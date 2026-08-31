//
//  LKStaticWindowController.swift
//  Lookin
//
//  Created by Li Kai on 2018/11/4.
//  https://lookin.work
//

import AppCenterAnalytics
import AppKit
import LookinShared
import RxRelay
import RxSwift

final class LKStaticWindowController: LKWindowController, NSToolbarDelegate {
    private(set) var viewController: LKStaticViewController!

    var toolbarItemsMap: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
    private let isFetchingHierarchyRelay = BehaviorRelay<Bool>(value: false)
    private let isFetchingDetailsRelay = BehaviorRelay<Bool>(value: false)
    private var inspectingAppEndToken: NSObjectProtocol?

    var isFetchingHierarchy: Bool {
        get { isFetchingHierarchyRelay.value }
        set { isFetchingHierarchyRelay.accept(newValue) }
    }

    var isFetchingDetails: Bool {
        get { isFetchingDetailsRelay.value }
        set { isFetchingDetailsRelay.accept(newValue) }
    }

    var mcpFetchingDetails: Bool { isFetchingDetails }
    var mcpFetchingHierarchy: Bool { isFetchingHierarchy }

    let disposeBag = DisposeBag()
    private var reloadHierarchyDisposable: Disposable?

    deinit {
        if let token = inspectingAppEndToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    override init(window: NSWindow?) {
        let contentSize: NSSize
        if LookinUITestSupport.isEnabled {
            contentSize = LookinUITestSupport.inspectorContentSize()
        } else {
            let screenSize = NSScreen.main?.frame.size ?? NSSize(width: 1440, height: 900)
            contentSize = NSSize(width: screenSize.width * 0.7, height: screenSize.height * 0.7)
        }
        let lkWindow = LKWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        lkWindow.tabbingMode = .disallowed
        lkWindow.titleVisibility = .hidden
        lkWindow.setAccessibilityIdentifier("lookin.inspector.window")
        lkWindow.setAccessibilityValue("loading")
        if #available(macOS 11.0, *) {
            lkWindow.toolbarStyle = .unified
        }
        lkWindow.minSize = NSSize(width: HierarchyMinWidth + DashboardViewWidth + 200, height: 500)
        if LookinUITestSupport.isEnabled {
            lkWindow.center()
        } else {
            lkWindow.center()
            lkWindow.setFrameUsingName(LKWindowSizeName_Static)
        }

        super.init(window: lkWindow)

        inspectingAppEndToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LKInspectingAppDidEndNotificationName"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isFetchingHierarchy = false
            self?.isFetchingDetails = false
        }

        viewController = LKStaticViewController()
        lkWindow.contentView = viewController.view
        contentViewController = viewController

        let toolbar = NSToolbar()
        toolbar.displayMode = .iconAndLabel
        toolbar.sizeMode = .regular
        toolbar.delegate = self
        lkWindow.toolbar = toolbar

        LKStaticAsyncUpdateManager.sharedInstance.delegate = self

        bindToolbarItemStates()
        bindFastModeSideEffects()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init() {
        self.init(window: nil)
    }

    func popupAllInspectableApps(
        with source: MenuPopoverAppsListControllerEventSource,
        needImages: Bool = true
    ) {
        guard let appItemView = toolbarItemsMap[NSToolbarItem.Identifier.LKToolBarIdentifier_App]?.view else { return }

        // App button tap: skip screenshots on first fetch to avoid blocking fetchAppInfosLock
        // for 10-15 s (cold App response with screenshots). The popover shows device icons and
        // app names immediately; screenshots are cosmetic and can wait for a subsequent fetch.
        // This mirrors the same optimization in LKLaunchViewController.reloadWithAutoEntering.
        let effectiveNeedImages: Bool
        switch source {
        case .appButton:
            effectiveNeedImages = false
        case .reloadButton, .noConnectionTips:
            effectiveNeedImages = needImages
        }

        LookinRACSignalRx.observeMainThread(
            LKAppsManager.sharedInstance.fetchAppsForPopover(withImage: effectiveNeedImages)
        )
        .subscribe(with: self, onSuccess: { owner, apps in
            owner.presentAppSwitcherPopover(apps: apps, source: source)
        })
        .disposed(by: disposeBag)
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var ret: [NSToolbarItem.Identifier] = [
            NSToolbarItem.Identifier.LKToolBarIdentifier_Reload,
            NSToolbarItem.Identifier.LKToolBarIdentifier_FastMode,
            NSToolbarItem.Identifier.LKToolBarIdentifier_App,
            .flexibleSpace,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Dimension,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Rotation,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Setting,
            .flexibleSpace,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Scale,
            .flexibleSpace,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Measure,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Console,
            NSToolbarItem.Identifier.LKToolBarIdentifier_Logs,
        ]
        if !LKMessageManager.sharedInstance.queryMessages().isEmpty {
            ret.append(NSToolbarItem.Identifier.LKToolBarIdentifier_Message)
            Analytics.trackEvent("Show Notification")
        }
        return ret
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if let existing = toolbarItemsMap[itemIdentifier] {
            return existing
        }
        guard let item = LKWindowToolbarHelper.sharedInstance().makeToolBarItem(
            withIdentifier: itemIdentifier,
            preferenceManager: LKPreferenceMain()
        ) else { return nil }
        toolbarItemsMap[itemIdentifier] = item

        switch itemIdentifier {
        case NSToolbarItem.Identifier.LKToolBarIdentifier_Reload:
            // Custom `item.view` — only wire the button; item.action would double-fire with button.action.
            if let button = item.view as? NSButton {
                button.target = self
                button.action = #selector(handleReload)
            }
        case NSToolbarItem.Identifier.LKToolBarIdentifier_App:
            if let button = item.view as? NSButton {
                button.target = self
                button.action = #selector(handleApp)
            }
        case NSToolbarItem.Identifier.LKToolBarIdentifier_Rotation:
            item.target = self
            item.action = #selector(handleFreeRotation)
        case NSToolbarItem.Identifier.LKToolBarIdentifier_Setting:
            item.label = NSLocalizedString("View", comment: "")
            item.target = self
            item.action = #selector(handleSetting(_:))
        case NSToolbarItem.Identifier.LKToolBarIdentifier_Console:
            item.target = self
            item.action = #selector(handleConsole)
            viewController.showConsoleObservable
                .skip(1)
                .distinctUntilChanged()
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { isShowing in
                    if let button = item.view as? NSButton {
                        button.state = isShowing ? .on : .off
                    }
                })
                .disposed(by: disposeBag)
        case NSToolbarItem.Identifier.LKToolBarIdentifier_Logs:
            item.target = self
            item.action = #selector(handleLogs)
            viewController.showLogsObservable
                .skip(1)
                .distinctUntilChanged()
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { isShowing in
                    if let button = item.view as? NSButton {
                        button.state = isShowing ? .on : .off
                    }
                })
                .disposed(by: disposeBag)
            LKLogsManager.shared.hasUnreadErrorsObservable
                .distinctUntilChanged()
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { hasUnread in
                    if let button = item.view as? NSButton {
                        LKStaticWindowController.updateLogsBadge(on: button, visible: hasUnread)
                    }
                })
                .disposed(by: disposeBag)
        case NSToolbarItem.Identifier.LKToolBarIdentifier_Message:
            item.label = NSLocalizedString("Notifications", comment: "")
            item.target = self
            item.action = #selector(handleMessage(_:))
        case NSToolbarItem.Identifier.LKToolBarIdentifier_FastMode:
            if let button = item.view as? NSButton {
                button.target = self
                button.action = #selector(handleFastMode)
            }
        default:
            break
        }
        return item
    }

    // MARK: - Event handlers

    @objc func handleReload() {
        if isFetchingDetails {
            LKStaticAsyncUpdateManager.sharedInstance.endUpdating()
            resetDetailFetchingToolbarState()
        }

        guard let app = LKAppsManager.sharedInstance.inspectingApp else {
            popupAllInspectableApps(with: .reloadButton)
            return
        }

        cancelInFlightHierarchyReload(on: app.channel)

        LKStaticAsyncUpdateManager.sharedInstance.endUpdating()
        isFetchingHierarchy = true
        viewController.progressView.animate(toProgress: InitialIndicatorProgressWhenFetchHierarchy)
        LKPerformanceReporter.sharedInstance.willStartReload()
        LKConnectionTiming.shared.begin("reload.hierarchy")

        reloadHierarchyDisposable?.dispose()
        reloadHierarchyDisposable = LookinRACSignalRx.observeMainThread(
            LKAppsManager.sharedInstance.fetchHierarchyDataForReload(from: app)
        )
        .do(onDispose: { [weak self] in
            self?.isFetchingHierarchy = false
        })
        .subscribe(with: self, onSuccess: { owner, info in
            owner.viewController.progressView.finish(completion: nil)
            LKStaticHierarchyDataSource.sharedInstance.reload(with: info, keepState: true)
            owner.isFetchingHierarchy = false
            LKPerformanceReporter.sharedInstance.didFetchHierarchy()
            LKConnectionTiming.shared.end("reload.hierarchy", attrs: ["flat": info.displayItems?.count ?? 0])
        }, onFailure: { owner, error in
            LKConnectionTiming.shared.end("reload.hierarchy", attrs: ["error": true])
            let nsError = error as NSError
            if nsError.code != LKLookinClientErrors.discard().code {
                owner.viewController.progressView.resetToZero()
                AlertError(nsError, owner.window)
            } else {
                owner.viewController.progressView.resetToZero()
            }
            owner.isFetchingHierarchy = false
        })
    }

    private func cancelInFlightHierarchyReload(on channel: LKPeerChannel?) {
        guard let channel else { return }
        let conn = LKConnectionManager.sharedInstance
        conn.cancelRequest(withType: UInt32(LookinRequestTypeHierarchyDetails), channel: channel)
        conn.cancelRequest(withType: UInt32(LookinRequestTypeHierarchy), channel: channel, notifyDiscard: true)
        conn.cancelRequest(withType: UInt32(LookinRequestTypePing), channel: channel, notifyDiscard: true)
    }

    @objc private func handleApp() {
        popupAllInspectableApps(with: .appButton)
    }

    @objc private func handleSetting(_ button: NSButton) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: LKHelper.isEnglish() ? 270 : 350, height: 200)
        popover.contentViewController = LKMenuPopoverSettingController(preferenceManager: LKPreferenceMain())
        popover.show(
            relativeTo: NSRect(x: 0, y: 0, width: button.bounds.width, height: button.bounds.height),
            of: button,
            preferredEdge: .maxY
        )
    }

    @objc private func handleConsole() {
        viewController.showConsole = !viewController.showConsole
    }

    @objc private func handleLogs() {
        viewController.showLogs = !viewController.showLogs
    }

    @objc private func handleFastMode() {
        LKConnectionTiming.shared.begin("fastMode.toggle")
        let manager = LKPreferenceMain()
        manager.fastMode = !manager.fastMode
        LKConnectionTiming.shared.end("fastMode.toggle", attrs: ["enabled": manager.fastMode])
    }

    @objc private func handleMessage(_ button: NSButton) {
        let menu = NSMenu()
        let msgs = LKMessageManager.sharedInstance.queryMessages()

        for msg in msgs {
            if msg == LKMessage_Jobs {
                let item = NSMenuItem()
                item.image = NSImageMake("Icon_Inspiration_small")
                item.title = NSLocalizedString("Job openings…(China)", comment: "")
                item.target = self
                item.action = #selector(handleJobsMenuItem)
                menu.addItem(item)
                menu.addItem(.separator())
                continue
            }
            if msg == LKMessage_NewServerVersion {
                let item = NSMenuItem()
                item.image = NSImageMake("Icon_Inspiration_small")
                let userVersion = LKAppsManager.sharedInstance.inspectingApp?.appInfo?.serverReadableVersion
                let newestVersion = LKServerVersionRequestor.shared.query()
                if let userVersion, !userVersion.isEmpty {
                    let format = NSLocalizedString(
                        "Your iOS project uses version %@ of the LookinServer SDK, while the latest version online is %@, it is recommended to upgrade.",
                        comment: ""
                    )
                    item.title = String(format: format, userVersion, newestVersion ?? "")
                } else {
                    let format = NSLocalizedString(
                        "Your iOS project uses an outdated version of the LookinServer SDK. It is recommended to upgrade to the latest version %@",
                        comment: ""
                    )
                    item.title = String(format: format, newestVersion ?? "")
                }
                menu.addItem(item)
                let historyItem = NSMenuItem()
                historyItem.image = NSImage(size: NSSize(width: 18, height: 1))
                historyItem.title = NSLocalizedString("Check out version updates on GitHub…", comment: "")
                historyItem.target = self
                historyItem.action = #selector(handleVersionsHistory)
                menu.addItem(historyItem)
                menu.addItem(.separator())
                continue
            }
            if msg == LKMessage_SwiftSubspec {
                let item = NSMenuItem()
                item.image = NSImageMake("Icon_Inspiration_small")
                item.title = NSLocalizedString(
                    "Your iOS project seems to use Swift, but you haven't turn on Swift optimization for Lookin",
                    comment: ""
                )
                menu.addItem(item)
                let howToItem = NSMenuItem()
                howToItem.image = NSImage(size: NSSize(width: 18, height: 1))
                howToItem.title = NSLocalizedString("How to turn on…", comment: "")
                howToItem.target = self
                howToItem.action = #selector(handleTurnOnSwift)
                menu.addItem(howToItem)
                menu.addItem(.separator())
            }
        }

        if menu.items.isEmpty {
            let item = NSMenuItem()
            item.title = NSLocalizedString("No message", comment: "")
            menu.addItem(item)
        }

        NSMenu.popUpContextMenu(menu, with: NSApplication.shared.currentEvent!, for: button)
        Analytics.trackEvent("Open Notification", withProperties: [
            "Jobs": "\(msgs.contains(LKMessage_Jobs))",
            "SwiftSubspec": "\(msgs.contains(LKMessage_SwiftSubspec))",
            "LowServer": "\(msgs.contains(LKMessage_NewServerVersion))",
        ])
    }

    @objc private func handleFreeRotation() {
        let manager = LKPreferenceMain()
        manager.freeRotation = !manager.freeRotation
    }

    @objc private func handleJobsMenuItem() {
        NSWorkspace.shared.open(URL(string: "https://bytedance.feishu.cn/docx/SAcgdoQuAouyXAxAqy8cmrT2n4b")!)
        LKMessageManager.sharedInstance.removeMessage(LKMessage_Jobs)
    }

    @objc private func handleVersionsHistory() {
        NSWorkspace.shared.open(URL(string: "https://github.com/QMUI/LookinServer/releases")!)
    }

    @objc private func handleTurnOnSwift() {
        NSWorkspace.shared.open(URL(string: "https://bytedance.feishu.cn/docx/GFRLdzpeKoakeyxvwgCcZ5XdnTb")!)
    }

    // MARK: - Private

    private func bindFastModeSideEffects() {
        LKPreferenceMain().fastModeObservable
            .distinctUntilChanged()
            .skip(1)
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, enabled in
                if enabled {
                    LKStaticAsyncUpdateManager.sharedInstance.updateForDisplayingItems()
                } else {
                    LKStaticAsyncUpdateManager.sharedInstance.endUpdating()
                    owner.resetDetailFetchingToolbarState()
                    LKStaticAsyncUpdateManager.sharedInstance.updateAll()
                }
            }
            .disposed(by: disposeBag)
    }

    private func bindToolbarItemStates() {
        Observable.combineLatest(
            isFetchingHierarchyRelay.asObservable(),
            isFetchingDetailsRelay.asObservable(),
            LKAppsManager.sharedInstance.switchStatusObservable.map { $0.isBusy }
        )
        .distinctUntilChanged { $0.0 == $1.0 && $0.1 == $1.1 && $0.2 == $1.2 }
        .observe(on: MainScheduler.instance)
        .subscribe(with: self) { owner, flags in
            let disabled = flags.0 || flags.1 || flags.2
            for id in [
                NSToolbarItem.Identifier.LKToolBarIdentifier_App,
                NSToolbarItem.Identifier.LKToolBarIdentifier_Console,
            ] {
                owner.toolbarItemsMap[id]?.isEnabled = !disabled
            }
            owner.toolbarItemsMap[NSToolbarItem.Identifier.LKToolBarIdentifier_FastMode]?.isEnabled = true
        }
        .disposed(by: disposeBag)

        LKAppsManager.sharedInstance.switchSuccessObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, success in
                owner.viewController.progressView.finish(completion: nil)
                let isSameApp = LKAppsManager.isSameInspectableSession(success.previousApp, success.freshApp)
                LKStaticHierarchyDataSource.sharedInstance.reload(with: success.hierarchyInfo, keepState: isSameApp)
            }
            .disposed(by: disposeBag)

        LKAppsManager.sharedInstance.switchFailureObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, error in
                owner.viewController.progressView.resetToZero()
                AlertError(error as NSError, owner.window)
            }
            .disposed(by: disposeBag)

        isFetchingHierarchyRelay.asObservable()
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, isFetching in
                owner.toolbarItemsMap[NSToolbarItem.Identifier.LKToolBarIdentifier_Reload]?.isEnabled = !isFetching
            }
            .disposed(by: disposeBag)

        LKStaticHierarchyDataSource.sharedInstance.selectedItemObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, item in
                guard let measureButton = owner.toolbarItemsMap[NSToolbarItem.Identifier.LKToolBarIdentifier_Measure]?.view as? NSButton else {
                    return
                }
                measureButton.isEnabled = item != nil
            }
            .disposed(by: disposeBag)
    }

    private static let logsBadgeLayerKey = "logsBadgeLayer"

    static func updateLogsBadge(on button: NSButton, visible: Bool) {
        button.wantsLayer = true
        if visible {
            if button.layer?.sublayers?.contains(where: { $0.name == logsBadgeLayerKey }) == true {
                return
            }
            let dotSize: CGFloat = 8
            let dot = CALayer()
            dot.name = logsBadgeLayerKey
            dot.cornerRadius = dotSize / 2
            dot.backgroundColor = NSColor.systemRed.cgColor
            dot.lookin_removeImplicitAnimations()
            // Anchor to top-right; layerMinXMargin + layerMinYMargin keeps it there
            // as the button resizes (non-flipped coords: y=0 is bottom)
            let w = max(button.bounds.width, 48)
            let h = max(button.bounds.height, 34)
            dot.frame = CGRect(x: w - dotSize - 2, y: h - dotSize - 2, width: dotSize, height: dotSize)
            dot.autoresizingMask = [.layerMinXMargin, .layerMinYMargin]
            button.layer?.addSublayer(dot)
        } else {
            button.layer?.sublayers?.filter { $0.name == logsBadgeLayerKey }.forEach { $0.removeFromSuperlayer() }
        }
    }
}
