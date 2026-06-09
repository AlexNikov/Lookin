//
//  LKStaticAsyncUpdateManager.swift
//  Lookin
//
//  Created by Li Kai on 2019/2/19.
//  https://lookin.work
//

import AppKit
import Foundation
import LookinShared
import RxRelay
import RxSwift

struct LKModifyingUpdateProgress {
    let received: Int
    let total: Int
}

private enum LKDetailRequestKind {
    case bulk
}

protocol LKStaticAsyncUpdateManagerDelegate: AnyObject {
    func detailUpdateTasksTotalCount(_ totalCount: UInt, finishedCount: UInt)
    func detailUpdateReceivedError(_ error: NSError)
}

final class LKStaticAsyncUpdateManager: NSObject {
    static let sharedInstance = LKStaticAsyncUpdateManager()

    weak var delegate: LKStaticAsyncUpdateManagerDelegate?

    private let modifyingUpdateProgressRelay = PublishRelay<LKModifyingUpdateProgress>()
    var modifyingUpdateProgress: Observable<LKModifyingUpdateProgress> {
        modifyingUpdateProgressRelay.asObservable()
    }

    private let modifyingUpdateErrorRelay = PublishRelay<NSError>()
    var modifyingUpdateError: Observable<NSError> {
        modifyingUpdateErrorRelay.asObservable()
    }

    private var succeededRequests: [LKDetailUpdateRequest] = []
    private var ongoingRequest: LKDetailUpdateRequest?
    private var detailUpdateDisposable: Disposable?
    private var modifyPatchDisposable: Disposable?
    private var selectionAttrFetchDisposable: Disposable?
    private var selectionAttrFetchWorkItem: DispatchWorkItem?
    private var selectionAttrFetchGeneration: UInt = 0
    private let disposeBag = DisposeBag()

    private override init() {
        super.init()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.dataSource.willReloadHierarchyInfo
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] _ in
                    self?.cancelScheduledSelectionAttributesFetch()
                    self?.cancelPendingSelectionAttributeRequest()
                    self?.succeededRequests.removeAll()
                })
                .disposed(by: self.disposeBag)

            // On real device the Peertalk watchdog can drop the channel mid-inspection.
            // When inspectingApp transitions nil→non-nil (auto-reconnect), re-schedule
            // attr fetch for whatever item is already selected but still has no attrs.
            LKAppsManager.sharedInstance.inspectingAppObservable
                .scan((nil as LKInspectableApp?, nil as LKInspectableApp?)) { ($0.1, $1) }
                .filter { prev, curr in prev == nil && curr != nil }
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] _ in
                    guard let self else { return }
                    let selected = self.dataSource.selectedItem
                    guard let selected, selected.queryAllAttrGroupList().isEmpty else { return }
                    self.scheduleSelectedItemAttributesFetch(selected)
                })
                .disposed(by: self.disposeBag)
        }
    }

    func updateAll() {
        assert(LKPreferenceMain().fastMode == false)
        guard LKAppsManager.sharedInstance.inspectingApp != nil,
              !(dataSource.flatItems?.isEmpty ?? true) else {
            return
        }
        endUpdating()

        let allTasks = makeMaximumTasks()
        guard !allTasks.isEmpty else { return }
        let visibleOids = Set(
            (dataSource.displayingFlatItems ?? []).compactMap(\.layerObject?.oid).filter { $0 != 0 }
        )
        var visibleTasks: [LookinStaticAsyncUpdateTask] = []
        var deferredTasks: [LookinStaticAsyncUpdateTask] = []
        for task in allTasks {
            if visibleOids.contains(task.oid) {
                visibleTasks.append(task)
            } else {
                deferredTasks.append(task)
            }
        }
        if visibleTasks.isEmpty {
            sendTasks(allTasks, completion: nil)
            return
        }
        sendTasks(visibleTasks) { [weak self] in
            guard let self, !deferredTasks.isEmpty else { return }
            self.sendTasks(deferredTasks, completion: nil)
        }
    }

    func endUpdating() {
        guard ongoingRequest != nil else { return }
        NSLog("AsyncUpdate - endUpdating")
        // Drop the Rx subscription and token before cancel — cancelRequest invokes completionBlock,
        // which must not run batch-finish side effects (alerts / preview rebuild) for a user stop.
        detailUpdateDisposable?.dispose()
        detailUpdateDisposable = nil
        ongoingRequest = nil
        notifyTasksCountToDelegate()
        LKAppsManager.sharedInstance.inspectingApp?.cancelHierarchyDetailFetching()
    }

    func updateForDisplayingItems() {
        if !LKPreferenceMain().fastMode,
           ProcessInfo.processInfo.environment["LOOKIN_VERIFY_LOG"] == nil {
            LKVerifyCustomInfoLogger.logAsyncUpdate("updateForDisplayingItems skipped — fastMode=false")
            return
        }
        guard LKAppsManager.sharedInstance.inspectingApp != nil else {
            LKVerifyCustomInfoLogger.logAsyncUpdate("updateForDisplayingItems skipped — no app")
            return
        }
        let items = LKStaticHierarchyDataSource.sharedInstance.displayingFlatItems
        guard let items, !items.isEmpty else {
            LKVerifyCustomInfoLogger.logAsyncUpdate("updateForDisplayingItems skipped — no displaying items")
            return
        }
        let newTasks = makeMinimumTasks(for: items)
        LKVerifyCustomInfoLogger.logAsyncUpdate(
            "updateForDisplayingItems items=\(items.count) tasks=\(newTasks.count)"
        )
        guard !newTasks.isEmpty else { return }
        sendTasks(newTasks, completion: nil)
    }

    func updateAfterModifyingDisplayItem(_ displayItem: LookinDisplayItem?) {
        guard let app = LKAppsManager.sharedInstance.inspectingApp else { return }
        guard let displayItem else {
            assertionFailure()
            return
        }

        var tasks: [LookinStaticAsyncUpdateTask] = []
        displayItem.enumerateSelfAndAncestors { item, _ in
            if item.doNotFetchScreenshotReason != .permitted { return }
            if item === displayItem, !(item.subitems?.isEmpty ?? true) {
                tasks.append(self.task(from: item, type: .soloScreenshot))
            }
            tasks.append(self.task(from: item, type: .groupScreenshot))
        }

        modifyingUpdateProgressRelay.accept(LKModifyingUpdateProgress(received: 0, total: 0))

        let screenshotsTotalCount = tasks.count
        var receivedScreenshotsCount = 0

        modifyPatchDisposable?.dispose()
        modifyPatchDisposable = app.fetchModificationPatch(withTasks: tasks)
            .observe(on: MainScheduler.instance)
            .subscribe(with: self, onNext: { owner, detail in
                LKStaticHierarchyDataSource.sharedInstance.modify(with: detail)

                if detail.groupScreenshot != nil {
                    receivedScreenshotsCount += 1
                }
                if detail.soloScreenshot != nil {
                    receivedScreenshotsCount += 1
                }
                owner.modifyingUpdateProgressRelay.accept(
                    LKModifyingUpdateProgress(
                        received: receivedScreenshotsCount,
                        total: screenshotsTotalCount
                    )
                )
            }, onError: { owner, error in
                assertionFailure()
                owner.modifyingUpdateErrorRelay.accept(error as NSError)
            }, onCompleted: { owner in
                owner.modifyingUpdateProgressRelay.accept(
                    LKModifyingUpdateProgress(
                        received: screenshotsTotalCount,
                        total: screenshotsTotalCount
                    )
                )
            })
    }

    var isUpdating: Bool {
        ongoingRequest != nil
    }

    func reloadSingleDisplayItem(_ item: LookinDisplayItem?) {
        guard let item, let tasks = LKReloadSingleItemUpdateTaskMaker.make(with: item), !tasks.isEmpty else {
            return
        }
        sendTasks(tasks, completion: nil)
    }

    /// Coalesce rapid hierarchy clicks — attrs only (no screenshot) to avoid Peertalk timeouts.
    func scheduleSelectedItemAttributesFetch(_ item: LookinDisplayItem?) {
        selectionAttrFetchWorkItem?.cancel()
        cancelPendingSelectionAttributeRequest()
        guard let item, !item.isUserCustom() else { return }
        guard item.queryAllAttrGroupList().isEmpty else { return }

        selectionAttrFetchGeneration &+= 1
        let generation = selectionAttrFetchGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self, generation == self.selectionAttrFetchGeneration else { return }
            self.fetchSelectedItemAttributesIfNeeded(item)
        }
        selectionAttrFetchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + LKUITiming.previewLayoutSettle, execute: work)
    }

    private func cancelScheduledSelectionAttributesFetch() {
        selectionAttrFetchWorkItem?.cancel()
        selectionAttrFetchWorkItem = nil
        selectionAttrFetchGeneration &+= 1
    }

    private func cancelPendingSelectionAttributeRequest() {
        selectionAttrFetchDisposable?.dispose()
        selectionAttrFetchDisposable = nil
    }

    private func fetchSelectedItemAttributesIfNeeded(_ item: LookinDisplayItem) {
        guard !item.isUserCustom() else { return }
        guard item.queryAllAttrGroupList().isEmpty else { return }
        guard let app = LKAppsManager.sharedInstance.inspectingApp else { return }
        guard let oid = item.layerObject?.oid, oid != 0 else { return }

        // AllAttrGroups is a separate request type — safe alongside bulk HierarchyDetails (no cancel push).
        cancelPendingSelectionAttributeRequest()
        selectionAttrFetchDisposable = LookinRACSignalRx.observeMainThread(
            app.fetchAttrGroupList(withOid: oid)
        )
        .subscribe(with: self, onSuccess: { owner, groups in
            owner.selectionAttrFetchDisposable = nil
            guard owner.dataSource.selectedItem?.layerObject?.oid == oid else { return }
            guard let displayItem = owner.dataSource.displayItem(withOid: oid) else { return }
            guard displayItem.queryAllAttrGroupList().isEmpty else { return }
            guard !groups.isEmpty else {
                owner.scheduleSelectedItemAttributesFetch(displayItem)
                return
            }
            displayItem.attributesGroupList = groups
            owner.dataSource.itemDidChangeAttrGroupRelay.accept(displayItem)
        }, onFailure: { owner, error in
            owner.selectionAttrFetchDisposable = nil
            let nsError = error as NSError
            if nsError.code == Int(LookinErrCode_Discard) { return }
            if owner.dataSource.selectedItem?.layerObject?.oid == oid {
                owner.scheduleSelectedItemAttributesFetch(item)
            }
        })
    }

    func reloadDisplayItemAndChildren(_ rootItem: LookinDisplayItem?) {
        guard let rootItem,
              let tasks = LKReloadItemAndChildrenUpdateTaskMaker.make(with: rootItem),
              !tasks.isEmpty else {
            return
        }

        rootItem.enumerateSelfAndChildren { item in
            item.soloScreenshot = nil
            item.groupScreenshot = nil
            for req in self.succeededRequests {
                req.removeTask(with: item)
            }
        }

        sendTasks(tasks) { [weak self] in
            self?.updateAfterReloadingItemAndChildren(rootItem)
        }
    }

    private var dataSource: LKStaticHierarchyDataSource {
        LKStaticHierarchyDataSource.sharedInstance
    }

    private func makeMaximumTasks() -> [LookinStaticAsyncUpdateTask] {
        var tasks: [LookinStaticAsyncUpdateTask] = (dataSource.displayingFlatItems ?? []).compactMap { item in
            if item.isUserCustom() { return nil }
            if item.doNotFetchScreenshotReason == .permitted {
                if item.isExpandable, item.isExpanded {
                    return task(from: item, type: .soloScreenshot)
                }
                return task(from: item, type: .groupScreenshot)
            }
            return task(from: item, type: .noScreenshot)
        }

        for item in dataSource.flatItems ?? [] {
            if item.isUserCustom() { continue }
            if item.doNotFetchScreenshotReason == .permitted {
                let groupTask = task(from: item, type: .groupScreenshot)
                if !tasks.contains(groupTask) {
                    tasks.append(groupTask)
                }
                // Solo on collapsed expandables bakes children into the parent plane in 3D (Fast Mode OFF).
                if item.isExpandable, item.isExpanded {
                    let soloTask = task(from: item, type: .soloScreenshot)
                    if !tasks.contains(soloTask) {
                        tasks.append(soloTask)
                    }
                }
            } else {
                let noShotTask = task(from: item, type: .noScreenshot)
                if !tasks.contains(noShotTask) {
                    tasks.append(noShotTask)
                }
            }
        }
        return tasks
    }

    private func makeMinimumTasks(for items: [LookinDisplayItem]) -> [LookinStaticAsyncUpdateTask] {
        var itemsToScan = items
        if let selected = dataSource.selectedItem,
           !selected.isUserCustom(),
           selected.queryAllAttrGroupList().isEmpty,
           !itemsToScan.contains(where: { $0 === selected }) {
            itemsToScan.insert(selected, at: 0)
        }

        var skippedCustom = 0
        var skippedHasScreenshot = 0
        var skippedHasAttrs = 0
        var skippedDuplicate = 0
        let tasks = itemsToScan.compactMap { item -> LookinStaticAsyncUpdateTask? in
            if item.isUserCustom() {
                skippedCustom += 1
                return nil
            }

            let hasScreenshotForCurrentMode: Bool = {
                if item.isExpandable, item.isExpanded {
                    return item.soloScreenshot != nil
                }
                return item.appropriateScreenshot() != nil
            }()
            if hasScreenshotForCurrentMode,
               !(item.attributesGroupList?.isEmpty ?? true) || !(item.customAttrGroupList?.isEmpty ?? true) {
                skippedHasScreenshot += 1
                return nil
            }

            var newTask: LookinStaticAsyncUpdateTask?
            if item.doNotFetchScreenshotReason == .permitted {
                if item.isExpandable, item.isExpanded {
                    newTask = task(from: item, type: .soloScreenshot)
                } else {
                    newTask = task(from: item, type: .groupScreenshot)
                }
            } else if !(item.attributesGroupList?.isEmpty ?? true) {
                skippedHasAttrs += 1
                return nil
            } else {
                newTask = task(from: item, type: .noScreenshot)
            }

            guard var newTask else { return nil }

            if item.attributesGroupList?.isEmpty ?? true {
                newTask.attrRequest = .need
            } else {
                newTask.attrRequest = .notNeed
            }

            for req in succeededRequests where req.queryIfContains(task: newTask) {
                if item === dataSource.selectedItem, item.queryAllAttrGroupList().isEmpty {
                    break
                }
                skippedDuplicate += 1
                return nil
            }
            return newTask
        }
        LKVerifyCustomInfoLogger.logAsyncUpdate(
            "makeMinimumTasks skipped custom=\(skippedCustom) screenshot=\(skippedHasScreenshot) attrs=\(skippedHasAttrs) duplicate=\(skippedDuplicate) created=\(tasks.count)"
        )
        return tasks
    }

    private func sendTasks(
        _ newTasks: [LookinStaticAsyncUpdateTask],
        kind: LKDetailRequestKind = .bulk,
        completion: (() -> Void)?
    ) {
        guard let app = LKAppsManager.sharedInstance.inspectingApp, !newTasks.isEmpty else {
            return
        }
        cancelScheduledSelectionAttributesFetch()
        cancelPendingSelectionAttributeRequest()
        detailUpdateDisposable?.dispose()
        detailUpdateDisposable = nil
        endUpdating()

        let packages = makePackages(from: newTasks)
        let request = LKDetailUpdateRequest()
        request.kind = kind
        request.packages = packages
        ongoingRequest = request

        notifyTasksCountToDelegate()
        NSLog("AsyncUpdate - Will send %@ tasks.", NSNumber(value: newTasks.count))
        LKVerifyCustomInfoLogger.logAsyncUpdate("send \(newTasks.count) tasks")

        let requestToken = request
        detailUpdateDisposable = LookinRACSignalRx.observeMainThread(
            app.fetchHierarchyDetail(withTaskPackages: packages)
        )
        .subscribe(with: self, onNext: { owner, details in
            guard owner.ongoingRequest === requestToken else { return }

            if !details.isEmpty {
                LKVerifyCustomInfoLogger.logAsyncUpdate(
                    "chunk \(details.count) detail(s), firstOid=\(details[0].displayItemOid)"
                )
            }
            for detail in details {
                if detail.failureCode == -1 {
                    requestToken.failedTasksCount += 1
                } else {
                    LKStaticHierarchyDataSource.sharedInstance.modify(with: detail)
                }
            }
            // One Peertalk progress frame == one task (ObjC: details.count is usually 1).
            requestToken.finishedTasksCount += 1
            owner.notifyTasksCountToDelegate()
        }, onError: { owner, error in
            guard owner.ongoingRequest === requestToken else { return }
            owner.ongoingRequest = nil
            owner.detailUpdateDisposable = nil
            owner.notifyTasksCountToDelegate()

            let nsError = error as NSError
            if nsError.code == Int(LookinErrCode_Discard) {
                return
            }

            let alertError: NSError
            if nsError.code == Int(LookinErrCode_Timeout) {
                let msgTitle = NSLocalizedString(
                    "Request timeout, layer data transmission failed.",
                    comment: ""
                )
                let msgDetail = NSLocalizedString(
                    "Perhaps your iOS app is paused with breakpoint in Xcode, blocked by other tasks in main thread, or moved to background state.\nToo large screenshots may also lead to this error.",
                    comment: ""
                )
                alertError = LookinErrorMake(msgTitle, msgDetail)
            } else {
                alertError = nsError
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + LKUITiming.asyncUpdateCoalesce) {
                guard owner.ongoingRequest == nil else { return }
                owner.delegate?.detailUpdateReceivedError(alertError)
                if requestToken.kind == .bulk,
                   let selected = owner.dataSource.selectedItem,
                   selected.queryAllAttrGroupList().isEmpty {
                    owner.scheduleSelectedItemAttributesFetch(selected)
                }
            }
        }, onCompleted: { owner in
            guard owner.ongoingRequest === requestToken else { return }
            let completedKind = requestToken.kind
            let userCancel = requestToken.tasksTotalCount > requestToken.finishedTasksCount
            if !userCancel {
                owner.succeededRequests.append(requestToken)
            }
            if requestToken.failedTasksCount > 0, !userCancel {
                let error = LookinErrorMake(
                    NSLocalizedString("Some layer data failed to transmit.", comment: ""),
                    NSLocalizedString(
                        "It may be due to changes in the layer structure within the iOS app. You can try reloading the entire structure in Lookin.",
                        comment: ""
                    )
                )
                owner.delegate?.detailUpdateReceivedError(error)
            }
            owner.ongoingRequest = nil
            owner.detailUpdateDisposable = nil
            owner.notifyTasksCountToDelegate()
            LKPerformanceReporter.sharedInstance.didComplete()
            if completedKind == .bulk,
               let selectedItem = owner.dataSource.selectedItem,
               selectedItem.queryAllAttrGroupList().isEmpty {
                owner.scheduleSelectedItemAttributesFetch(selectedItem)
            }
            if let selectedItem = owner.dataSource.selectedItem,
               !selectedItem.queryAllAttrGroupList().isEmpty {
                owner.dataSource.itemDidChangeAttrGroupRelay.accept(selectedItem)
            }
            LKConnectionManager.sharedInstance.flushWireScreenshotBuffers(
                on: LKAppsManager.sharedInstance.inspectingApp?.channel
            )
            if owner.dataSource.consumePendingHierarchyPreviewReload() {
                owner.dataSource.didReloadHierarchyInfoRelay.accept(())
            } else {
                owner.refreshAllPreviewNodesAfterBatchUpdate()
                if (LKPreviewView.sharedForMCP?.mcpDebugInfo()["displayItemNodesCount"] as? Int ?? 0) == 0 {
                    owner.dataSource.didReloadHierarchyInfoRelay.accept(())
                }
            }
            completion?()
        })
    }

    private func updateAfterReloadingItemAndChildren(_ rootItem: LookinDisplayItem) {
        if LKPreferenceMain().fastMode {
            updateForDisplayingItems()
        } else {
            var tasks: [LookinStaticAsyncUpdateTask] = []
            rootItem.enumerateSelfAndChildren { item in
                if item.isUserCustom() { return }
                if item.doNotFetchScreenshotReason == .permitted {
                    tasks.append(self.task(from: item, type: .groupScreenshot))
                    if item.isExpandable {
                        tasks.append(self.task(from: item, type: .soloScreenshot))
                    }
                } else {
                    tasks.append(self.task(from: item, type: .noScreenshot))
                }
            }
            sendTasks(tasks, completion: nil)
        }
    }

    private func makePackages(from tasks: [LookinStaticAsyncUpdateTask]) -> [LookinStaticAsyncUpdateTasksPackage] {
        var packages: [LookinStaticAsyncUpdateTasksPackage] = []
        var bufferTasks: [LookinStaticAsyncUpdateTask] = []
        var packageTotalArea: CGFloat = 0
        let packageMaxArea: CGFloat = 2_000_000
        let packageMaxTasksCount = 100

        for task in tasks {
            let currentArea = task.frameSize.width * task.frameSize.height
            if packageTotalArea + currentArea > packageMaxArea || bufferTasks.count >= packageMaxTasksCount {
                if !bufferTasks.isEmpty {
                    packageTotalArea = 0
                    var package = LookinStaticAsyncUpdateTasksPackage()
                    package.tasks = bufferTasks
                    packages.append(package)
                    bufferTasks.removeAll()
                }
            }
            packageTotalArea += currentArea
            bufferTasks.append(task)
        }

        if !bufferTasks.isEmpty {
            var package = LookinStaticAsyncUpdateTasksPackage()
            package.tasks = bufferTasks
            packages.append(package)
        }
        return packages
    }

    private func task(
        from item: LookinDisplayItem,
        type: LookinStaticAsyncUpdateTaskType
    ) -> LookinStaticAsyncUpdateTask {
        var task = LookinStaticAsyncUpdateTask()
        task.oid = item.layerObject?.oid ?? 0
        task.frameSize = item.frame.size
        task.taskType = type
        task.clientReadableVersion = LKHelper.lookinReadableVersion()
        return task
    }

    private func refreshAllPreviewNodesAfterBatchUpdate() {
        dataSource.flatItems?.forEach { item in
            (item.previewNode as? LKDisplayItemNode)?.refreshPreviewAppearance()
        }
    }

    private func notifyTasksCountToDelegate() {
        guard let ongoingRequest else {
            delegate?.detailUpdateTasksTotalCount(0, finishedCount: 0)
            return
        }
        var totalCount = 0
        for pack in ongoingRequest.packages ?? [] {
            totalCount += pack.tasks?.count ?? 0
        }
        let finishedCount = ongoingRequest.finishedTasksCount
        NSLog("AsyncUpdate - notify delagate: %@/%@", NSNumber(value: finishedCount), NSNumber(value: totalCount))
        delegate?.detailUpdateTasksTotalCount(UInt(totalCount), finishedCount: UInt(finishedCount))
    }
}

// MARK: - LKDetailUpdateRequest

private final class LKDetailUpdateRequest: NSObject {
    var kind: LKDetailRequestKind = .bulk
    var packages: [LookinStaticAsyncUpdateTasksPackage]?
    var finishedTasksCount = 0
    var failedTasksCount = 0

    var tasksTotalCount: Int {
        packages?.reduce(0) { $0 + ($1.tasks?.count ?? 0) } ?? 0
    }

    func queryIfContains(task: LookinStaticAsyncUpdateTask) -> Bool {
        for pack in packages ?? [] {
            if pack.tasks?.contains(task) == true {
                return true
            }
        }
        return false
    }

    func removeTask(with item: LookinDisplayItem) {
        guard var packs = packages else { return }
        for index in packs.indices {
            packs[index].tasks = packs[index].tasks?.lookin_filter { task in
                task.oid != item.layerObject!.oid
            }
        }
        packages = packs
    }
}
