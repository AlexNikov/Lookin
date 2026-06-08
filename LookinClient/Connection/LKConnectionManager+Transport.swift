import Darwin
import Foundation
import LookinShared
import RxSwift

final class LKSimulatorConnectionPort: CustomStringConvertible {
    var portNumber: Int32 = 0
    var connectedChannel: LookinPTChannel?

    var description: String {
        "number:\(portNumber)"
    }
}

final class LKUSBConnectionPort: CustomStringConvertible {
    var portNumber: Int32 = 0
    var deviceID: NSNumber?
    var connectedChannel: LookinPTChannel?

    var description: String {
        "number:\(portNumber), deviceID:\(String(describing: deviceID)), connectedChannel:\(String(describing: connectedChannel))"
    }
}

extension LKConnectionManager {
    private static var lastIOSRelistenRequestAt: TimeInterval = 0
    private static var bootedSimulatorCache: (value: Bool, at: TimeInterval)?

    // MARK: - Ports Connect

    /// Closes all cached discovery transports (launch-screen rescan after leaving inspector).
    public func releaseAllDiscoveryChannels() {
        for port in allSimulatorPorts {
            port.connectedChannel?.close()
            port.connectedChannel = nil
        }
        for port in allUSBPorts {
            port.connectedChannel?.close()
            port.connectedChannel = nil
        }
    }

    /// Closes discovery transports except the target session (USB is unstable while sim link stays open).
    public func releaseDiscoveryChannels(except keep: LookinPTChannel?) {
        var toRelease: [LookinPTChannel] = []
        for port in allSimulatorPorts {
            if let channel = port.connectedChannel, channel !== keep {
                toRelease.append(channel)
            }
        }
        for port in allUSBPorts {
            if let channel = port.connectedChannel, channel !== keep {
                toRelease.append(channel)
            }
        }
        for channel in toRelease {
            releaseCachedChannel(channel)
        }
    }

    /// Clears cached Peertalk channels and closes the transport (e.g. when leaving the inspector).
    public func releaseCachedChannel(_ channel: LookinPTChannel) {
        for port in allSimulatorPorts where port.connectedChannel === channel {
            port.connectedChannel = nil
        }
        for port in allUSBPorts where port.connectedChannel === channel {
            port.connectedChannel = nil
        }
        if channel.isConnected {
            channel.cancel()
        } else {
            channel.close()
        }
    }

    private func purgeDisconnectedCachedChannels() {
        for port in allSimulatorPorts {
            guard let channel = port.connectedChannel, !channel.isConnected else { continue }
            channel.close()
            port.connectedChannel = nil
        }
        for port in allUSBPorts {
            guard let channel = port.connectedChannel, !channel.isConnected else { continue }
            channel.close()
            port.connectedChannel = nil
        }
    }

    /// Drops cached Peertalk transports and asks iOS to relisten (needed after switching simulator demo).
    public func prepareForAppRediscovery() {
        nudgeIOSPeertalkRelistenBeforeDiscovery()
        releaseAllDiscoveryChannels()
        mcpLastConnectSnapshot = nil
    }

    public func tryToConnectAllPorts(forceFreshDiscovery: Bool = false) -> Single<[LookinPTChannel]> {
        Single.create { single in
            let task = Task { [self] in
                // ObjC parity: normal discovery only purges dead transports. Full rediscovery
                // (relisten + close all) is explicit via forceFreshDiscovery — not on every
                // launch poll / auto-reconnect while inspectingApp is nil (breaks USB devices).
                if forceFreshDiscovery {
                    self.prepareForAppRediscovery()
                } else {
                    self.purgeDisconnectedCachedChannels()
                }
                async let simulatorChannels = self.tryConnectAllSimulatorPorts()
                async let usbChannels = self.tryConnectAllUSBDevices()
                let channels = await simulatorChannels + usbChannels
                if !channels.isEmpty, self.mcpLastConnectSnapshot == nil {
                    let snap = LKMCPConnectSnapshot()
                    snap.channelCount = channels.count
                    snap.connectedPorts = channels.map { Int($0.targetPort) }
                    snap.timestamp = Date().timeIntervalSince1970
                    self.mcpLastConnectSnapshot = snap
                }
                single(.success(channels))
            }
            return Disposables.create { task.cancel() }
        }
    }

    private struct SimulatorConnectAttempt {
        let portNumber: Int32
        let channel: LookinPTChannel?
        let errnoCode: Int?
    }

    public func mcpCachedSimulatorPortNumbers() -> [Int32] {
        allSimulatorPorts.compactMap { port in
            port.connectedChannel != nil ? port.portNumber : nil
        }
    }

    private func tryConnectAllSimulatorPorts(isRetryAfterIOSRelisten: Bool = false) async -> [LookinPTChannel] {
        guard Self.hasBootedIOSSimulator() else { return [] }

        let channels = await performSimulatorConnectAttempts()
        if channels.isEmpty, !isRetryAfterIOSRelisten {
            let errors = mcpLastConnectSnapshot?.portErrors ?? []
            let allRefused = !errors.isEmpty && errors.allSatisfy { $0.hasSuffix(":61") }
            // :47190 MCP exists only in Simulator (localhost port-forward). Skip on USB-only workflows.
            if allRefused, requestIOSPeertalkRelisten() {
                try? await Task.sleep(nanoseconds: 600_000_000)
                return await tryConnectAllSimulatorPorts(isRetryAfterIOSRelisten: true)
            }
        }
        return channels
    }

    /// MCP launch-health: whether an iOS Simulator is booted (cached ~3s).
    static func mcpHasBootedIOSSimulator() -> Bool {
        hasBootedIOSSimulator()
    }

    /// Avoid simctl + :47190 relisten spam when the user inspects a physical device only.
    private static func hasBootedIOSSimulator() -> Bool {
        let now = Date().timeIntervalSince1970
        if let cached = bootedSimulatorCache, now - cached.at < 3 {
            return cached.value
        }
        let pipe = Pipe()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        task.arguments = ["simctl", "list", "devices", "booted", "-j"]
        task.standardOutput = pipe
        task.standardError = Pipe()
        var booted = false
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let devices = json["devices"] as? [String: [[String: Any]]] {
                    booted = devices.values.contains { list in
                        list.contains { ($0["state"] as? String) == "Booted" }
                    }
                }
            }
        } catch {
            booted = false
        }
        bootedSimulatorCache = (booted, now)
        return booted
    }

    private func performSimulatorConnectAttempts() async -> [LookinPTChannel] {
        await withTaskGroup(of: SimulatorConnectAttempt.self) { group in
            for port in allSimulatorPorts {
                group.addTask { [self] in
                    do {
                        let channel = try await connectToSimulatorPort(port)
                        return SimulatorConnectAttempt(portNumber: port.portNumber, channel: channel, errnoCode: nil)
                    } catch {
                        return SimulatorConnectAttempt(
                            portNumber: port.portNumber,
                            channel: nil,
                            errnoCode: (error as NSError).code
                        )
                    }
                }
            }
            var channels: [LookinPTChannel] = []
            var connectErrors: [String] = []
            var connectedPorts: [Int] = []
            for await attempt in group {
                if let channel = attempt.channel {
                    channels.append(channel)
                    connectedPorts.append(Int(attempt.portNumber))
                } else if let code = attempt.errnoCode {
                    connectErrors.append("\(attempt.portNumber):\(code)")
                }
            }

            let snapshot = LKMCPConnectSnapshot()
            snapshot.channelCount = channels.count
            snapshot.connectedPorts = connectedPorts
            snapshot.portErrors = connectErrors
            snapshot.cachedSimulatorPorts = allSimulatorPorts
                .filter { $0.connectedChannel != nil }
                .map { Int($0.portNumber) }
            snapshot.timestamp = Date().timeIntervalSince1970
            mcpLastConnectSnapshot = snapshot
            LKMCPClientDiagnostics.shared.recordConnectSnapshot(snapshot)

            if channels.isEmpty {
                let summary = connectErrors.isEmpty
                    ? "all ports failed (no errno captured)"
                    : connectErrors.joined(separator: " ")
                let allRefused = !connectErrors.isEmpty && connectErrors.allSatisfy { $0.hasSuffix(":61") }
                LookinDiagLog.log(
                    "client connect simulator channels=0 errors=[\(summary)] (61=ECONNREFUSED — start LookinCustomInfoDemo in Simulator; 48=EADDRINUSE on iOS — kill stale demo)"
                )
                if allRefused {
                    LookinDiagLog.log(
                        "client hint: launch Lookin.LookinCustomInfoDemoSwift in Simulator, bring Simulator to front (Lookin polls launch screen; may POST iOS :47190/relisten-peertalk)"
                    )
                }
            } else {
                let ports = channels.map { String($0.targetPort) }.joined(separator: ",")
                LookinDiagLog.log("client connect simulator channels=\(channels.count) ports=[\(ports)]")
            }
            return channels
        }
    }

    private func nudgeIOSPeertalkRelistenBeforeDiscovery() {
        _ = requestIOSPeertalkRelisten()
    }

    /// Ask the running Simulator demo (MCP :47190) to drop a stale Peertalk peer and listen again.
    private func requestIOSPeertalkRelisten() -> Bool {
        guard Self.hasBootedIOSSimulator() else { return false }

        let now = Date().timeIntervalSince1970
        guard now - Self.lastIOSRelistenRequestAt >= 2 else { return false }
        Self.lastIOSRelistenRequestAt = now

        if performIOSMCPRequest(method: "POST", path: "/relisten-peertalk") {
            LookinDiagLog.log("client POST iOS /relisten-peertalk OK — will retry simulator connect")
            return true
        }
        // Older demo builds: GET /status nudges `nudgePeertalkListenForLaunchScreenDiscoveryIfNeeded`.
        if performIOSMCPRequest(method: "GET", path: "/status") {
            LookinDiagLog.log("client GET iOS /status — nudged Peertalk re-listen before discovery")
            return true
        }
        return false
    }

    private func performIOSMCPRequest(method: String, path: String) -> Bool {
        guard let url = URL(string: "http://127.0.0.1:47190\(path)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 2

        let semaphore = DispatchSemaphore(value: 0)
        var succeeded = false
        URLSession.shared.dataTask(with: request) { _, response, error in
            if error == nil, let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) {
                succeeded = true
            }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 3)
        return succeeded
    }

    private func connectToSimulatorPort(_ port: LKSimulatorConnectionPort) async throws -> LookinPTChannel {
        if let connectedChannel = port.connectedChannel {
            if connectedChannel.isConnected {
                return connectedChannel
            }
            connectedChannel.close()
            port.connectedChannel = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let localChannel = LookinPTChannel.channel(withDelegate: self)
            localChannel.connect(
                toPort: UInt16(port.portNumber),
                ipv4Address: in_addr_t(INADDR_LOOPBACK)
            ) { error, _ in
                if let error {
                    localChannel.close()
                    continuation.resume(throwing: error)
                } else {
                    localChannel.targetPort = Int(port.portNumber)
                    port.connectedChannel = localChannel
                    continuation.resume(returning: localChannel)
                }
            }
        }
    }

    private func tryConnectAllUSBDevices() async -> [LookinPTChannel] {
        guard !allUSBPorts.isEmpty else {
            LookinDiagLog.log("client connect usb channels=0 (no USB device in allUSBPorts — plug in device or unlock iPhone)")
            return []
        }

        // iOS binds Peertalk asynchronously after scene/active — retry before giving up this poll.
        let maxAttempts = 6
        for attempt in 1 ... maxAttempts {
            let channels = await performUSBConnectAttempts()
            if !channels.isEmpty {
                let ports = channels.map { String($0.targetPort) }.joined(separator: ",")
                LookinDiagLog.log("client connect usb channels=\(channels.count) ports=[\(ports)]")
                return channels
            }
            if attempt < maxAttempts {
                // iOS Peertalk watchdog may need ~1s to recycle after Mac Lookin quit (killall).
                let delayMs: UInt64 = attempt == 3 ? 2_000_000_000 : 900_000_000
                try? await Task.sleep(nanoseconds: delayMs)
            }
        }
        return []
    }

    private func performUSBConnectAttempts() async -> [LookinPTChannel] {
        await withTaskGroup(of: (Int32, LookinPTChannel?, Int?).self) { group in
            for port in allUSBPorts {
                group.addTask { [self] in
                    do {
                        let channel = try await connectToUSBPort(port)
                        return (port.portNumber, channel, nil)
                    } catch {
                        return (port.portNumber, nil, (error as NSError).code)
                    }
                }
            }
            var channels: [LookinPTChannel] = []
            var connectErrors: [String] = []
            for await attempt in group {
                if let channel = attempt.1 {
                    channels.append(channel)
                } else if let code = attempt.2 {
                    connectErrors.append("\(attempt.0):\(code)")
                }
            }
            if channels.isEmpty {
                let summary = connectErrors.isEmpty
                    ? "all USB ports failed (no errno captured)"
                    : connectErrors.joined(separator: " ")
                LookinDiagLog.log(
                    "client connect usb channels=0 devicePorts=\(allUSBPorts.count) errors=[\(summary)] (3=connection refused — on iPhone Xcode console expect 'Connected successfully on 127.0.0.1:4717x'; rebuild demo after pod install)"
                )
            }
            return channels
        }
    }

    private func connectToUSBPort(_ port: LKUSBConnectionPort) async throws -> LookinPTChannel {
        if let connectedChannel = port.connectedChannel {
            if connectedChannel.isConnected {
                return connectedChannel
            }
            connectedChannel.close()
            port.connectedChannel = nil
        }

        guard let deviceID = port.deviceID else {
            throw LKLookinClientErrors.inner
        }

        return try await withCheckedThrowingContinuation { continuation in
            let channel = LookinPTChannel.channel(withDelegate: self)
            channel.connect(
                toPort: port.portNumber,
                over: LookinPTUSBHub.shared(),
                deviceID: deviceID
            ) { error in
                if let error {
                    channel.close()
                    continuation.resume(throwing: error)
                } else {
                    channel.targetPort = Int(port.portNumber)
                    port.connectedChannel = channel
                    continuation.resume(returning: channel)
                }
            }
        }
    }

    // MARK: - USB Device Listening

    func startListeningForUSBDevices() {
        let center = NotificationCenter.default
        // Observers must exist before sharedHub starts usbmux Listen — otherwise
        // Attached for an already-plugged iPhone is delivered before registration.
        center.addObserver(
            forName: NSNotification.Name(Lookin_PTUSBDeviceDidAttachNotification),
            object: nil,
            queue: nil
        ) { [weak self] note in
            self?.registerUSBDevice(fromAttachNotification: note)
        }

        center.addObserver(
            forName: NSNotification.Name(Lookin_PTUSBDeviceDidDetachNotification),
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let self, let deviceID = self.usbDeviceID(from: note) else { return }
            self.allUSBPorts.removeAll { $0.deviceID == deviceID }
            self.attachedUSBDeviceLabels.removeValue(forKey: deviceID.uint32Value)
            NSLog("Lookin - USB 设备拔出，DeviceID: %@", deviceID)
        }

        _ = LookinPTUSBHub.shared()
    }

    private func usbDeviceID(from note: Notification) -> NSNumber? {
        guard let raw = note.userInfo?["DeviceID"] else { return nil }
        if let id = raw as? NSNumber { return id }
        if let id = raw as? Int { return NSNumber(value: id) }
        if let id = raw as? UInt32 { return NSNumber(value: id) }
        if let id = raw as? Int64 { return NSNumber(value: id) }
        return nil
    }

    private func usbDeviceLabel(from note: Notification) -> String? {
        guard let props = note.userInfo?["Properties"] as? [String: Any] else { return nil }
        if let name = props["DeviceName"] as? String, !name.isEmpty {
            return name
        }
        if let serial = props["SerialNumber"] as? String, !serial.isEmpty, !looksLikeUDID(serial) {
            return serial
        }
        return nil
    }

    private func looksLikeUDID(_ value: String) -> Bool {
        value.count >= 20 && value.contains("-")
    }

    private func registerUSBDevice(fromAttachNotification note: Notification) {
        guard let deviceID = usbDeviceID(from: note) else {
            LookinDiagLog.log("client USB attach ignored — missing DeviceID in notification")
            return
        }
        if let label = usbDeviceLabel(from: note) {
            attachedUSBDeviceLabels[deviceID.uint32Value] = label
        }
        if allUSBPorts.contains(where: { $0.deviceID == deviceID }) {
            return
        }
        for number in Int32(LookinUSBDeviceIPv4PortNumberStart) ... Int32(LookinUSBDeviceIPv4PortNumberEnd) {
            let port = LKUSBConnectionPort()
            port.portNumber = number
            port.deviceID = deviceID
            allUSBPorts.append(port)
        }
        let label = attachedUSBDeviceLabels[deviceID.uint32Value] ?? "iPhone"
        LookinDiagLog.log("client USB device attached id=\(deviceID) name=\(label)")
        NSLog("Lookin - USB device connected, DeviceID: %@", deviceID)
    }
}
