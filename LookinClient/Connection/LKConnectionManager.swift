import Foundation
import LookinShared
import RxRelay
import RxSwift

public final class LKConnectionManager: NSObject {
    public static let sharedInstance = LKConnectionManager()

    private let channelWillEndRelay = PublishRelay<LKPeerChannel>()
    public var channelWillEnd: Observable<LKPeerChannel> {
        channelWillEndRelay.asObservable()
    }

    var peerActiveRequests: [ObjectIdentifier: NSMutableSet] = [:]

    private let didReceivePushRelay = PublishRelay<LookinTriple>()
    public var didReceivePush: Observable<LookinTriple> {
        didReceivePushRelay.asObservable()
    }

    var allSimulatorPorts: [LKSimulatorConnectionPort] = []
    var allUSBPorts: [LKUSBConnectionPort] = []
    /// usbmux `Properties.DeviceName` keyed by DeviceID (for launch tiles before Peertalk connects).
    var attachedUSBDeviceLabels: [UInt32: String] = [:]

    /// True when usbmux reported at least one attached iOS device (may still be waiting for demo listen).
    public var hasAttachedUSBDevices: Bool { !allUSBPorts.isEmpty }

    func uniqueAttachedUSBDeviceIDs() -> [NSNumber] {
        var seen = Set<UInt32>()
        var ids: [NSNumber] = []
        for port in allUSBPorts {
            guard let deviceID = port.deviceID else { continue }
            let raw = deviceID.uint32Value
            if seen.insert(raw).inserted {
                ids.append(deviceID)
            }
        }
        return ids
    }

    func usbDeviceLabel(for deviceID: NSNumber) -> String? {
        attachedUSBDeviceLabels[deviceID.uint32Value]
    }

    public func isUSBPeertalkPort(_ port: Int) -> Bool {
        port >= Int(LookinUSBDeviceIPv4PortNumberStart) && port <= Int(LookinUSBDeviceIPv4PortNumberEnd)
    }

    public func isSimulatorPeertalkPort(_ port: Int) -> Bool {
        port >= Int(LookinSimulatorIPv4PortNumberStart) && port <= Int(LookinSimulatorIPv4PortNumberEnd)
    }

    public func channelUsesUSB(_ channel: LKPeerChannel?) -> Bool {
        guard let channel else { return false }
        return isUSBPeertalkPort(channel.targetPort)
    }

    /// Simulator app may appear before the USB demo starts listening — keep polling instead of auto-enter.
    public func shouldDeferLaunchAutoEnterForPendingUSB(usableApps: [LKInspectableApp]) -> Bool {
        guard hasAttachedUSBDevices else { return false }
        return !usableApps.contains { channelUsesUSB($0.channel) }
    }

    public internal(set) var mcpLastConnectSnapshot: LKMCPConnectSnapshot?

    /// MCP verify: one-shot `forceFreshDiscovery` on the next `discover-apps` (set via `LOOKIN_FORCE_DISCOVER_ONCE=1` on launch).
    var mcpForceFreshDiscoverOnNextFetch = ProcessInfo.processInfo.environment["LOOKIN_FORCE_DISCOVER_ONCE"] == "1"

    func consumeMCPForceFreshDiscover() -> Bool {
        guard mcpForceFreshDiscoverOnNextFetch else { return false }
        mcpForceFreshDiscoverOnNextFetch = false
        return true
    }

    public func clearMCPSessionSnapshots() {
        mcpLastConnectSnapshot = nil
    }

    private static let pushFrameTypes: IndexSet = {
        IndexSet(LookinWirePushTypes.all.map { Int($0) })
    }()

    private static let requestTagLock = NSLock()
    private static var nextRequestTag: UInt32 = 1

    func allocateRequestTag() -> UInt32 {
        Self.requestTagLock.lock()
        defer { Self.requestTagLock.unlock() }
        let tag = Self.nextRequestTag
        Self.nextRequestTag &+= 1
        if Self.nextRequestTag == 0 {
            Self.nextRequestTag = 1
        }
        return tag
    }

    private override init() {
        super.init()

        allSimulatorPorts = (Int32(LookinSimulatorIPv4PortNumberStart) ... Int32(LookinSimulatorIPv4PortNumberEnd)).map { number in
            let port = LKSimulatorConnectionPort()
            port.portNumber = number
            return port
        }

        startListeningForUSBDevices()
        LKServerVersionRequestor.shared.preload()
    }

    func shouldAcceptPeerFrame(
        channel: LKPeerChannel,
        type: UInt32,
        tag: UInt32,
        payloadSize: UInt32
    ) -> Bool {
        _ = payloadSize
        if Self.pushFrameTypes.contains(Int(type)) {
            return true
        }

        if Self.wireV2FrameTypes.contains(Int(type)) {
            return true
        }

        if Self.lk_activeRequest(on: channel, frameType: type, tag: tag) != nil {
            return true
        }

        NSLog("LookinClient - will refuse, type:%@, tag:%@", NSNumber(value: type), NSNumber(value: tag))
        return false
    }

    func deliverIncomingPeerFrame(
        channel: LKPeerChannel,
        type: UInt32,
        tag: UInt32,
        payload: Data?
    ) {
        if Self.pushFrameTypes.contains(Int(type)) {
            let data = payload ?? Data()
            guard !data.isEmpty else { return }
            guard let pushEnvelope = try? LKWireCodecV2.decodeJSON(WirePushEnvelope.self, from: data) else {
                NSLog("LookinWireV2 - push JSON decode failed type:%u", type)
                return
            }
            guard LookinWireFormat.validateWireVersion(pushEnvelope.wireVersion, context: "push") else {
                return
            }
            didReceivePushRelay.accept(
                LookinTriple(
                    first: channel,
                    second: NSNumber(value: pushEnvelope.pushType),
                    third: NSNull()
                )
            )
            return
        }

        let data = payload ?? Data()
        guard !data.isEmpty else {
            return
        }

        let activeRequest = LKConnectionManager.lk_activeRequest(on: channel, frameType: type, tag: tag)

        if handleWireV2FrameIfNeeded(
            type: type,
            tag: tag,
            data: data,
            channel: channel,
            activeRequest: activeRequest
        ) {
            return
        }

        if Self.wireV2FrameTypes.contains(Int(type)) {
            if let activeRequest {
                NSLog("LookinWireV2 - wire v2 frame decode failed type:%u tag:%u", type, tag)
                activeRequest.endTimeoutCount()
                removeActiveRequest(activeRequest, from: channel)
                activeRequest.failBlock?(LKLookinClientErrors.inner)
            }
            return
        }

        if let activeRequest {
            NSLog("LookinWireV2 - legacy NSCoding response rejected type:%u tag:%u", type, tag)
            activeRequest.endTimeoutCount()
            removeActiveRequest(activeRequest, from: channel)
            activeRequest.failBlock?(LKLookinClientErrors.inner)
        }
    }

    func peerChannelDidEnd(_ channel: LKPeerChannel?, error: NSError?) {
        guard let channel else { return }
        for port in allSimulatorPorts where port.connectedChannel === channel {
            port.connectedChannel = nil
        }
        for port in allUSBPorts where port.connectedChannel === channel {
            port.connectedChannel = nil
        }
        clearActiveRequests(for: channel)
        channelWillEndRelay.accept(channel)
        channel.close()
        _ = error
    }
}
