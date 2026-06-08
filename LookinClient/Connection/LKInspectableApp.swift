import Foundation
import LookinShared
import RxSwift

public final class LKInspectableApp: NSObject {
    public var serverVersionError: NSError?
    public var appInfo: LookinAppInfo?
    public weak var channel: LookinPTChannel?
    /// Launch screen placeholder while a USB iPhone is plugged in but no demo is listening yet.
    public var isLaunchUSBPendingPlaceholder = false
    public var pendingUSBDeviceID: NSNumber?

    public func fetchHierarchyData() -> Single<LookinHierarchyInfo> {
        let params = WireHierarchyRequestParams(
            clientVersion: LKHelper.lookinReadableVersion(),
            minWireVersion: LookinWireFormat.version
        )
        return requestTyped(
            withType: UInt32(LookinRequestTypeHierarchy),
            wirePayload: .hierarchy(params)
        ) { data in
            guard let info = data as? LookinHierarchyInfo else {
                throw LKLookinClientErrors.inner
            }
            return info
        }
    }

    public func submitInbuiltModification(_ modification: LookinAttributeModification) -> Single<LookinDisplayItemDetail> {
        requestTyped(
            withType: UInt32(LookinRequestTypeInbuiltAttrModification),
            wirePayload: .inbuilt(modification)
        ) { data in
            guard let detail = data as? LookinDisplayItemDetail else {
                throw LKLookinClientErrors.inner
            }
            return detail
        }
    }

    public func cancelInbuiltModification() {
        guard let channel else { return }
        LKConnectionManager.sharedInstance.cancelRequest(
            withType: UInt32(LookinRequestTypeInbuiltAttrModification),
            channel: channel,
            notifyDiscard: true
        )
    }

    public func submitCustomModification(_ modification: LookinCustomAttrModification) -> Completable {
        requestTyped(
            withType: UInt32(LookinRequestTypeCustomAttrModification),
            wirePayload: .custom(modification)
        ) { _ in () }
            .asCompletable()
    }

    public func fetchHierarchyDetail(
        withTaskPackages packages: [LookinStaticAsyncUpdateTasksPackage]
    ) -> Observable<[LookinDisplayItemDetail]> {
        let wirePackages = packages.map { WireAsyncTaskMapper.wirePackage(from: $0) }
        return requestObservable(
            withType: UInt32(LookinRequestTypeHierarchyDetails),
            wirePayload: .detailPackages(wirePackages)
        )
        .map { value in
            let details = LookinCastDisplayItemDetails(value as Any)
            if details.isEmpty, !(value is NSNull) {
                NSLog(
                    "LookinClient - hierarchy details chunk empty after cast, data type: %@",
                    String(describing: type(of: value))
                )
            }
            return details
        }
    }

    private static func unwrapConnectionResponseAttachment(_ value: Any?) -> LookinConnectionResponseAttachment? {
        LookinCastConnectionResponseAttachment(value)
    }

    public func cancelHierarchyDetailFetching() {
        cancelRequest(withType: UInt32(LookinRequestTypeHierarchyDetails))
        push(withType: UInt32(LookinPush_CanceHierarchyDetails), data: nil)
    }

    public func fetchModificationPatch(withTasks tasks: [LookinStaticAsyncUpdateTask]) -> Observable<LookinDisplayItemDetail> {
        let wireTasks = tasks.map { WireAsyncTaskMapper.wireTask(from: $0) }
        return requestObservable(
            withType: UInt32(LookinRequestTypeAttrModificationPatch),
            wirePayload: .patchTasks(wireTasks)
        )
        .compactMap { $0 as? LookinDisplayItemDetail }
    }

    public func fetchObject(withOid oid: UInt) -> Single<LookinDisplayItem> {
        guard oid != 0 else {
            return .error(LKLookinClientErrors.inner)
        }
        return requestTyped(
            withType: UInt32(LookinRequestTypeFetchObject),
            wirePayload: .oid(oid)
        ) { data in
            guard let item = data as? LookinDisplayItem else {
                throw LKLookinClientErrors.inner
            }
            return item
        }
    }

    /// Lightweight attr fetch for dashboard selection — does not cancel bulk HierarchyDetails sync.
    public func fetchAttrGroupList(withOid oid: UInt) -> Single<[LookinAttributesGroup]> {
        guard oid != 0 else {
            return .error(LKLookinClientErrors.inner)
        }
        return requestTyped(
            withType: UInt32(LookinRequestTypeAllAttrGroups),
            wirePayload: .oid(oid)
        ) { data in
            if let list = data as? [LookinAttributesGroup] {
                return list
            }
            if let list = data as? NSArray as? [LookinAttributesGroup] {
                return list
            }
            throw LKLookinClientErrors.inner
        }
    }

    public func fetchSelectorNames(withClass className: String, hasArg: Bool) -> Single<[String]> {
        let query = WireSelectorQueryParams(className: className, hasArg: hasArg)
        return requestTyped(
            withType: UInt32(LookinRequestTypeAllSelectorNames),
            wirePayload: .selector(query)
        ) { data in
            if let list = data as? [String] {
                return list
            }
            if let list = data as? NSArray as? [String] {
                return list
            }
            throw LKLookinClientErrors.inner
        }
    }

    public func invokeMethod(withOid oid: UInt, text: String) -> Single<[String: Any]> {
        guard oid != 0, !text.isEmpty else {
            return .error(LKLookinClientErrors.inner)
        }
        let invoke = WireInvokeParams(oid: oid, text: text)
        return requestTyped(
            withType: UInt32(LookinRequestTypeInvokeMethod),
            wirePayload: .invoke(invoke)
        ) { data in
            guard let dict = data as? [String: Any] else {
                throw LKLookinClientErrors.inner
            }
            if (dict["description"] as? String) == LookinStringFlag_VoidReturn {
                var newValue = dict
                newValue["description"] = NSLocalizedString(
                    "The method was invoked successfully and no value was returned.",
                    comment: ""
                )
                return newValue
            }
            return dict
        }
    }

    public func fetchImage(withImageViewOid oid: UInt) -> Single<Data> {
        guard oid != 0 else {
            return .error(LKLookinClientErrors.inner)
        }
        return requestTyped(
            withType: UInt32(LookinRequestTypeFetchImageViewImage),
            wirePayload: .oid(oid)
        ) { data in
            if let imageData = data as? Data {
                return imageData
            }
            if let nsData = data as? NSData {
                return nsData as Data
            }
            throw LKLookinClientErrors.inner
        }
    }

    public func modifyGestureRecognizer(_ oid: UInt, toBeEnabled shouldBeEnabled: Bool) -> Completable {
        guard oid != 0 else {
            return .error(LKLookinClientErrors.inner)
        }
        let params = WireRecognizerParams(oid: oid, enable: shouldBeEnabled)
        return requestTyped(
            withType: UInt32(LookinRequestTypeModifyRecognizerEnable),
            wirePayload: .recognizer(params)
        ) { _ in () }
            .asCompletable()
    }

    // MARK: - Private

    private func push(withType pushType: UInt32, data: NSObject?) {
        guard let channel else { return }
        LKConnectionManager.sharedInstance.push(withType: pushType, data: data, channel: channel)
    }

    private func requestObservable(
        withType requestType: UInt32,
        wirePayload: WireClientRequestPayload
    ) -> Observable<Any?> {
        guard let channel else {
            return .error(LKLookinClientErrors.noConnect)
        }

        return LKConnectionManager.sharedInstance.request(
            withType: requestType,
            data: nil,
            channel: channel,
            wirePayload: wirePayload
        )
        .flatMap { pair -> Observable<Any?> in
            guard let attachment = Self.unwrapConnectionResponseAttachment(pair.first) else {
                NSLog(
                    "LookinClient - connection response unwrap failed, type: %@",
                    String(describing: type(of: pair.first as Any))
                )
                return .error(LKLookinClientErrors.inner)
            }
            if let error = attachment.error as NSError? {
                if error.code == LookinErrCode_ObjectNotFound {
                    return .error(LKLookinClientErrors.objectNotFound)
                }
                if error.code == LookinErrCode_Inner {
                    return .error(LKLookinClientErrors.inner)
                }
                return .error(error)
            }
            if requestType == UInt32(LookinRequestTypeInbuiltAttrModification),
               attachment.data as? LookinDisplayItemDetail == nil {
                LookinDiagLog.log("client wire inbuilt missing LookinDisplayItemDetail")
                return .error(LKLookinClientErrors.inner)
            }
            if requestType == UInt32(LookinRequestTypeInbuiltAttrModification),
               let detail = attachment.data as? LookinDisplayItemDetail {
                LookinDiagLog.log("client wire inbuilt detailOid=\(detail.displayItemOid)")
            }
            if requestType == UInt32(LookinRequestTypeCustomAttrModification) {
                LookinDiagLog.log("client wire custom ACK hasError=\(attachment.error != nil)")
            }
            return .just(attachment.data)
        }
    }

    private func requestTyped<T>(
        withType requestType: UInt32,
        wirePayload: WireClientRequestPayload,
        map: @escaping (Any?) throws -> T
    ) -> Single<T> {
        requestObservable(withType: requestType, wirePayload: wirePayload)
            .take(1)
            .asSingle()
            .map { try map($0) }
    }

    private func cancelRequest(withType requestType: UInt32) {
        guard let channel else { return }
        LKConnectionManager.sharedInstance.cancelRequest(withType: requestType, channel: channel)
    }
}
