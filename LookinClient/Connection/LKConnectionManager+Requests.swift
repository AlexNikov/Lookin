import Foundation
import LookinShared
import RxSwift

extension LKConnectionManager {
    private static let requestTypesSkippingPreflightPing: Set<UInt32> = [
        UInt32(LookinRequestTypeInbuiltAttrModification),
        UInt32(LookinRequestTypeCustomAttrModification),
        UInt32(LookinRequestTypeAttrModificationPatch),
        UInt32(LookinRequestTypeAllAttrGroups),
        // Lightweight background fetch for console autocomplete; no blocking on ping.
        UInt32(LookinRequestTypeAllSelectorNames),
    ]

    // MARK: - Request

    public func push(withType pushType: UInt32, data: NSObject?, channel: LKPeerChannel?) {
        guard let channel, channel.isConnected else { return }

        do {
            guard Self.isWirePushType(pushType) else {
                NSLog("LookinWireV2 - unsupported push type:%u", pushType)
                return
            }
            let jsonData = try encodeWireV2PushPayload(pushType: pushType)
            let payload = (jsonData as NSData).createReferencingDispatchData()
            NSLog("LookinClient - pushData, type:%@", NSNumber(value: pushType))
            channel.sendFrame(ofType: pushType, tag: 0, withPayload: payload, callback: nil)
        } catch {
            assertionFailure()
        }
    }

    public func request(
        withType requestType: UInt32,
        data requestData: NSObject?,
        channel: LKPeerChannel?,
        wirePayload: WireClientRequestPayload? = nil
    ) -> Observable<LookinPair> {
        Observable.create { observer in
            let sendPayload: () -> Void = {
                self.request(
                    withType: requestType,
                    channel: channel,
                    data: requestData,
                    wirePayload: wirePayload,
                    timeoutInterval: LKWireClientRequestTimeout.interval(forRequestType: requestType),
                    succ: { responseData in
                        observer.onNext(LookinPair(first: responseData, second: channel))
                    },
                    fail: { observer.onError($0) },
                    completion: { observer.onCompleted() }
                )
            }

            if Self.requestTypesSkippingPreflightPing.contains(requestType) {
                sendPayload()
                return Disposables.create()
            }

            self.request(
                withType: UInt32(LookinRequestTypePing),
                channel: channel,
                data: nil,
                timeoutInterval: LKWireClientRequestTimeout.pingInterval(beforeRequestType: requestType),
                succ: { pingResponse in
                    guard let pingResponse = pingResponse as? LookinConnectionResponseAttachment else {
                        observer.onError(LKLookinClientErrors.inner)
                        return
                    }
                    if let versionErr = self.checkServerVersion(with: pingResponse) {
                        observer.onError(versionErr)
                        return
                    }
                    sendPayload()
                },
                fail: { observer.onError($0) },
                completion: nil
            )
            return Disposables.create()
        }
    }

    public func cancelRequest(withType requestType: UInt32, channel: LKPeerChannel?) {
        cancelRequest(withType: requestType, channel: channel, notifyDiscard: false)
    }

    public func cancelRequest(withType requestType: UInt32, channel: LKPeerChannel?, notifyDiscard: Bool) {
        guard let channel else { return }
        guard
            let activeRequest = activeRequestSet(for: channel)?.lookin_firstFiltered({ obj in
                guard let request = obj as? LKConnectionRequest else { return false }
                return request.type == requestType
            }) as? LKConnectionRequest
        else {
            return
        }

        activeRequest.endTimeoutCount()
        removeActiveRequest(activeRequest, from: channel)
        if notifyDiscard, let failBlock = activeRequest.failBlock {
            failBlock(LKLookinClientErrors.discard())
        }
        activeRequest.completionBlock?()
        NSLog("Lookin - 用户手动取消 request, type:%@", NSNumber(value: requestType))
    }

    private func checkServerVersion(with pingResponse: LookinConnectionResponseAttachment) -> NSError? {
        let serverVersion = pingResponse.lookinServerVersion
        if serverVersion == -1 || serverVersion == 100 {
            return LKLookinClientErrors.serverVersionTooLow()
        }
        if serverVersion > LOOKIN_SUPPORTED_SERVER_MAX {
            return LKLookinClientErrors.serverVersionTooHigh()
        }
        if serverVersion < LOOKIN_SUPPORTED_SERVER_MIN {
            return LKLookinClientErrors.serverVersionTooLow()
        }
        return nil
    }

    private func request(
        withType requestType: UInt32,
        channel: LKPeerChannel?,
        data: NSObject?,
        wirePayload: WireClientRequestPayload? = nil,
        timeoutInterval: TimeInterval,
        succ succBlock: ((Any?) -> Void)?,
        fail failBlock: ((NSError) -> Void)?,
        completion completionBlock: (() -> Void)?
    ) {
        guard let channel else {
            assertionFailure()
            failBlock?(LKLookinClientErrors.inner)
            return
        }
        guard channel.isConnected else {
            failBlock?(LKLookinClientErrors.noConnect)
            return
        }

        if let activeRequests = activeRequestSet(for: channel), activeRequests.count > 0, requestType != UInt32(LookinRequestTypePing) {
            let requestsToDiscard = activeRequests.lookin_filter { obj in
                guard let request = obj as? LKConnectionRequest else { return false }
                return request.type == requestType
            }
            for case let request as LKConnectionRequest in requestsToDiscard {
                request.endTimeoutCount()
                removeActiveRequest(request, from: channel)
                request.failBlock?(LKLookinClientErrors.discard())
                NSLog("LookinClient - will discard request, type:%@, tag:%@", NSNumber(value: request.type), NSNumber(value: request.tag))
            }
        }

        let request = LKConnectionRequest()
        request.type = requestType
        request.tag = allocateRequestTag()
        request.succBlock = succBlock
        request.failBlock = { error in
            if let error = error as NSError? {
                failBlock?(error)
            }
        }
        request.completionBlock = completionBlock
        request.timeoutInterval = timeoutInterval
        request.timeoutBlock = { [weak channel] selfRequest in
            guard let channel else { return }
            if let failBlock = selfRequest.failBlock {
                failBlock(LKLookinClientErrors.timeout())
            }
            self.removeActiveRequest(selfRequest, from: channel)
        }

        do {
            let jsonData = try encodeWireV2RequestPayload(
                requestType: requestType,
                tag: request.tag,
                data: data,
                wirePayload: wirePayload
            )
            // Peertalk frame type = LookinRequestType*; payload is JSON.
            let frameType = requestType
            let payload = (jsonData as NSData).createReferencingDispatchData()
            // Register before send — loopback wire v2 responses can arrive before sendFrame's callback.
            let activeRequests = ensureActiveRequestSet(for: channel)
            activeRequests.add(request)
            channel.sendFrame(ofType: frameType, tag: request.tag, withPayload: payload) { error in
                if let error {
                    self.removeActiveRequest(request, from: channel)
                    failBlock?(LKLookinClientErrors.peerTalk())
                    _ = error
                } else {
                    request.resetTimeoutCount()
                }
            }
        } catch {
            assertionFailure()
        }
    }
}
