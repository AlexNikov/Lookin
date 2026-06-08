import AppKit
import LookinShared

// MARK: - Expansion

extension LKHierarchyDataSource {
    func adjustExpansionByIndex(
        _ index: Int,
        referenceDict: [NSNumber: NSNumber]?,
        selectedItem outputSelectedItem: UnsafeMutablePointer<LookinDisplayItem?>?
    ) {
        LKDebugEventLog.shared.record("adjust_expansion", [
            "index": index,
            "hasReferenceDict": referenceDict != nil,
        ])
        var index = index
        if index < 0 || index > 4 {
            assertionFailure("adjustExpansionByIndex, index 为 \(index)")
            index = max(min(index, 4), 0)
        }

        preferenceManager().expansionIndex = index

        var expandedCount = flatItems?.count ?? 0
        flatItems?.forEach { obj in
            obj.hasDeterminedExpansion = false

            if !obj.isExpandable {
                obj.hasDeterminedExpansion = true
                expandedCount -= 1
                return
            }

            if let referenceDict,
               let oid = obj.layerObject?.oid,
               let prevState = referenceDict[NSNumber(value: oid)] {
                obj.isExpanded = prevState.boolValue
                obj.hasDeterminedExpansion = true
                if !obj.isExpanded {
                    expandedCount -= 1
                }
            }
        }

        if index == 0 {
            var preferedSelectedItem: LookinDisplayItem?
            flatItems?.forEach { obj in
                if obj.hasDeterminedExpansion { return }
                obj.isExpanded = false
                if obj.representedAsKeyWindow {
                    preferedSelectedItem = obj
                }
            }
            outputSelectedItem?.pointee = preferedSelectedItem

        } else if index == 4 {
            flatItems?.forEach { obj in
                if obj.hasDeterminedExpansion { return }
                if obj.inNoPreviewHierarchy {
                    obj.isExpanded = false
                    return
                }
                obj.isExpanded = true
            }

            if outputSelectedItem != nil {
                var preferedSelectedItem: LookinDisplayItem?
                let keyWindowRootItem = rawHierarchyInfo?.displayItems?.first { $0.representedAsKeyWindow }

                if let keyWindowRootItem {
                    let keyWindowFlatItems = LookinDisplayItem.flatItems(fromHierarchicalItems: [keyWindowRootItem])
                    for obj in keyWindowFlatItems.reversed() {
                        if obj.hostViewControllerObject != nil {
                            preferedSelectedItem = obj
                            break
                        }
                    }
                }
                outputSelectedItem?.pointee = preferedSelectedItem
            }

        } else {
            var keyWindowItem = rawHierarchyInfo?.displayItems?.first { $0.representedAsKeyWindow }
            if keyWindowItem == nil {
                keyWindowItem = rawHierarchyInfo?.displayItems?.first
            }

            rawHierarchyInfo?.displayItems?.forEach { windowItem in
                if windowItem === keyWindowItem { return }
                let windowFlatItems = LookinDisplayItem.flatItems(fromHierarchicalItems: [windowItem])
                windowFlatItems.forEach { obj in
                    if obj.hasDeterminedExpansion { return }
                    obj.isExpanded = false
                    obj.hasDeterminedExpansion = true
                }
            }

            let uiTransitionViewItems = (keyWindowItem?.subitems as? [LookinDisplayItem])?.lookin_filter { obj in
                obj.title() == "UITransitionView"
            } as? [LookinDisplayItem] ?? []

            for (idx, obj) in uiTransitionViewItems.enumerated() {
                if obj.hasDeterminedExpansion { continue }
                if idx == uiTransitionViewItems.count - 1 {
                    obj.isExpanded = true
                } else {
                    obj.isExpanded = false
                }
                obj.hasDeterminedExpansion = true
            }

            var viewControllerItems: [LookinDisplayItem] = []
            if let keyWindowItem {
                let keyWindowFlatItems = LookinDisplayItem.flatItems(fromHierarchicalItems: [keyWindowItem])
                for obj in keyWindowFlatItems {
                    if obj.hostViewControllerObject != nil {
                        viewControllerItems.append(obj)
                        continue
                    }
                    if obj.hasDeterminedExpansion { continue }
                    if obj.inNoPreviewHierarchy || obj.preferToBeCollapsed
                        || (!LKPreferenceMain().showHiddenItems && obj.inHiddenHierarchy) {
                        obj.isExpanded = false
                        obj.hasDeterminedExpansion = true
                        continue
                    }
                    if obj.itemIsKindOfClasses(withNames: ["UINavigationBar", "UITabBar"]) {
                        obj.enumerateSelfAndChildren { item in
                            if item.hasDeterminedExpansion { return }
                            item.isExpanded = false
                            item.hasDeterminedExpansion = true
                        }
                    }
                }
            }

            outputSelectedItem?.pointee = viewControllerItems.last

            if index == 1 {
                for viewControllerItem in viewControllerItems.reversed() {
                    viewControllerItem.enumerateSelfAndAncestors { item, _ in
                        if item.hasDeterminedExpansion { return }
                        item.isExpanded = item !== viewControllerItem
                        item.hasDeterminedExpansion = true
                    }
                }
                flatItems?.forEach { obj in
                    if obj.hasDeterminedExpansion { return }
                    obj.isExpanded = false
                }

            } else if index == 2 {
                for viewControllerItem in viewControllerItems.reversed() {
                    viewControllerItem.enumerateAncestors { item, _ in
                        if item.hasDeterminedExpansion { return }
                        item.isExpanded = true
                        item.hasDeterminedExpansion = true
                    }

                    let hasTableOrCollectionView = viewControllerItem.subitems?.first?
                        .itemIsKindOfClasses(withNames: ["UITableView", "UICollectionView"]) ?? false
                    let indentsForward: Int = hasTableOrCollectionView ? 2 : 3

                    viewControllerItem.enumerateSelfAndChildren { item in
                        if item.hasDeterminedExpansion { return }
                        if item.indentLevel() < viewControllerItem.indentLevel() + indentsForward {
                            item.isExpanded = true
                            item.hasDeterminedExpansion = true
                        }
                    }
                }
                flatItems?.forEach { obj in
                    if obj.hasDeterminedExpansion { return }
                    obj.isExpanded = false
                }

            } else if index == 3 {
                flatItems?.forEach { obj in
                    if obj.hasDeterminedExpansion { return }
                    obj.isExpanded = true
                    obj.hasDeterminedExpansion = true
                }
            }
        }

        buildDisplayingFlatItems()
    }

    func collapseItem(_ item: LookinDisplayItem) {
        guard item.isExpandable, item.isExpanded else { return }
        let oid = item.layerObject?.oid ?? item.viewObject?.oid ?? 0
        NSLog("LKHierarchyDataSource - collapseItem oid=%lu title=%@", UInt(oid), item.title() ?? "?")
        LKDebugEventLog.shared.record("collapse", ["oid": UInt(oid), "title": item.title() ?? ""])
        item.isExpanded = false
        buildDisplayingFlatItems()
        reconcileSelectedItemAfterExpansionChange()
    }

    func expandItem(_ item: LookinDisplayItem) {
        guard item.isExpandable, !item.isExpanded else { return }
        let oid = item.layerObject?.oid ?? item.viewObject?.oid ?? 0
        NSLog("LKHierarchyDataSource - expandItem oid=%lu title=%@", UInt(oid), item.title() ?? "?")
        LKDebugEventLog.shared.record("expand", ["oid": UInt(oid), "title": item.title() ?? "?"])
        item.isExpanded = true
        buildDisplayingFlatItems()
        reconcileSelectedItemAfterExpansionChange()
    }

    func expandToShowItem(_ item: LookinDisplayItem) {
        item.enumerateAncestors { targetItem, _ in
            if !targetItem.isExpanded {
                targetItem.isExpanded = true
            }
        }
        buildDisplayingFlatItems()
    }

    func expandItemsRooted(by item: LookinDisplayItem) {
        if item.preferToBeCollapsed {
            item.enumerateSelfAndChildren { targetItem in
                if targetItem.isExpandable, !targetItem.isExpanded {
                    targetItem.isExpanded = true
                }
            }
        } else {
            item.enumerateSelfAndChildren { targetItem in
                if targetItem.isExpandable, !targetItem.isExpanded, !targetItem.preferToBeCollapsed {
                    targetItem.isExpanded = true
                }
            }
        }
        buildDisplayingFlatItems()
    }

    func collapseAllChildren(of item: LookinDisplayItem) {
        item.enumerateSelfAndChildren { enumeratedItem in
            if enumeratedItem === item { return }
            guard enumeratedItem.isExpandable, enumeratedItem.isExpanded else { return }
            enumeratedItem.isExpanded = false
        }
        buildDisplayingFlatItems()
        reconcileSelectedItemAfterExpansionChange()
    }

    func reconcileSelectedItemAfterExpansionChange() {
        guard let selected = selectedItem else { return }
        if selected.displayingInHierarchy { return }

        var candidate: LookinDisplayItem? = selected
        while let item = candidate, !item.displayingInHierarchy {
            candidate = item.superItem
        }
        if let candidate, candidate.displayingInHierarchy, candidate !== selected {
            selectedItem = candidate
        } else if !selected.displayingInHierarchy {
            selectedItem = displayingFlatItems?.first
        }
    }
}
