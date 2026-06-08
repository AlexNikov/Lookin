import Foundation
import LookinShared

extension LKConnectionManager {
    private static let wireScreenshotCoordinator = LKWireScreenshotCoordinator()

    /// Wire v2 multiplexes `LKJS` / `LKPG` frame types; Peertalk requests keep `LookinRequestType*` as `type`.
    static func lk_activeRequest(
        on channel: LookinPTChannel,
        frameType type: UInt32,
        tag: UInt32
    ) -> LKConnectionRequest? {
        if wireV2FrameTypes.contains(Int(type)) {
            return channel.lk_activeRequests?.lookin_firstFiltered { obj in
                (obj as? LKConnectionRequest)?.tag == tag
            } as? LKConnectionRequest
        }
        return channel.lk_activeRequests?.lookin_firstFiltered { obj in
            guard let request = obj as? LKConnectionRequest else { return false }
            return request.type == type && request.tag == tag
        } as? LKConnectionRequest
    }

    static var wireV2FrameTypes: IndexSet {
        IndexSet([Int(LookinWireFormat.frameTypeJSON), Int(LookinWireFormat.frameTypeScreenshot)])
    }

    func handleWireV2FrameIfNeeded(
        type: UInt32,
        tag: UInt32,
        data: Data,
        channel: LookinPTChannel,
        activeRequest: LKConnectionRequest?
    ) -> Bool {
        switch type {
        case LookinWireFormat.frameTypeJSON:
            guard let activeRequest else { return false }
            return handleWireJSONFrame(data: data, tag: tag, activeRequest: activeRequest, channel: channel)
        case LookinWireFormat.frameTypeScreenshot:
            handleWireScreenshotFrame(data: data, tag: tag, channel: channel, activeRequest: activeRequest)
            return true
        default:
            guard let activeRequest,
                  type == activeRequest.type,
                  data.first == UInt8(ascii: "{") else {
                return false
            }
            return handleWireJSONFrame(data: data, tag: tag, activeRequest: activeRequest, channel: channel)
        }
    }

    private func handleWireJSONFrame(
        data: Data,
        tag: UInt32,
        activeRequest: LKConnectionRequest,
        channel: LookinPTChannel
    ) -> Bool {
        guard let envelope = try? LKWireCodecV2.decodeJSON(WireResponseEnvelope.self, from: data) else {
            LookinDiagLog.log("client wire JSON decode FAIL type=\(activeRequest.type) tag=\(tag)")
            failWireResponse(
                activeRequest: activeRequest,
                channel: channel,
                reason: "JSON decode failed tag=\(tag)"
            )
            return true
        }
        guard LookinWireFormat.validateWireVersion(envelope.wireVersion, context: "response") else {
            LookinDiagLog.log("client wire version FAIL got=\(envelope.wireVersion) tag=\(tag)")
            failWireResponse(
                activeRequest: activeRequest,
                channel: channel,
                reason: "wireVersion=\(envelope.wireVersion) tag=\(tag)"
            )
            return true
        }

        let attachment = LookinConnectionResponseAttachment()
        if WireRequestResponseMapper.applyResponseEnvelope(envelope, to: attachment) {
            if let wireDetail = envelope.detail {
                let detail = attachment.data as? LookinDisplayItemDetail ?? WireHierarchyMapper.lookinDetail(from: wireDetail)
                Self.wireScreenshotCoordinator.storePendingDetail(detail, request: activeRequest, channel: channel)
                flushBufferedWireScreenshots(for: detail.displayItemOid, tag: tag, channel: channel)
            }
            LookinDiagLog.log(
                "client wire resp OK type=\(activeRequest.type) tag=\(tag) hasDetail=\(envelope.detail != nil) hasError=\(envelope.error != nil)"
            )
            deliverWireAttachment(attachment, activeRequest: activeRequest, channel: channel, envelope: envelope)
            return true
        }

        NSLog(
            "LookinWireV2 - unexpected response shape type=%u tag=%u hasDetail=%d hasError=%d",
            envelope.requestType,
            tag,
            envelope.detail != nil ? 1 : 0,
            envelope.error != nil ? 1 : 0
        )
        failWireResponse(
            activeRequest: activeRequest,
            channel: channel,
            reason: "Unexpected wire response (type \(envelope.requestType))"
        )
        return true
    }

    private func failWireResponse(
        activeRequest: LKConnectionRequest,
        channel: LookinPTChannel,
        reason: String
    ) {
        NSLog("LookinWireV2 - %@", reason)
        activeRequest.endTimeoutCount()
        channel.lk_activeRequests?.remove(activeRequest)
        activeRequest.failBlock?(LKLookinClientErrors.wireResponseFailed(reason))
    }

    private func handleWireScreenshotFrame(
        data: Data,
        tag: UInt32,
        channel: LookinPTChannel,
        activeRequest: LKConnectionRequest?
    ) {
        guard let parsed = LKWireCodecV2.parseScreenshotPayload(data) else { return }
        guard let image = WireScreenshotImageCoding.lookinImage(from: parsed.imageData, format: parsed.format) else {
            NSLog("LookinWireV2 - screenshot decode failed oid=%u", parsed.oid)
            return
        }
        if let detail = Self.wireScreenshotCoordinator.pendingDetail(
            for: activeRequest,
            channel: channel,
            tag: tag,
            oid: parsed.oid
        ) {
            switch parsed.kind {
            case .solo:
                detail.soloScreenshot = image
            case .group:
                detail.groupScreenshot = image
            }
        }
        applyWireV2Screenshot(oid: parsed.oid, kind: parsed.kind, image: image, tag: tag, channel: channel)
    }

    /// Applies a wire v2 screenshot directly onto `LookinDisplayItem` by oid (does not require pending JSON detail).
    private func applyWireV2Screenshot(
        oid: UInt,
        kind: WireScreenshotKind,
        image: LookinImage,
        tag: UInt32,
        channel: LookinPTChannel
    ) {
        guard LKStaticHierarchyDataSource.sharedInstance.displayItem(withOid: oid) != nil else {
            Self.wireScreenshotCoordinator.bufferScreenshot(
                oid: oid,
                kind: kind,
                image: image,
                tag: tag,
                channel: channel
            )
            return
        }
        let patch = LookinDisplayItemDetail()
        patch.displayItemOid = oid
        switch kind {
        case .solo:
            patch.soloScreenshot = image
        case .group:
            patch.groupScreenshot = image
        }
        applyWireV2ScreenshotToHierarchy(patch)
    }

    private func applyWireV2ScreenshotToHierarchy(_ detail: LookinDisplayItemDetail) {
        let apply = {
            LKStaticHierarchyDataSource.sharedInstance.modify(with: detail)
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    private func deliverWireAttachment(
        _ attachment: LookinConnectionResponseAttachment,
        activeRequest: LKConnectionRequest,
        channel: LookinPTChannel,
        envelope: WireResponseEnvelope
    ) {
        let deliver = { [self] in
            if attachment.appIsInBackground {
                activeRequest.endTimeoutCount()
                channel.lk_activeRequests?.remove(activeRequest)
                activeRequest.failBlock?(LKLookinClientErrors.pingFailForBackgroundState())
                return
            }

            activeRequest.succBlock?(attachment)

            var hasReceivedAllResponses = false
            if attachment.dataTotalCount > 0 {
                activeRequest.receivedDataCount += attachment.currentDataCount
                if activeRequest.receivedDataCount >= attachment.dataTotalCount {
                    hasReceivedAllResponses = true
                }
            } else {
                hasReceivedAllResponses = true
            }

            if hasReceivedAllResponses {
                activeRequest.endTimeoutCount()
                channel.lk_activeRequests?.remove(activeRequest)
                flushAllBufferedWireScreenshots(for: activeRequest.tag, channel: channel)
                Self.wireScreenshotCoordinator.clearPendingState(
                    for: activeRequest.tag,
                    channel: channel,
                    request: activeRequest
                )
                activeRequest.completionBlock?()
            } else {
                activeRequest.resetTimeoutCount()
            }
            _ = envelope
        }
        if Thread.isMainThread {
            deliver()
        } else {
            DispatchQueue.main.async(execute: deliver)
        }
    }

    private func flushBufferedWireScreenshots(for oid: UInt, tag: UInt32, channel: LookinPTChannel) {
        Self.wireScreenshotCoordinator.flushBufferedScreenshots(for: oid, tag: tag, channel: channel) {
            [self] oid, kind, image in
            applyWireV2Screenshot(oid: oid, kind: kind, image: image, tag: tag, channel: channel)
        }
    }

    private func flushAllBufferedWireScreenshots(for tag: UInt32, channel: LookinPTChannel) {
        Self.wireScreenshotCoordinator.flushAllBufferedScreenshots(for: tag, channel: channel) {
            [self] oid, kind, image in
            applyWireV2Screenshot(oid: oid, kind: kind, image: image, tag: tag, channel: channel)
        }
    }

    /// Apply screenshots that arrived before `displayItem(withOid:)` was ready.
    func flushWireScreenshotBuffers(on channel: LookinPTChannel?) {
        guard let channel else { return }
        Self.wireScreenshotCoordinator.flushAllBufferedOnChannel(channel) {
            [self] oid, tag, kind, image in
            applyWireV2Screenshot(oid: oid, kind: kind, image: image, tag: tag, channel: channel)
        }
    }

    func encodeWireV2RequestPayload(
        requestType: UInt32,
        tag: UInt32,
        data: NSObject? = nil,
        wirePayload: WireClientRequestPayload? = nil
    ) throws -> Data {
        let envelope: WireRequestEnvelope
        if let wirePayload {
            envelope = wirePayload.envelope(requestType: requestType, tag: tag)
        } else {
            envelope = WireRequestResponseMapper.requestEnvelope(
                requestType: requestType,
                tag: tag,
                data: data
            )
        }
        return try LKWireCodecV2.encodeJSON(envelope)
    }

    static func isWirePushType(_ pushType: UInt32) -> Bool {
        LookinWirePushTypes.all.contains(pushType)
    }

    func encodeWireV2PushPayload(pushType: UInt32) throws -> Data {
        try LKWireCodecV2.encodeJSON(WirePushEnvelope(pushType: pushType))
    }

}
