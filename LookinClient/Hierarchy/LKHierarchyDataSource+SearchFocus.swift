import AppCenterAnalytics
import AppKit
import LookinShared

private extension LookinDisplayItem {
    var isExpandedBeforeSearchOrFocus: Bool {
        get { lookin_getBindBOOL(forKey: "isExpandedBeforeSearching") }
        set { lookin_bindBOOL(newValue, forKey: "isExpandedBeforeSearching") }
    }
}

// MARK: - Search & Focus

extension LKHierarchyDataSource {
    func search(with string: String) {
        guard !string.isEmpty else {
            assertionFailure()
            return
        }

        if state != .search {
            rawFlatItems?.forEach { obj in
                obj.isExpandedBeforeSearchOrFocus = obj.isExpanded
            }
            state = .search
        }

        selectedItem = nil

        let keyShouldShow = "show"
        rawFlatItems?.forEach { displayItem in
            displayItem.lookin_bindBOOL(false, forKey: keyShouldShow)
            displayItem.highlightedSearchString = nil
        }

        rawFlatItems?.forEach { displayItem in
            if displayItem.isMatched(withSearchString: string) {
                displayItem.highlightedSearchString = string
                displayItem.enumerateAncestors { ancestor, _ in
                    ancestor.isExpanded = true
                    ancestor.lookin_bindBOOL(true, forKey: keyShouldShow)
                }
                displayItem.enumerateSelfAndChildren { selfOrChild in
                    selfOrChild.isExpanded = false
                    selfOrChild.lookin_bindBOOL(true, forKey: keyShouldShow)
                }
            }
        }

        let filteredItems = rawFlatItems?.lookin_filter { displayItem in
            let shouldShow = displayItem.lookin_getBindBOOL(forKey: keyShouldShow)
            if shouldShow {
                displayItem.isInSearch = true
            }
            return shouldShow
        } as? [LookinDisplayItem]

        flatItems = filteredItems
        didReloadFlatItemsWithSearchOrFocusRelay.accept(())
        buildDisplayingFlatItems()
    }

    func focusDisplayItem(_ item: LookinDisplayItem) {
        Analytics.trackEvent("Focus")

        if state == .normal {
            rawFlatItems?.forEach { obj in
                obj.isExpandedBeforeSearchOrFocus = obj.isExpanded
            }
        } else if state == .search {
            rawFlatItems?.forEach { obj in
                obj.isInSearch = false
                obj.highlightedSearchString = nil
            }
        }
        state = .focus

        var newFlatItems: [LookinDisplayItem] = []
        item.enumerateSelfAndChildren { currItem in
            newFlatItems.append(currItem)
        }
        flatItems = newFlatItems
        didReloadFlatItemsWithSearchOrFocusRelay.accept(())
        buildDisplayingFlatItems()
    }

    func endFocus() {
        guard state != .normal else { return }
        state = .normal

        rawFlatItems?.forEach { obj in
            obj.isExpanded = obj.isExpandedBeforeSearchOrFocus
        }

        flatItems = rawFlatItems
        didReloadFlatItemsWithSearchOrFocusRelay.accept(())
        buildDisplayingFlatItems()
    }

    func endSearch() {
        guard state != .normal else { return }
        state = .normal

        rawFlatItems?.forEach { obj in
            obj.isInSearch = false
            obj.highlightedSearchString = nil
            obj.isExpanded = obj.isExpandedBeforeSearchOrFocus
        }

        selectedItem?.enumerateAncestors { item, _ in
            item.isExpanded = true
        }

        flatItems = rawFlatItems
        didReloadFlatItemsWithSearchOrFocusRelay.accept(())
        buildDisplayingFlatItems()
    }
}
