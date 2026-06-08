//
//  LKReadWindowController.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//

import AppKit
import LookinShared
import RxSwift

final class LKReadWindowController: LKWindowController, NSToolbarDelegate {
    private(set) var viewController: LKReadViewController!

    private var toolbarItemsMap: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
    private var preferenceManager: LKPreferenceManager!

    private let disposeBag = DisposeBag()

    init(file: LookinHierarchyFile) {
        let screenSize = NSScreen.main?.frame.size ?? NSSize(width: 1440, height: 900)
        let window = LKWindow(
            contentRect: NSRect(x: 0, y: 0, width: screenSize.width * 0.7, height: screenSize.height * 0.7),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.tabbingMode = .disallowed
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
        window.minSize = NSSize(width: 800, height: 500)
        window.center()

        super.init(window: window)

        preferenceManager = LKPreferenceManager()
        viewController = LKReadViewController(file: file, preferenceManager: preferenceManager)
        window.contentView = viewController.view
        contentViewController = viewController

        viewController.hierarchyDataSource.selectedItemObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, item in
                let measureButton = owner.toolbarItemsMap[NSToolbarItem.Identifier.LKToolBarIdentifier_Measure]?.view as? NSButton
                measureButton?.isEnabled = item != nil
            }
            .disposed(by: disposeBag)

        let toolbar = NSToolbar()
        toolbar.displayMode = .iconAndLabel
        toolbar.sizeMode = .regular
        toolbar.delegate = self
        window.toolbar = toolbar
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            NSToolbarItem.Identifier.LKToolBarIdentifier_AppInReadMode,
            .flexibleSpace,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Dimension,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Rotation,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Setting,
            .flexibleSpace,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Scale,
            .flexibleSpace,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Measure,
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if let item = toolbarItemsMap[itemIdentifier] {
            return item
        }

        let item: NSToolbarItem
        if itemIdentifier == NSToolbarItem.Identifier.LKToolBarIdentifier_AppInReadMode {
            guard let appInfo = viewController.hierarchyDataSource.rawHierarchyInfo?.appInfo else {
                return nil
            }
            item = LKWindowToolbarHelper.sharedInstance().makeAppInReadModeItem(with: appInfo)
        } else if let toolbarItem = LKWindowToolbarHelper.sharedInstance().makeToolBarItem(
                withIdentifier: itemIdentifier,
                preferenceManager: preferenceManager
            ) {
            item = toolbarItem
        } else {
            return nil
        }
        toolbarItemsMap[itemIdentifier] = item

        if item.itemIdentifier == NSToolbarItem.Identifier.LKToolBarIdentifier_Setting {
            item.label = NSLocalizedString("View", comment: "")
            item.target = self
            item.action = #selector(handleSetting(_:))
        } else if item.itemIdentifier == NSToolbarItem.Identifier.LKToolBarIdentifier_Rotation {
            item.target = self
            item.action = #selector(handleFreeRotation)
        }
        return item
    }

    // MARK: - Event Handler

    @objc private func handleSetting(_ button: NSButton) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: LKHelper.isEnglish() ? 270 : 350, height: 200)
        popover.contentViewController = LKMenuPopoverSettingController(preferenceManager: preferenceManager)
        popover.show(
            relativeTo: NSRect(x: 0, y: 0, width: button.bounds.width, height: button.bounds.height),
            of: button,
            preferredEdge: .maxY
        )
    }

    @objc private func handleFreeRotation() {
        let boolValue = preferenceManager.freeRotation
        preferenceManager.freeRotation = !boolValue
    }

    // MARK: - LKAppMenuManagerDelegate

    func appMenuManagerDidSelectDimension() {
        if preferenceManager.previewDimension == Int(LookinPreviewDimension.dimension2D.rawValue) {
            preferenceManager.previewDimension = Int(LookinPreviewDimension.dimension3D.rawValue)
        } else {
            preferenceManager.previewDimension = Int(LookinPreviewDimension.dimension2D.rawValue)
        }
    }

    func appMenuManagerDidSelectZoomIn() {
        let currentScale = preferenceManager.previewScale
        let targetScale = min(max(currentScale + 0.1, LookinPreviewMinScale), LookinPreviewMaxScale)
        preferenceManager.previewScale = targetScale
    }

    func appMenuManagerDidSelectZoomOut() {
        let currentScale = preferenceManager.previewScale
        let targetScale = min(max(currentScale - 0.1, LookinPreviewMinScale), LookinPreviewMaxScale)
        preferenceManager.previewScale = targetScale
    }

    func appMenuManagerDidSelectDecreaseInterspace() {
        let currentValue = preferenceManager.zInterspace
        var newValue = currentValue - 0.1
        newValue = min(max(newValue, LookinPreviewMinZInterspace), LookinPreviewMaxZInterspace)
        preferenceManager.zInterspace = newValue
    }

    func appMenuManagerDidSelectIncreaseInterspace() {
        let currentValue = preferenceManager.zInterspace
        var newValue = currentValue + 0.1
        newValue = min(max(newValue, LookinPreviewMinZInterspace), LookinPreviewMaxZInterspace)
        preferenceManager.zInterspace = newValue
    }

    func appMenuManagerDidSelectExpansionIndex(_ index: UInt) {
        viewController.hierarchyDataSource.adjustExpansionByIndex(
            Int(index),
            referenceDict: nil,
            selectedItem: nil
        )
    }

    func appMenuManagerDidSelectFilter() {
        viewController.currentHierarchyView().activateSearchBar()
    }
}
