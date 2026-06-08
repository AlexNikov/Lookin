import LookinShared
import RxRelay
import RxSwift

// MARK: - State & item relays

extension LKHierarchyDataSource {
    var stateObservable: Observable<LKHierarchyDataSourceState> {
        stateRelay.asObservable()
    }

    var state: LKHierarchyDataSourceState {
        get { stateRelay.value }
        set {
            guard newValue != stateRelay.value else { return }
            stateRelay.accept(newValue)
        }
    }

    var displayingFlatItemsObservable: Observable<[LookinDisplayItem]?> {
        displayingFlatItemsRelay.asObservable()
    }

    var displayingFlatItems: [LookinDisplayItem]? {
        get { displayingFlatItemsRelay.value }
        set { displayingFlatItemsRelay.accept(newValue) }
    }

    var rawHierarchyInfoObservable: Observable<LookinHierarchyInfo?> {
        rawHierarchyInfoRelay.asObservable()
    }

    var rawHierarchyInfo: LookinHierarchyInfo? {
        get { rawHierarchyInfoRelay.value }
        set { rawHierarchyInfoRelay.accept(newValue) }
    }
}
