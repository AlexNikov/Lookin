import Foundation
import LookinShared

extension LKConnectionManager {
    func activeRequestSet(for channel: LKPeerChannel) -> NSMutableSet? {
        peerActiveRequests[ObjectIdentifier(channel)]
    }

    func ensureActiveRequestSet(for channel: LKPeerChannel) -> NSMutableSet {
        let key = ObjectIdentifier(channel)
        if let existing = peerActiveRequests[key] {
            return existing
        }
        let created = NSMutableSet()
        peerActiveRequests[key] = created
        return created
    }

    func removeActiveRequest(_ request: LKConnectionRequest, from channel: LKPeerChannel) {
        activeRequestSet(for: channel)?.remove(request)
    }

    func clearActiveRequests(for channel: LKPeerChannel) {
        peerActiveRequests.removeValue(forKey: ObjectIdentifier(channel))
    }

    /// Fail and drop in-flight Peertalk requests (inspector teardown / MCP reconnect).
    func cancelAllActivePeerRequests() {
        var channels: [LKPeerChannel] = []
        for port in allSimulatorPorts {
            if let channel = port.connectedChannel {
                channels.append(channel)
            }
        }
        for port in allUSBPorts {
            if let channel = port.connectedChannel {
                channels.append(channel)
            }
        }
        for channel in channels {
            cancelActivePeerRequests(on: channel)
        }
    }

    private func cancelActivePeerRequests(on channel: LKPeerChannel) {
        guard let set = activeRequestSet(for: channel) else { return }
        let requests = set.allObjects.compactMap { $0 as? LKConnectionRequest }
        for request in requests {
            request.endTimeoutCount()
            removeActiveRequest(request, from: channel)
            request.failBlock?(LKLookinClientErrors.discard())
            request.completionBlock?()
        }
    }
}
