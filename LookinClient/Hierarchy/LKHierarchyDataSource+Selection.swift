import AppKit
import LookinShared
import RxRelay
import RxSwift

// MARK: - Selection & hover

extension LKHierarchyDataSource {
    var selectedItemObservable: Observable<LookinDisplayItem?> {
        selectedItemTick
            .startWith(())
            .map { [weak self] in self?._selectedItem }
            .distinctUntilChanged { $0 === $1 }
    }

    var selectedItem: LookinDisplayItem? {
        get { _selectedItem }
        set { updateSelectedItem(newValue) }
    }

    var hoveredItemObservable: Observable<LookinDisplayItem?> {
        hoveredItemTick
            .startWith(())
            .map { [weak self] in self?._hoveredItem }
            .distinctUntilChanged { $0 === $1 }
    }

    var hoveredItem: LookinDisplayItem? {
        get { _hoveredItem }
        set { updateHoveredItem(newValue) }
    }

    func updateSelectedItem(_ newValue: LookinDisplayItem?) {
        if _selectedItem === newValue { return }
        let prevSelected = _selectedItem
        _selectedItem = newValue
        prevSelected?.notifySelectionChangeToDelegates()
        _selectedItem?.notifySelectionChangeToDelegates()
        selectedItemTick.accept(())
        LKUserActionManager.sharedInstance.send(.selectedItemChange)
        if NSColorPanel.sharedColorPanelExists {
            NSColorPanel.shared.close()
        }
        if newValue == nil,
           preferenceManager().measureState != .no {
            preferenceManager().measureState = .no
        }
    }

    func updateHoveredItem(_ newValue: LookinDisplayItem?) {
        if _hoveredItem === newValue { return }
        let prevHovered = _hoveredItem
        _hoveredItem = newValue
        prevHovered?.notifyHoverChangeToDelegates()
        _hoveredItem?.notifyHoverChangeToDelegates()
        hoveredItemTick.accept(())
    }
}
