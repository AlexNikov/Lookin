//
//  LKStaticHierarchyDataSource.swift
//  Lookin
//
//  Created by Li Kai on 2018/12/21.
//  https://lookin.work
//

import AppCenterAnalytics
import AppKit
import Foundation
import LookinShared
import RxRelay
import RxSwift

final class LKStaticHierarchyDataSource: LKHierarchyDataSource {
    static let sharedInstance = LKStaticHierarchyDataSource()

    private(set) var appInfo: LookinAppInfo?

    let itemsDidChangeFrameRelay = PublishRelay<LookinDisplayItem>()
    var itemsDidChangeFrame: Observable<LookinDisplayItem> {
        itemsDidChangeFrameRelay.asObservable()
    }

    private var shouldIgnoreFastModeAutoUpdate = false
    private var isUsingDanceUI = false
  /// Coalesced while `LKStaticAsyncUpdateManager` is fetching (avoids a second full 3D rebuild mid-batch).
    private var pendingHierarchyPreviewReload = false

    private override init() {
        super.init()
        // ObjC baseline does not refetch on selectedItem KVO — only via buildDisplayingFlatItems.
    }

    override func reload(with info: LookinHierarchyInfo, keepState: Bool) {
        // Wire v2 hierarchy omits appInfo unless the payload includes it — restore for preview centering.
        if info.appInfo == nil, let inspectingAppInfo = LKAppsManager.sharedInstance.inspectingApp?.appInfo {
            info.appInfo = inspectingAppInfo
        }

        // Strip before super.reload — didReloadHierarchyInfo renders 3D from flatItems.
        stripEmbeddedScreenshots(from: info.displayItems)

        super.reload(with: info, keepState: keepState)

        LKConnectionManager.sharedInstance.flushWireScreenshotBuffers(
            on: LKAppsManager.sharedInstance.inspectingApp?.channel
        )

        appInfo = info.appInfo
        guard let appInfo = info.appInfo, appInfo.screenScale > 0 else { return }
        let screenScale = max(appInfo.screenScale, 1)

        let maxLengthInPx = LookinNodeImageMaxLengthInPx - 100
        for obj in flatItems ?? [] {
            let widthInPx = obj.frame.size.width * screenScale
            let heightInPx = obj.frame.size.height * screenScale
            if widthInPx > maxLengthInPx || heightInPx > maxLengthInPx {
                obj.doNotFetchScreenshotReason = LookinDoNotFetchScreenshotReason.tooLarge
            }
        }

        updateMessageStatus()

        // Archive screenshots use drawHierarchy and bake descendants — drop all before detail fetch.
        flatItems?.forEach { item in
            item.soloScreenshot = nil
            item.groupScreenshot = nil
        }

        buildDisplayingFlatItems()

        let shouldUpdateAll = LKPreferenceMain().fastMode == false
        if shouldUpdateAll {
            LKStaticAsyncUpdateManager.sharedInstance.updateAll()
        }
    }

    /// Hierarchy archive embeds drawHierarchy screenshots (often with full subtree).
    private func stripEmbeddedScreenshots(from items: [LookinDisplayItem]?) {
        guard let items else { return }
        for item in items {
            item.soloScreenshot = nil
            item.groupScreenshot = nil
            stripEmbeddedScreenshots(from: item.subitems)
        }
    }

    func modify(with detail: LookinDisplayItemDetail?) {
        guard let detail else { return }
        guard let displayItem = displayItem(withOid: detail.displayItemOid) else {
            assertionFailure()
            return
        }

        let titleBefore    = displayItem.title()    ?? ""
        let subtitleBefore = displayItem.subtitle() ?? ""

        if let customDisplayTitle = detail.customDisplayTitle,
           !customDisplayTitle.isEmpty,
           customDisplayTitle != displayItem.customDisplayTitle {
            displayItem.customDisplayTitle = customDisplayTitle
        }
        if let danceUISource = detail.danceUISource {
            displayItem.danceuiSource = danceUISource
            if !isUsingDanceUI {
                isUsingDanceUI = true
                Analytics.trackEvent("UseDance")
            }
        }
        var screenshotChanged = false
        if let groupScreenshot = detail.groupScreenshot {
            displayItem.groupScreenshot = groupScreenshot
            screenshotChanged = true
        }
        if let soloScreenshot = detail.soloScreenshot {
            displayItem.soloScreenshot = soloScreenshot
            screenshotChanged = true
        }
        if screenshotChanged {
            refreshPreviewAppearanceUpToRoot(from: displayItem)
        }

        if detail.frameValue != nil || detail.boundsValue != nil {
            modifyDisplayItem(
                displayItem,
                newFrame: detail.frameValue?.rectValue ?? displayItem.frame,
                newBounds: detail.boundsValue?.rectValue ?? displayItem.bounds
            )
        }

        var didChangeHiddenAlpha = false
        if let hiddenValue = detail.hiddenValue, hiddenValue.boolValue != displayItem.isHidden {
            displayItem.isHidden = hiddenValue.boolValue
            didChangeHiddenAlpha = true
        }
        if let alphaValue = detail.alphaValue, alphaValue.floatValue != displayItem.alpha {
            displayItem.alpha = alphaValue.floatValue
            didChangeHiddenAlpha = true
        }
        if didChangeHiddenAlpha {
            itemDidChangeHiddenAlphaValueRelay.accept(displayItem)
        }

        var attrChanged = false
        if let attributesGroupList = detail.attributesGroupList, !attributesGroupList.isEmpty {
            displayItem.attributesGroupList = attributesGroupList
            attrChanged = true
        } else if didChangeHiddenAlpha {
            Self.syncVisibilityAttributes(on: displayItem)
            attrChanged = true
        }
        if let customAttrGroupList = detail.customAttrGroupList, !customAttrGroupList.isEmpty {
            displayItem.customAttrGroupList = customAttrGroupList
            attrChanged = true
        }
        if attrChanged {
            itemDidChangeAttrGroupRelay.accept(displayItem)
        }

        if let subitems = detail.subitems,
           (displayItem.subitems?.count ?? 0) > 0 || subitems.count > 0 {
            shouldIgnoreFastModeAutoUpdate = true

            switch state {
            case .focus:
                endFocus()
            case .search:
                endSearch()
            default:
                break
            }

            let flatItemsBefore = flatItems?.count ?? 0
            let oldSubitemOids = Self.oidList(from: displayItem.subitems)
            NSLog("LKStaticHierarchyDataSource - subitems for oid=%lu count=%d flatItems=%d",
                  detail.displayItemOid, subitems.count, flatItemsBefore)
            var expansionByOid: [UInt: Bool] = [:]
            flatItems?.forEach { item in
                if let oid = item.layerObject?.oid ?? item.viewObject?.oid {
                    expansionByOid[oid] = item.isExpanded
                }
            }

            displayItem.subitems = subitems
            let newRawFlatItems = LookinDisplayItem.flatItems(
                fromHierarchicalItems: rawHierarchyInfo?.displayItems ?? []
            )
            rawFlatItems = newRawFlatItems
            flatItems = rawFlatItems

            flatItems?.forEach { item in
                if let oid = item.layerObject?.oid ?? item.viewObject?.oid,
                   let wasExpanded = expansionByOid[oid] {
                    item.isExpanded = wasExpanded
                }
            }
            let newSubitemOids = Self.oidList(from: subitems)
            let treeStructureChanged = flatItemsBefore != newRawFlatItems.count
                || oldSubitemOids != newSubitemOids
            NSLog("LKStaticHierarchyDataSource - expansion restored for %d oids", expansionByOid.count)
            LKDebugEventLog.shared.record("modify_subitems", [
                "oid": detail.displayItemOid,
                "subitems_count": subitems.count,
                "flatItems_before": flatItemsBefore,
                "flatItems_after": newRawFlatItems.count,
                "treeStructureChanged": treeStructureChanged,
            ])

            if treeStructureChanged {
                if LKStaticAsyncUpdateManager.sharedInstance.isUpdating {
                    pendingHierarchyPreviewReload = true
                } else {
                    didReloadHierarchyInfoRelay.accept(())
                }
            }

            displayItem.enumerateSelfAndChildren { obj in
                if obj === displayItem { return }
                if !obj.isUserCustom(), !obj.shouldCaptureImage {
                    obj.enumerateSelfAndChildren { item in
                        item.noPreview = true
                        item.doNotFetchScreenshotReason = .userConfig
                    }
                }
                if let danceSource = obj.customInfo?.danceuiSource, !danceSource.isEmpty {
                    LKDanceUIAttrMaker.makeDanceUIJumpAttribute(obj, danceSource: danceSource)
                }
            }
            buildDisplayingFlatItems()
            shouldIgnoreFastModeAutoUpdate = false
        }

        let titleAfter    = displayItem.title()    ?? ""
        let subtitleAfter = displayItem.subtitle() ?? ""
        if titleBefore != titleAfter || subtitleBefore != subtitleAfter {
            NSLog("LKStaticHierarchyDataSource - title changed oid=%lu '%@'|'%@' → '%@'|'%@'",
                  detail.displayItemOid, titleBefore, subtitleBefore, titleAfter, subtitleAfter)
            LKDebugEventLog.shared.record("title_changed", [
                "oid": detail.displayItemOid,
                "title_before": titleBefore, "title_after": titleAfter,
                "subtitle_before": subtitleBefore, "subtitle_after": subtitleAfter,
            ])
        }

        LKVerifyCustomInfoLogger.logDetailModify(detail: detail, displayItem: displayItem)
    }

    override func buildDisplayingFlatItems() {
        super.buildDisplayingFlatItems()
        let fastMode = LKPreferenceMain().fastMode
        LKVerifyCustomInfoLogger.logAsyncUpdate(
            "buildDisplayingFlatItems count=\(displayingFlatItems?.count ?? 0) fastMode=\(fastMode) ignoreAuto=\(shouldIgnoreFastModeAutoUpdate)"
        )
        if ProcessInfo.processInfo.environment["LOOKIN_VERIFY_LOG"] != nil {
            if !shouldIgnoreFastModeAutoUpdate {
                LKStaticAsyncUpdateManager.sharedInstance.updateForDisplayingItems()
            }
            return
        }
        if fastMode, !shouldIgnoreFastModeAutoUpdate {
            LKStaticAsyncUpdateManager.sharedInstance.updateForDisplayingItems()
        }
    }

    override func preferenceManager() -> LKPreferenceManager {
        LKPreferenceMain()
    }

    override func isReadOnly() -> Bool {
        false
    }

    private func modifyDisplayItem(
        _ item: LookinDisplayItem,
        newFrame: CGRect,
        newBounds: CGRect
    ) {
        if item.frame == newFrame, item.bounds == newBounds {
            return
        }
        item.frame = newFrame
        item.bounds = newBounds
        itemsDidChangeFrameRelay.accept(item)
    }

    private func updateMessageStatus() {
        if serverSideIsSwiftProject, appInfo?.swiftEnabledInLookinServer == -1 {
            LKMessageManager.sharedInstance.addMessage(LKMessage_SwiftSubspec)
        } else {
            LKMessageManager.sharedInstance.removeMessage(LKMessage_SwiftSubspec)
        }

        if queryIfUsingNewestServerVersion() {
            LKMessageManager.sharedInstance.removeMessage(LKMessage_NewServerVersion)
        } else {
            LKMessageManager.sharedInstance.addMessage(LKMessage_NewServerVersion)
        }
    }

    func consumePendingHierarchyPreviewReload() -> Bool {
        let pending = pendingHierarchyPreviewReload
        pendingHierarchyPreviewReload = false
        return pending
    }

    /// Parent planes in 3D hide texture when children load; refresh ancestors after each screenshot chunk.
    private func refreshPreviewAppearanceUpToRoot(from item: LookinDisplayItem) {
        item.enumerateSelfAndAncestors { ancestor, _ in
            (ancestor.previewNode as? LKDisplayItemNode)?.refreshPreviewAppearance()
        }
    }

    private static func oidList(from items: [LookinDisplayItem]?) -> [UInt] {
        (items ?? []).map { $0.viewObject?.oid ?? $0.layerObject?.oid ?? 0 }
    }

    /// Patch/detail chunks may update `isHidden`/`alpha` without resending full attr groups.
    private static func syncVisibilityAttributes(on displayItem: LookinDisplayItem) {
        for group in displayItem.queryAllAttrGroupList() {
            for section in group.attrSections ?? [] {
                for attr in section.attributes ?? [] {
                    guard let id = attr.identifier else { continue }
                    if id == LookinAttr_ViewLayer_Visibility_Hidden {
                        attr.value = .bool(displayItem.isHidden)
                    } else if id == LookinAttr_ViewLayer_Visibility_Opacity {
                        attr.value = .double(Double(displayItem.alpha))
                    }
                }
            }
        }
    }

    private func queryIfUsingNewestServerVersion() -> Bool {
        let newestVersion = LKServerVersionRequestor.shared.query() ?? ""
        if newestVersion.isEmpty {
            return true
        }
        guard let appInfo else { return false }
        let userVersion = appInfo.serverReadableVersion
        Analytics.trackEvent("ServerVersion", withProperties: ["version": userVersion ?? ""])
        return LKVersionComparer.compare(withNewest: newestVersion, user: userVersion ?? "")
    }
}
