//
//  LKStaticWindowController+MCPAppSwitcher.swift
//  Lookin
//
//  MCP automation: toolbar app-switcher popover.
//

import AppKit
import LookinShared
import RxSwift

extension LKStaticWindowController {
    func presentAppSwitcherPopover(
        apps: [LKInspectableApp],
        source: MenuPopoverAppsListControllerEventSource
    ) {
        guard let appItemView = toolbarItemsMap[NSToolbarItem.Identifier.LKToolBarIdentifier_App]?.view else { return }
        let sorted = LKAppsManager.sortedForDisplay(apps)
        let vc = LKMenuPopoverAppsListController(apps: sorted, source: source)
        let popover = NSPopover()
        vc.didSelectApp = { [weak popover] (app: LKInspectableApp?) in
            guard let app else { return }
            popover?.close()
            if let error = app.serverVersionError as NSError? {
                if error.code == Int(LookinErrCode_ServerVersionTooLow) {
                    LKHelper.openLookinWebsite(withPath: "faq/server-version-too-low/")
                } else {
                    LKHelper.openLookinWebsite(withPath: "faq/server-version-too-high/")
                }
            } else {
                LKStaticAsyncUpdateManager.sharedInstance.endUpdating()
                self.viewController.progressView.animate(toProgress: InitialIndicatorProgressWhenFetchHierarchy)
                LKAppsManager.sharedInstance.switchToInspectableApp(app)
            }
        }
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = vc.bestSize()
        popover.contentViewController = vc
        popover.show(
            relativeTo: NSRect(x: 0, y: 0, width: appItemView.bounds.width, height: appItemView.bounds.height),
            of: appItemView,
            preferredEdge: .maxY
        )
    }
}

enum LKMCPAppSwitcher {
    static func fetchAndOpen(timeout: TimeInterval) -> [String: Any] {
        LKMCPClientDiagnostics.shared.mcpOperationWillBegin()
        defer { LKMCPClientDiagnostics.shared.mcpOperationDidEnd() }

        if Thread.isMainThread {
            var result: [String: Any] = [:]
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                result = fetchAndOpen(timeout: timeout)
                group.leave()
            }
            _ = group.wait(timeout: .now() + timeout + LKMCPTiming.mainQueueHop + 10)
            return result
        }

        let fetchResult: Result<[LKInspectableApp], Error> = LKMCPBlockingWait.onMain(timeout: timeout) { done in
            _ = LookinRACSignalRx.observeMainThread(
                LKAppsManager.sharedInstance.fetchAppsForPopover(withImage: false)
            )
            .subscribe(
                onSuccess: { apps in done(.success(apps)) },
                onFailure: { error in done(.failure(error)) }
            )
        }

        guard case .success(let apps) = fetchResult else {
            return response(for: [])
        }

        let showSem = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            LKNavigationManager.sharedInstance.staticWindowController?
                .presentAppSwitcherPopover(apps: apps, source: .appButton)
            showSem.signal()
        }
        _ = showSem.wait(timeout: .now() + LKMCPTiming.mainQueueHop)

        let expectedCount = apps.count
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let targets = LKMCPInspectTarget.launchTargets()
            if targets.count >= expectedCount {
                return response(for: targets)
            }
            if !targets.isEmpty, expectedCount <= 1 {
                return response(for: targets)
            }
            Thread.sleep(forTimeInterval: LKMCPTiming.appSwitcherTilePollInterval)
        }
        return response(for: LKMCPInspectTarget.launchTargets())
    }

    private static func response(for targets: [[String: Any]]) -> [String: Any] {
        [
            "ok": !targets.isEmpty,
            "count": targets.count,
            "targets": targets,
            "uiMode": LKNavigationManager.sharedInstance.mcpUIMode.rawValue,
            "lastDiscover": LKMCPClientDiagnostics.shared.lastDiscoverSummary,
        ]
    }
}
