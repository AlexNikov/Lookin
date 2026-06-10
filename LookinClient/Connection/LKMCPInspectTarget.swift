//
//  LKMCPInspectTarget.swift
//  Lookin
//
//  MCP automation: launch-screen tiles and sim ↔ USB target selection.
//

import AppKit
import LookinShared
import RxSwift

enum LKMCPInspectTarget {
    /// Triggers launch-screen reload and waits for tiles / discover (MCP automation).
    static func refreshLaunchTargets(timeout: TimeInterval = LKMCPTiming.defaultOperationTimeout) -> [String: Any] {
        LKMCPClientDiagnostics.shared.mcpOperationWillBegin()
        defer { LKMCPClientDiagnostics.shared.mcpOperationDidEnd() }
        if Thread.isMainThread {
            var result: [String: Any] = [:]
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                result = refreshLaunchTargets(timeout: timeout)
                group.leave()
            }
            _ = group.wait(timeout: .now() + timeout + LKMCPTiming.mainQueueHop)
            return result
        }

        let subscribeSem = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            let nav = LKNavigationManager.sharedInstance
            if nav.launchWindowController == nil {
                nav.showLaunch()
            }
            nav.launchWindowController?.launchViewController?.mcpReloadWithoutAutoEnter()
            subscribeSem.signal()
        }
        _ = subscribeSem.wait(timeout: .now() + LKMCPTiming.mainQueueHop)

        let deadline = Date().addingTimeInterval(timeout)
        var targets: [LKMCPLaunchTile] = []
        while Date() < deadline {
            targets = launchTilesOnMain()
            let usable = LKMCPClientDiagnostics.shared.lastDiscoverSummary["usableAppCount"] as? Int ?? 0
            if targets.count >= 2 || (targets.count >= 1 && usable >= 1) {
                break
            }
            Thread.sleep(forTimeInterval: LKMCPTiming.launchTilePollInterval)
        }

        return [
            "ok": !targets.isEmpty,
            "uiMode": LKNavigationManager.sharedInstance.mcpUIMode.rawValue,
            "count": targets.count,
            "targets": targets.map { $0.dictionaryRepresentation() },
            "lastDiscover": LKMCPClientDiagnostics.shared.lastDiscoverSummary,
        ]
    }

    /// Visible `LKLaunchAppView` tiles on the launch screen or app-switcher popover.
    static func launchTargets() -> [[String: Any]] {
        launchTiles().map { $0.dictionaryRepresentation() }
    }

    /// Enter inspector from launch or switch sim ↔ USB in inspector (blocks up to `timeout` s).
    static func selectInspectTarget(
        channel: String?,
        accessibilityIdentifier: String?,
        index: Int?,
        timeout: TimeInterval = LKMCPTiming.defaultOperationTimeout
    ) -> [String: Any] {
        selectInspectTargetStructured(
            channel: channel,
            accessibilityIdentifier: accessibilityIdentifier,
            index: index,
            timeout: timeout
        ).dictionaryRepresentation()
    }

    private static func selectInspectTargetStructured(
        channel: String?,
        accessibilityIdentifier: String?,
        index: Int?,
        timeout: TimeInterval
    ) -> LKMCPSelectInspectResult {
        LKMCPClientDiagnostics.shared.mcpOperationWillBegin()
        defer { LKMCPClientDiagnostics.shared.mcpOperationDidEnd() }
        if Thread.isMainThread {
            var result = LKMCPSelectInspectResult.timeout(channel: .unknown)
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                result = selectInspectTargetStructured(
                    channel: channel,
                    accessibilityIdentifier: accessibilityIdentifier,
                    index: index,
                    timeout: timeout
                )
                group.leave()
            }
            _ = group.wait(timeout: .now() + timeout + LKMCPTiming.mainQueueHop)
            return result
        }

        let normalizedChannel = channel?.lowercased()
        let channelTag = LKMCPChannelTag(rawChannel: normalizedChannel)
        let stub = resolveInspectableStubFromTiles(
            channel: normalizedChannel,
            accessibilityIdentifier: accessibilityIdentifier,
            index: index
        )
        if stub == nil,
           normalizedChannel == nil,
           (accessibilityIdentifier ?? "").isEmpty,
           index == nil {
            return .noMatchingTarget(launchTargets: launchTiles())
        }

        let previousMode = LKNavigationManager.sharedInstance.mcpUIMode
        let previousApp = LKAppsManager.sharedInstance.inspectingApp
        let fallbackChannel: LKMCPChannelTag = {
            if channelTag != .unknown { return channelTag }
            return LKAppsManager.mcpChannelTag(for: stub)
        }()

        final class SubHold: @unchecked Sendable {
            var disposable: Disposable?
        }
        let subHold = SubHold()

        let waitResult: Result<LKMCPSelectInspectSuccess, Error> = LKMCPBlockingWait.onMain(
            timeout: timeout + LKMCPTiming.connectCompletionSlack
        ) { done in
            closeAppSwitcherPopoverIfVisible()
            LKStaticAsyncUpdateManager.sharedInstance.endUpdating()
            let conn = LKConnectionManager.sharedInstance
            let connectSingle: Single<(LKInspectableApp, LookinHierarchyInfo)>
            if let stub, stub.serverVersionError == nil {
                connectSingle = LKAppsManager.sharedInstance.connectInspectableApp(stub)
            } else if let normalizedChannel {
                connectSingle = LKAppsManager.sharedInstance.fetchAppInfos(withImage: false, localInfos: nil)
                    .flatMap { apps -> Single<(LKInspectableApp, LookinHierarchyInfo)> in
                        guard let match = apps.first(where: { candidate in
                            guard candidate.serverVersionError == nil, candidate.appInfo != nil else { return false }
                            return LKAppsManager.mcpChannelTag(for: candidate).rawValue == normalizedChannel
                        }) else {
                            return .error(LKLookinClientErrors.noConnect)
                        }
                        conn.releaseDiscoveryChannels(except: match.channel)
                        return match.fetchHierarchyData().map { (match, $0) }
                    }
            } else if let stub {
                connectSingle = LKAppsManager.sharedInstance.connectInspectableApp(stub)
            } else {
                connectSingle = .error(LKLookinClientErrors.noConnect)
            }
            subHold.disposable = LookinRACSignalRx.observeMainThread(connectSingle)
                .subscribe(
                    onSuccess: { pair in
                        let (freshApp, info) = pair
                        let keepState = LKAppsManager.isSameInspectableSession(previousApp, freshApp)
                        LKAppsManager.sharedInstance.inspectingApp = freshApp
                        LKStaticHierarchyDataSource.sharedInstance.reload(with: info, keepState: keepState)
                        if previousMode == .launch {
                            LKNavigationManager.sharedInstance.showStaticWorkspace()
                            LKNavigationManager.sharedInstance.closeLaunch()
                        }
                        done(.success(LKMCPSelectInspectSuccess(
                            freshApp: freshApp,
                            previousMode: previousMode,
                            keepState: keepState
                        )))
                    },
                    onFailure: { error in
                        done(.failure(error))
                    }
                )
        }
        _ = subHold.disposable

        switch waitResult {
        case .success(let payload):
            return .success(payload)
        case .failure(let error):
            let nsError = error as NSError
            if nsError.isEqual(LKLookinClientErrors.timeout())
                || nsError.isEqual(LKLookinClientErrors.inner) {
                return .timeout(channel: fallbackChannel)
            }
            return .failure(
                message: nsError.localizedDescription,
                code: nsError.code,
                channel: fallbackChannel
            )
        }
    }

    // MARK: - Private

    private static func launchTilesOnMain() -> [LKMCPLaunchTile] {
        if Thread.isMainThread {
            return launchTiles()
        }
        var result: [LKMCPLaunchTile] = []
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            result = launchTiles()
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + LKMCPTiming.mainQueueHop)
        return result
    }

    private static func launchTiles() -> [LKMCPLaunchTile] {
        var entries: [(view: LKLaunchAppView, channel: LKMCPChannelTag)] = []
        for window in NSApp.windows where window.isVisible {
            collectLaunchAppViews(in: window.contentView, into: &entries)
        }
        let sorted = entries.sorted { lhs, rhs in
            let lhsSim = lhs.channel == .sim
            let rhsSim = rhs.channel == .sim
            if lhsSim != rhsSim { return lhsSim && !rhsSim }
            let lhsDevice = lhs.view.app?.appInfo?.deviceDescription ?? ""
            let rhsDevice = rhs.view.app?.appInfo?.deviceDescription ?? ""
            return lhsDevice < rhsDevice
        }
        return sorted.enumerated().map { index, entry in
            LKMCPLaunchTile.from(view: entry.view, index: index, channel: entry.channel)
        }
    }

    private static func resolveInspectableStubFromTiles(
        channel: String?,
        accessibilityIdentifier: String?,
        index: Int?
    ) -> LKInspectableApp? {
        var entries: [(view: LKLaunchAppView, channel: LKMCPChannelTag)] = []
        for window in NSApp.windows where window.isVisible {
            collectLaunchAppViews(in: window.contentView, into: &entries)
        }
        let sorted = entries.sorted { lhs, rhs in
            let lhsSim = lhs.channel == .sim
            let rhsSim = rhs.channel == .sim
            if lhsSim != rhsSim { return lhsSim && !rhsSim }
            return (lhs.view.app?.appInfo?.deviceDescription ?? "")
                < (rhs.view.app?.appInfo?.deviceDescription ?? "")
        }

        if let index, index >= 0, index < sorted.count, let app = sorted[index].view.app {
            return app
        }
        if let accessibilityIdentifier, !accessibilityIdentifier.isEmpty {
            if let match = sorted.first(where: { $0.view.accessibilityIdentifier() == accessibilityIdentifier })?.view.app {
                return match
            }
        }
        if let channel, !channel.isEmpty {
            let normalized = LKMCPChannelTag(rawChannel: channel)
            if let match = sorted.first(where: { $0.channel == normalized })?.view.app {
                return match
            }
        }
        return nil
    }

    /// Dismiss toolbar app-switcher so its in-flight `fetchAppInfos` does not block sim ↔ USB select.
    private static func closeAppSwitcherPopoverIfVisible() {
        for window in NSApp.windows where window.isVisible {
            if window.contentViewController is LKMenuPopoverAppsListController {
                window.close()
            }
        }
    }

    private static func collectLaunchAppViews(
        in view: NSView?,
        into entries: inout [(view: LKLaunchAppView, channel: LKMCPChannelTag)]
    ) {
        guard let view, !view.isHidden, view.alphaValue > 0.05 else { return }
        let frame = view.frame
        if frame.width < 4 || frame.height < 4 { return }

        if let launchView = view as? LKLaunchAppView, launchView.app != nil {
            entries.append((launchView, LKAppsManager.mcpChannelTag(for: launchView.app)))
        }
        for subview in view.subviews {
            collectLaunchAppViews(in: subview, into: &entries)
        }
    }
}
