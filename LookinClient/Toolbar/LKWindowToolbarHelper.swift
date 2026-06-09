//
//  LKWindowToolbarHelper.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/8.
//  https://lookin.work
//

import AppKit
import LookinShared
import RxSwift

extension NSToolbarItem.Identifier {
    static let LKToolBarIdentifier_Dimension = NSToolbarItem.Identifier("0")
    static let LKToolBarIdentifier_Scale = NSToolbarItem.Identifier("1")
    static let LKToolBarIdentifier_Setting = NSToolbarItem.Identifier("2")
    static let LKToolBarIdentifier_Reload = NSToolbarItem.Identifier("3")
    static let LKToolBarIdentifier_App = NSToolbarItem.Identifier("5")
    static let LKToolBarIdentifier_AppInReadMode = NSToolbarItem.Identifier("12")
    static let LKToolBarIdentifier_Add = NSToolbarItem.Identifier("13")
    static let LKToolBarIdentifier_Remove = NSToolbarItem.Identifier("14")
    static let LKToolBarIdentifier_Console = NSToolbarItem.Identifier("15")
    static let LKToolBarIdentifier_Rotation = NSToolbarItem.Identifier("16")
    static let LKToolBarIdentifier_Measure = NSToolbarItem.Identifier("17")
    static let LKToolBarIdentifier_Message = NSToolbarItem.Identifier("18")
    static let LKToolBarIdentifier_FastMode = NSToolbarItem.Identifier("19")
    static let LKToolBarIdentifier_Logs = NSToolbarItem.Identifier("20")
}

private let keyBindingPreferenceManager = "PreferenceManager"
private let keyBindingAppInfo = "AppInfo"

private enum LKToolbarItemLayout {
    static let height: CGFloat = 34

    static func installMinSize(on view: NSView, minWidth: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: height),
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth),
        ])
    }

    static func installFixedSize(on view: NSView, width: CGFloat) -> NSLayoutConstraint {
        view.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = view.widthAnchor.constraint(equalToConstant: width)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: height),
            widthConstraint,
        ])
        return widthConstraint
    }
}

class LKWindowToolbarHelper: NSObject {
    private static let _shared = LKWindowToolbarHelper()
    private let disposeBag = DisposeBag()

    class func sharedInstance() -> LKWindowToolbarHelper {
        _shared
    }

    func makeToolBarItem(
        withIdentifier identifier: NSToolbarItem.Identifier,
        preferenceManager manager: LKPreferenceManager
    ) -> NSToolbarItem? {
        assert(identifier != .LKToolBarIdentifier_AppInReadMode)

        if identifier == .LKToolBarIdentifier_Measure {
            let image = NSImageMake("icon_measure")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded
            button.setButtonType(.pushOnPushOff)
            button.target = self
            button.action = #selector(handleToggleMeasureButton(_:))
            button.lookin_bindObject(manager, forKey: "manager")

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Measure)
            item.label = NSLocalizedString("Measure", comment: "")
            item.view = button
            LKToolbarItemLayout.installMinSize(on: button, minWidth: 48)

            manager.measureStateObservable
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak button] state in
                    button?.state = state != .no ? .on : .off
                })
                .disposed(by: disposeBag)
            return item
        }

        if identifier == .LKToolBarIdentifier_Rotation {
            let image = NSImageMake("icon_rotation")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded
            button.setButtonType(.pushOnPushOff)

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Rotation)
            item.label = NSLocalizedString("Free Rotation", comment: "")
            item.view = button
            LKToolbarItemLayout.installMinSize(on: button, minWidth: 48)

            manager.freeRotationObservable
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak button] enabled in
                    button?.state = enabled ? .on : .off
                })
                .disposed(by: disposeBag)
            return item
        }

        if identifier == .LKToolBarIdentifier_Dimension {
            let image2d = NSImageMake("icon_2d")
            image2d?.isTemplate = true
            let image3d = NSImageMake("icon_3d")
            image3d?.isTemplate = true

            let control = NSSegmentedControl(images: [image2d!, image3d!], trackingMode: .selectOne, target: self, action: #selector(handleDimension(_:)))
            control.lookin_bindObjectWeakly(manager, forKey: keyBindingPreferenceManager)
            control.segmentDistribution = .fillEqually

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Dimension)
            item.label = "2D / 3D"
            item.view = control
            LKToolbarItemLayout.installMinSize(on: control, minWidth: 90)

            manager.previewDimensionObservable
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak control] segment in
                    control?.selectedSegment = segment
                })
                .disposed(by: disposeBag)
            return item
        }

        if identifier == .LKToolBarIdentifier_Scale {
            let scale = manager.previewScale

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Scale)
            let scaleView = LKWindowToolbarScaleView()
            scaleView.slider.minValue = LookinPreviewMinScale
            scaleView.slider.maxValue = LookinPreviewMaxScale
            scaleView.slider.doubleValue = scale
            scaleView.slider.target = self
            scaleView.slider.action = #selector(handleScaleSlider(_:))
            scaleView.increaseButton.target = self
            scaleView.increaseButton.action = #selector(handleScaleIncreaseButton(_:))
            scaleView.decreaseButton.target = self
            scaleView.decreaseButton.action = #selector(handleScaleDecreaseButton(_:))
            scaleView.slider.lookin_bindObjectWeakly(manager, forKey: keyBindingPreferenceManager)
            scaleView.increaseButton.lookin_bindObjectWeakly(manager, forKey: keyBindingPreferenceManager)
            scaleView.decreaseButton.lookin_bindObjectWeakly(manager, forKey: keyBindingPreferenceManager)

            item.label = NSLocalizedString("Zoom", comment: "")
            item.view = scaleView
            LKToolbarItemLayout.installMinSize(on: scaleView, minWidth: 160)

            manager.previewScaleObservable
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak slider = scaleView.slider] scale in
                    slider?.doubleValue = scale
                })
                .disposed(by: disposeBag)
            return item
        }

        if identifier == .LKToolBarIdentifier_Setting {
            let image = NSImageMake("icon_setting")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded
            button.lookin_bindObjectWeakly(manager, forKey: keyBindingPreferenceManager)

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Setting)
            item.view = button
            LKToolbarItemLayout.installMinSize(on: button, minWidth: 48)
            return item
        }

        if identifier == .LKToolBarIdentifier_Reload {
            let image = NSImageMake("icon_reload")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Reload)
            item.label = NSLocalizedString("Reload", comment: "")
            item.view = button
            LKToolbarItemLayout.installMinSize(on: button, minWidth: 68)
            return item
        }

        if identifier == .LKToolBarIdentifier_App {
            let button = LKWindowToolbarAppButton()
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_App)
            item.label = NSLocalizedString("Select App", comment: "")
            item.view = button
            let appItemWidthConstraint = LKToolbarItemLayout.installFixedSize(on: button, width: 42)

            LKAppsManager.sharedInstance.inspectingAppObservable
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { app in
                    button.appInfo = app?.appInfo
                    let width = app != nil ? button.bestWidth + 6 : 42
                    appItemWidthConstraint.constant = width
                })
                .disposed(by: disposeBag)
            return item
        }

        if identifier == .LKToolBarIdentifier_Console {
            let image = NSImageMake("icon_console")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded
            button.setButtonType(.pushOnPushOff)

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Console)
            item.label = NSLocalizedString("Console", comment: "")
            item.view = button
            LKToolbarItemLayout.installMinSize(on: button, minWidth: 48)
            return item
        }

        if identifier == .LKToolBarIdentifier_Logs {
            let image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: nil)
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded
            button.setButtonType(.pushOnPushOff)

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Logs)
            item.label = NSLocalizedString("Logs", comment: "")
            item.view = button
            LKToolbarItemLayout.installMinSize(on: button, minWidth: 48)
            return item
        }

        if identifier == .LKToolBarIdentifier_FastMode {
            let image = NSImageMake("icon_turbo")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded
            button.setButtonType(.pushOnPushOff)

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_FastMode)
            item.label = NSLocalizedString("Fast Mode", comment: "")
            item.view = button
            LKToolbarItemLayout.installMinSize(on: button, minWidth: 60)

            manager.fastModeObservable
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak button] enabled in
                    button?.state = enabled ? .on : .off
                })
                .disposed(by: disposeBag)
            return item
        }

        if identifier == .LKToolBarIdentifier_Add {
            let image = NSImage(named: NSImage.addTemplateName)
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Add)
            item.view = button
            LKToolbarItemLayout.installMinSize(on: button, minWidth: 48)
            return item
        }

        if identifier == .LKToolBarIdentifier_Remove {
            let image = NSImageMake("icon_delete")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Remove)
            item.view = button
            LKToolbarItemLayout.installMinSize(on: button, minWidth: 48)
            return item
        }

        if identifier == .LKToolBarIdentifier_Message {
            let image = NSImageMake("icon_notification")
            image?.isTemplate = true

            let button = NSButton()
            button.image = image
            button.bezelStyle = .texturedRounded

            let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_Message)
            item.view = button
            LKToolbarItemLayout.installMinSize(on: button, minWidth: 48)
            return item
        }

        assertionFailure()
        return nil
    }

    func makeAppInReadModeItem(with appInfo: LookinAppInfo) -> NSToolbarItem {
        let button = LKWindowToolbarAppButton()
        button.bezelStyle = .texturedRounded
        button.lookin_bindObject(appInfo, forKey: keyBindingAppInfo)
        button.appInfo = appInfo

        let item = NSToolbarItem(itemIdentifier: .LKToolBarIdentifier_AppInReadMode)
        item.label = "iOS App"
        item.view = button
        _ = LKToolbarItemLayout.installFixedSize(on: button, width: button.bestWidth + 6)
        return item
    }

    @objc private func handleDimension(_ control: NSSegmentedControl) {
        guard let manager = control.lookin_getBindObject(forKey: keyBindingPreferenceManager) as? LKPreferenceManager else { return }
        manager.previewDimension = control.selectedSegment
    }

    @objc private func handleScaleSlider(_ slider: NSSlider) {
        guard let manager = slider.lookin_getBindObject(forKey: keyBindingPreferenceManager) as? LKPreferenceManager else { return }
        manager.previewScale = slider.doubleValue
    }

    @objc private func handleScaleIncreaseButton(_ button: NSButton) {
        guard let manager = button.lookin_getBindObject(forKey: keyBindingPreferenceManager) as? LKPreferenceManager else { return }
        let currentScale = manager.previewScale
        let targetScale = min(max(currentScale + 0.1, LookinPreviewMinScale), LookinPreviewMaxScale)
        manager.previewScale = targetScale
    }

    @objc private func handleScaleDecreaseButton(_ button: NSButton) {
        guard let manager = button.lookin_getBindObject(forKey: keyBindingPreferenceManager) as? LKPreferenceManager else { return }
        let currentScale = manager.previewScale
        let targetScale = min(max(currentScale - 0.1, LookinPreviewMinScale), LookinPreviewMaxScale)
        manager.previewScale = targetScale
    }

    @objc private func handleToggleMeasureButton(_ button: NSButton) {
        guard let manager = button.lookin_getBindObject(forKey: "manager") as? LKPreferenceManager else { return }
        let state: LookinMeasureState = button.state == .on ? .locked : .no
        manager.measureState = state
    }
}
