//
//  LKLaunchViewController.swift
//  Lookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//

import AppKit
import LookinShared
import RxSwift

class LKLaunchViewController: LKBaseViewController {
    private weak var hostWindow: NSWindow?
    private var appViews: [LKLaunchAppView] = []
    private var bottomIndicatorView: LKProgressIndicatorView!
    private var reloadingIndicator: NSProgressIndicator?
    private var noAppsTitleLabel: LKLabel?
    private var tutorialControl: LKTextControl!
    private var isEnteringApp = false
    private var enteringStartedAt: Date?
    private var lastFetchCompletedAt: Date?
    private var appInfos: [LookinAppInfo] = []
    private var appDiscoveryTimer: DispatchSourceTimer?
    private var appDiscoveryPollCount = 0
    private static let appDiscoveryMaxPolls = 45

    private let appViewInterSpace: CGFloat = 10
    private let contentHorInset: CGFloat = 30
    private let contentHeight: CGFloat = 400

    private let disposeBag = DisposeBag()

    init(window: NSWindow) {
        hostWindow = window
        super.init(containerView: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func makeContainerView() -> NSView {
        let containerView = LKVisualEffectView()
        containerView.blendingMode = .behindWindow
        containerView.state = .active

        appViews = []

        tutorialControl = LKTextControl()
        tutorialControl.layer?.cornerRadius = 4
        tutorialControl.label.stringValue = NSLocalizedString("Can't see your app ?", comment: "")
        tutorialControl.label.textColor = .linkColor
        tutorialControl.label.font = NSFont.systemFont(ofSize: 12)
        tutorialControl.adjustAlphaWhenClick = true
        tutorialControl.addTarget(self, clickAction: #selector(handleTutorial))
        containerView.addSubview(tutorialControl)

        bottomIndicatorView = LKProgressIndicatorView()
        containerView.addSubview(bottomIndicatorView)

        bottomIndicatorView.animate(toProgress: 0.7, duration: 0.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + LKUITiming.brief) { [weak self] in
            self?.reloadWithAutoEntering(true)
        }

        return containerView
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        if let reloadingIndicator, let noAppsTitleLabel {
            reloadingIndicator.sizeToFit()
            noAppsTitleLabel.sizeToFit()

            let midY = view.bounds.height * 0.35
            let groupWidth = reloadingIndicator.frame.width + 5 + noAppsTitleLabel.frame.width
            var x = (view.bounds.width - groupWidth) / 2
            reloadingIndicator.frame.origin = NSPoint(x: x, y: midY - reloadingIndicator.frame.height / 2)
            x = reloadingIndicator.frame.maxX + 5
            noAppsTitleLabel.frame.origin = NSPoint(
                x: x,
                y: midY - noAppsTitleLabel.frame.height / 2
            )
        }

        tutorialControl.sizeToFit()
        tutorialControl.frame.origin = NSPoint(
            x: (view.bounds.width - tutorialControl.frame.width) / 2 + 3,
            y: 14
        )

        var posX = contentHorInset
        for appView in appViews {
            appView.sizeToFit()
            appView.frame.origin = NSPoint(x: posX, y: 30)
            posX = appView.frame.maxX + appViewInterSpace
        }

        bottomIndicatorView.frame = NSRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: 3
        )
    }

    /// MCP: refresh launch tiles without auto-entering inspector.
    /// Bypasses the `isMcpOperationInProgress` guard — the caller (refreshLaunchTargets) holds
    /// that flag itself, so the normal guard would make this a permanent no-op.
    func mcpReloadWithoutAutoEnter() {
        stopAppDiscoveryPolling()
        reloadWithAutoEntering(false, bypassMCPInProgressCheck: true)
    }

    /// MCP select/refresh: pause background discover polling to avoid fetchAppInfos lock contention.
    func mcpPauseDiscoveryPolling() {
        stopAppDiscoveryPolling()
    }

    /// MCP launch-health snapshot (freeze detection inputs).
    func mcpLaunchScreenSnapshot() -> [String: Any] {
        let visibleTiles = appViews.filter { !$0.isHidden && $0.app != nil }
        let now = Date()
        var snapshot: [String: Any] = [
            "isEnteringApp": isEnteringApp,
            "isPolling": appDiscoveryTimer != nil,
            "pollCount": appDiscoveryPollCount,
            "tileCount": visibleTiles.count,
            "showsSearchingUI": noAppsTitleLabel != nil,
            "progress": bottomIndicatorView?.progress ?? 0,
        ]
        if let enteringStartedAt {
            snapshot["enteringAgeSec"] = now.timeIntervalSince(enteringStartedAt)
        } else {
            snapshot["enteringAgeSec"] = 0
        }
        if let lastFetchCompletedAt {
            snapshot["secondsSinceLastFetch"] = now.timeIntervalSince(lastFetchCompletedAt)
        } else {
            snapshot["secondsSinceLastFetch"] = -1
        }
        return snapshot
    }

    /// Automation: open inspector by activating the demo app tile (or the only visible tile).
    func lookin_mcpTryEnterInspector() {
        if isEnteringApp { return }
        guard bottomIndicatorView != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + LKUITiming.launchAppsReveal) { [weak self] in
                self?.lookin_mcpTryEnterInspector()
            }
            return
        }

        LookinRACSignalRx.observeMainThread(
            LKAppsManager.sharedInstance.fetchAppInfos(withImage: true, localInfos: appInfos)
        )
        .subscribe(with: self, onSuccess: { owner, apps in
            guard let app = LKAppsManager.preferredInspectableApp(from: apps) else { return }
            if owner.appViews.isEmpty {
                owner.renderWithApps(apps)
            }
            owner.enterApp(app)
        })
        .disposed(by: disposeBag)
    }

    private func reloadWithAutoEntering(_ autoEnter: Bool, bypassMCPInProgressCheck: Bool = false) {
        if isEnteringApp { return }
        if !bypassMCPInProgressCheck && LKMCPClientDiagnostics.shared.isMcpOperationInProgress { return }

        LookinRACSignalRx.observeMainThread(
            LKAppsManager.sharedInstance.fetchAppInfos(withImage: true, localInfos: appInfos)
        )
        .subscribe(with: self, onSuccess: { owner, apps in
            owner.handleFetchedApps(apps, autoEnter: autoEnter)
        }, onFailure: { owner, _ in
            owner.handleFetchedApps([], autoEnter: autoEnter)
        })
        .disposed(by: disposeBag)
    }

    private func handleFetchedApps(_ apps: [LKInspectableApp], autoEnter: Bool) {
        if isEnteringApp { return }
        lastFetchCompletedAt = Date()
        appInfos = apps.compactMap { $0.appInfo }
        let usableApps = apps.filter { $0.serverVersionError == nil && $0.appInfo != nil }
        let names = usableApps.compactMap { $0.appInfo?.appName }.joined(separator: ", ")
        let deferUSB = LKConnectionManager.sharedInstance.shouldDeferLaunchAutoEnterForPendingUSB(
            usableApps: usableApps
        )
        LookinDiagLog.log(
            "client launch found apps=\(usableApps.count) [\(names)] autoEnter=\(autoEnter) deferUSB=\(deferUSB)"
        )

        let displayApps = LKAppsManager.appsForLaunchDisplay(discovered: apps)

        if autoEnter, !deferUSB {
            let appToEnter = LKAppsManager.preferredAppForLaunchAutoEnter(from: apps)
            if let appToEnter {
                stopAppDiscoveryPolling()
                renderWithApps(displayApps)
                enterApp(appToEnter)
                return
            }
        }

        if bottomIndicatorView.progress > 0, !deferUSB {
            bottomIndicatorView.finish(completion: nil)
        }
        renderWithApps(displayApps)

        if (usableApps.isEmpty || deferUSB), !isEnteringApp {
            scheduleAppDiscoveryPolling()
        } else {
            stopAppDiscoveryPolling()
        }
    }

    /// Keep scanning simulator/USB ports while the launch screen shows “Searching…” (demo may start after Lookin).
    private func scheduleAppDiscoveryPolling() {
        guard appDiscoveryTimer == nil else { return }
        appDiscoveryPollCount = 0
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + LKUITiming.launchPollInterval, repeating: LKUITiming.launchPollInterval)
        timer.setEventHandler { [weak self] in
            guard let self, !self.isEnteringApp else {
                self?.stopAppDiscoveryPolling()
                return
            }
            if LKMCPClientDiagnostics.shared.isMcpOperationInProgress {
                return
            }
            self.appDiscoveryPollCount += 1
            let waitingForUSB = LKConnectionManager.sharedInstance.hasAttachedUSBDevices
            if self.appDiscoveryPollCount > Self.appDiscoveryMaxPolls, !waitingForUSB {
                self.stopAppDiscoveryPolling()
                return
            }
            // Auto-enter only before any tile is shown; deferUSB in handleFetchedApps waits for USB demo.
            self.reloadWithAutoEntering(self.appViews.isEmpty)
        }
        timer.resume()
        appDiscoveryTimer = timer
    }

    private func stopAppDiscoveryPolling() {
        appDiscoveryTimer?.cancel()
        appDiscoveryTimer = nil
        appDiscoveryPollCount = 0
    }

    @objc
    private func handleClickAppView(_ view: LKLaunchAppView) {
        if isEnteringApp { return }

        guard let app = view.app else { return }

        if app.isLaunchUSBPendingPlaceholder || app.channel == nil {
            guard let window = resolvedWindow else { return }
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("No inspectable app on this iPhone yet", comment: "")
            alert.informativeText = NSLocalizedString(
                "Launch your iOS app with LookinServer on the device (Xcode Run), then return here.",
                comment: ""
            )
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.beginSheetModal(for: window)
            reloadWithAutoEntering(false)
            return
        }

        if let error = app.serverVersionError {
            if error.code == Int(LookinErrCode_ServerVersionTooLow) {
                LKHelper.openLookinWebsite(withPath: "faq/server-version-too-low/")
            } else {
                LKHelper.openLookinWebsite(withPath: "faq/server-version-too-high/")
            }
            return
        }

        bottomIndicatorView.animate(toProgress: 0.8, duration: 1)
        enterApp(app)
    }

    private func renderWithApps(_ apps: [LKInspectableApp]?) {
        let apps = apps.map { LKAppsManager.sortedForDisplay($0) }
        guard let apps, !apps.isEmpty else {
            resolvedWindow?.setContentSize(NSSize(width: 256, height: contentHeight))
            showNoAppsView()
            appViews.forEach { $0.isHidden = true }
            return
        }

        var windowWidth = contentHorInset * 2 + CGFloat(apps.count - 1) * appViewInterSpace
        appViews = resizeAppViews(count: apps.count, apps: apps, windowWidth: &windowWidth)
        appViews.forEach { $0.isHidden = false }

        resolvedWindow?.setContentSize(NSSize(width: windowWidth, height: contentHeight))
        hideNoAppsViews()
        view.needsLayout = true
    }

    private func resizeAppViews(
        count: Int,
        apps: [LKInspectableApp],
        windowWidth: inout CGFloat
    ) -> [LKLaunchAppView] {
        var views = appViews

        while views.count < count {
            let view = LKLaunchAppView()
            self.view.addSubview(view)
            views.append(view)
        }
        while views.count > count {
            views.removeLast().removeFromSuperview()
        }

        for (idx, view) in views.enumerated() {
            view.app = apps[idx]
            view.addTarget(self, clickAction: #selector(handleClickAppView(_:)))
            windowWidth += view.sizeThatFits(
                NSSize(
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )
            ).width
        }

        return views
    }

    private func enterApp(_ app: LKInspectableApp) {
        if isEnteringApp { return }
        stopAppDiscoveryPolling()
        isEnteringApp = true
        enteringStartedAt = Date()

        LKPerformanceReporter.sharedInstance.willStartReload()

        LookinRACSignalRx.observeMainThread(
            LKAppsManager.sharedInstance.connectInspectableApp(app)
        )
            .subscribe(with: self, onSuccess: { owner, pair in
                let (freshApp, info) = pair
                owner.handleEnterAppSuccess(app: freshApp, info: info)
                LKPerformanceReporter.sharedInstance.didFetchHierarchy()
            }, onFailure: { owner, error in
                owner.handleEnterAppFail(with: (error as NSError?) ?? LKLookinClientErrors.inner)
            })
            .disposed(by: disposeBag)
    }

    private func handleEnterAppSuccess(app: LKInspectableApp, info: LookinHierarchyInfo) {
        isEnteringApp = false
        enteringStartedAt = nil
        LKAppsManager.sharedInstance.inspectingApp = app
        LKStaticHierarchyDataSource.sharedInstance.reload(with: info, keepState: false)

        let openInspector = { [weak self] in
            LKNavigationManager.sharedInstance.showStaticWorkspace()
            LKNavigationManager.sharedInstance.closeLaunch()
            _ = self
        }
        // Do not block inspector on progress-bar animation (MCP verify / headless runs).
        openInspector()
        bottomIndicatorView.finish(completion: nil)
    }

    private func handleEnterAppFail(with error: NSError) {
        isEnteringApp = false
        enteringStartedAt = nil
        bottomIndicatorView.resetToZero()
        guard let window = resolvedWindow else { return }
        NSAlert(error: error).beginSheetModal(for: window) { [weak self] _ in
            self?.reloadWithAutoEntering(false)
        }
    }

    private func showNoAppsView() {
        if noAppsTitleLabel == nil {
            let label = LKLabel()
            label.textColor = .labelColor
            label.font = NSFont.systemFont(ofSize: 14)
            label.stringValue = NSLocalizedString("Searching for inspectable apps", comment: ""
            )
            view.addSubview(label)
            noAppsTitleLabel = label
        }
        if reloadingIndicator == nil {
            let indicator = NSProgressIndicator()
            indicator.isIndeterminate = true
            indicator.style = .spinning
            indicator.controlSize = .small
            view.addSubview(indicator)
            indicator.startAnimation(self)
            reloadingIndicator = indicator
        }
        view.needsLayout = true
    }

    private func hideNoAppsViews() {
        noAppsTitleLabel?.removeFromSuperview()
        noAppsTitleLabel = nil

        reloadingIndicator?.removeFromSuperview()
        reloadingIndicator = nil
    }

    @objc
    private func handleTutorial() {
        LKHelper.openLookinWebsite(withPath: "faq/cannot-see/")
    }

    private var resolvedWindow: NSWindow? {
        hostWindow ?? view.window
    }

    deinit {
        stopAppDiscoveryPolling()
    }
}
