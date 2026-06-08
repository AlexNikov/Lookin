//
//  LKHierarchyDataSource.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/6.
//  https://lookin.work
//

import AppKit
import LookinShared
import RxRelay
import RxSwift

enum LKHierarchyDataSourceState: UInt {
    case normal
    case search
    case focus
}

class LKHierarchyDataSource: NSObject {
    let stateRelay = BehaviorRelay<LKHierarchyDataSourceState>(value: .normal)
    private let flatItemsRelay = BehaviorRelay<[LookinDisplayItem]?>(value: nil)
    let displayingFlatItemsRelay = BehaviorRelay<[LookinDisplayItem]?>(value: nil)
    let rawHierarchyInfoRelay = BehaviorRelay<LookinHierarchyInfo?>(value: nil)

    private(set) var willReloadHierarchyInfo = PublishRelay<Void>()

    let itemDidChangeHiddenAlphaValueRelay = PublishRelay<LookinDisplayItem>()
    var itemDidChangeHiddenAlphaValue: Observable<LookinDisplayItem> {
        itemDidChangeHiddenAlphaValueRelay.asObservable()
    }

    let itemDidChangeNoPreviewRelay = PublishRelay<Void>()
    var itemDidChangeNoPreview: Observable<Void> {
        itemDidChangeNoPreviewRelay.asObservable()
    }

    let didReloadHierarchyInfoRelay = PublishRelay<Void>()
    var didReloadHierarchyInfo: Observable<Void> {
        didReloadHierarchyInfoRelay.asObservable()
    }

    let didReloadFlatItemsWithSearchOrFocusRelay = PublishRelay<Void>()
    var didReloadFlatItemsWithSearchOrFocus: Observable<Void> {
        didReloadFlatItemsWithSearchOrFocusRelay.asObservable()
    }

    let itemDidChangeAttrGroupRelay = PublishRelay<LookinDisplayItem>()
    var itemDidChangeAttrGroup: Observable<LookinDisplayItem> {
        itemDidChangeAttrGroupRelay.asObservable()
    }

    var rawFlatItems: [LookinDisplayItem]? {
        didSet { rebuildOidToDisplayItemMap() }
    }

    /// Whether the most recent reload preserved the previous app state (keepState: true).
    /// False means a new app session — the 3D preview may auto-fit the scale to include off-screen content.
    var lastReloadKeptState: Bool = false

    weak var _selectedItem: LookinDisplayItem?
    let selectedItemTick = PublishRelay<Void>()

    weak var _hoveredItem: LookinDisplayItem?
    let hoveredItemTick = PublishRelay<Void>()

    var selectColorMenu: NSMenu!
    var customColorMenuItemTag: Int { 10 }
    var toggleColorFormatMenuItemTag: Int { 11 }

    func preferenceManager() -> LKPreferenceManager {
        assertionFailure("should implement by subclass")
        return LKPreferenceMain()
    }

    var shouldAvoidChangingPreviewSelectionDueToDashboardSearch = false

    var serverSideIsSwiftProject = false

    func isReadOnly() -> Bool { true }

    func buildDisplayingFlatItems() {
        displayingFlatItems = flatItems?.filter { $0.displayingInHierarchy } ?? []
    }

    var oidToDisplayItemMap: [UInt: LookinDisplayItem] = [:]
    var colorToAliasMap: [String: [String]] = [:]

    private let kvoDisposeBag = DisposeBag()

    func reload(with info: LookinHierarchyInfo, keepState: Bool) {
        performReload(with: info, keepState: keepState)
    }

    override init() {
        super.init()

        LKPreferenceMain().rgbaFormatObservable
            .skip(1)
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, _ in
                owner.setUpColors()
            }
            .disposed(by: kvoDisposeBag)
    }

    deinit {
        NSLog("%@ dealloc", String(describing: type(of: self)))
    }
}

// MARK: - flatItems relay access

extension LKHierarchyDataSource {
    var flatItemsObservable: Observable<[LookinDisplayItem]?> {
        flatItemsRelay.asObservable()
    }

    var flatItems: [LookinDisplayItem]? {
        get { flatItemsRelay.value }
        set { flatItemsRelay.accept(newValue) }
    }
}
