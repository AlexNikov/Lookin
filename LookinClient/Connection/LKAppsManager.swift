import Foundation
import LookinShared
import RxRelay
import RxSwift

public final class LKAppsManager: NSObject {
    public static let sharedInstance = LKAppsManager()

    static func usableInspectableApps(from apps: [LKInspectableApp]) -> [LKInspectableApp] {
        apps.filter { $0.serverVersionError == nil && $0.appInfo != nil }
    }

    /// Same bundle on simulator and USB counts as different inspect targets.
    static func isSameInspectableSession(_ a: LKInspectableApp?, _ b: LKInspectableApp?) -> Bool {
        guard let a, let b else { return false }
        guard a.appInfo?.isEqual(toAppInfo: b.appInfo) == true else { return false }
        let conn = LKConnectionManager.sharedInstance
        return conn.channelUsesUSB(a.channel) == conn.channelUsesUSB(b.channel)
    }

    /// Peertalk transport for an inspect target — survives a dropped channel (reload / reconnect).
    static func inspectSessionUsesUSB(_ app: LKInspectableApp) -> Bool {
        if app.isLaunchUSBPendingPlaceholder {
            return true
        }
        let conn = LKConnectionManager.sharedInstance
        if let channel = app.channel {
            return conn.channelUsesUSB(channel)
        }
        if app.appInfo?.deviceType == .simulator {
            return false
        }
        return conn.hasAttachedUSBDevices
    }

    private enum LKInspectTransportFilter {
        case usb
        case simulator
    }

    public enum SwitchStatus {
        case idle
        /// App button tapped; waiting for the app list to arrive before showing the popover.
        case fetchingAppList
        case connecting(LKInspectableApp)

        /// True whenever the App button should be disabled.
        public var isBusy: Bool {
            switch self {
            case .idle: return false
            case .fetchingAppList, .connecting: return true
            }
        }

        public var isConnecting: Bool {
            if case .connecting = self { return true }
            return false
        }
    }

    public struct SwitchSuccess {
        public let previousApp: LKInspectableApp?
        public let freshApp: LKInspectableApp
        public let hierarchyInfo: LookinHierarchyInfo
    }

    private static func transportFilter(forUSB wantsUSB: Bool) -> LKInspectTransportFilter {
        wantsUSB ? .usb : .simulator
    }

    private static func filterChannels(
        _ channels: [LKPeerChannel],
        transport: LKInspectTransportFilter
    ) -> [LKPeerChannel] {
        let conn = LKConnectionManager.sharedInstance
        switch transport {
        case .usb:
            return channels.filter { conn.channelUsesUSB($0) }
        case .simulator:
            return channels.filter { !conn.channelUsesUSB($0) }
        }
    }

    /// Simulator tiles first, then USB; stable order within each group.
    static func sortedForDisplay(_ apps: [LKInspectableApp]) -> [LKInspectableApp] {
        apps.sorted { lhs, rhs in
            let lhsSim = !inspectSessionUsesUSB(lhs)
            let rhsSim = !inspectSessionUsesUSB(rhs)
            if lhsSim != rhsSim { return lhsSim && !rhsSim }
            let lhsDevice = lhs.appInfo?.deviceDescription ?? ""
            let rhsDevice = rhs.appInfo?.deviceDescription ?? ""
            if lhsDevice != rhsDevice { return lhsDevice < rhsDevice }
            return (lhs.appInfo?.appName ?? "") < (rhs.appInfo?.appName ?? "")
        }
    }

    /// Adds USB placeholder tiles when a physical device is attached but its demo is not listening yet.
    static func appsForLaunchDisplay(discovered: [LKInspectableApp]) -> [LKInspectableApp] {
        let conn = LKConnectionManager.sharedInstance
        let hasConnectedUSBApp = discovered.contains {
            $0.serverVersionError == nil && $0.appInfo != nil && conn.channelUsesUSB($0.channel)
        }
        guard conn.hasAttachedUSBDevices, !hasConnectedUSBApp else {
            return sortedForDisplay(discovered)
        }

        var result = discovered
        for deviceID in conn.uniqueAttachedUSBDeviceIDs() {
            let placeholder = LKInspectableApp()
            placeholder.isLaunchUSBPendingPlaceholder = true
            placeholder.pendingUSBDeviceID = deviceID
            let info = LookinAppInfo()
            info.deviceType = .others
            info.deviceDescription = conn.usbDeviceLabel(for: deviceID) ?? "iPhone"
            info.appName = NSLocalizedString("Waiting for inspectable app", comment: "")
            placeholder.appInfo = info
            result.append(placeholder)
        }
        return sortedForDisplay(result)
    }

    /// USB demo when a physical device is attached (CollLayout on iPhone, etc.).
    static func preferredUSBInspectableApp(from apps: [LKInspectableApp]) -> LKInspectableApp? {
        let usable = usableInspectableApps(from: apps)
        guard LKConnectionManager.sharedInstance.hasAttachedUSBDevices else { return nil }
        return usable.first { LKConnectionManager.sharedInstance.channelUsesUSB($0.channel) }
    }

    /// Launch auto-enter: only when a single target, or USB-only while iPhone is attached (never steal sim tile).
    static func preferredAppForLaunchAutoEnter(from apps: [LKInspectableApp]) -> LKInspectableApp? {
        let usable = usableInspectableApps(from: apps)
        guard !usable.isEmpty else { return nil }
        if usable.count == 1 { return usable[0] }
        let conn = LKConnectionManager.sharedInstance
        let simApps = usable.filter { !conn.channelUsesUSB($0.channel) }
        let usbApps = usable.filter { conn.channelUsesUSB($0.channel) }
        if !simApps.isEmpty, !usbApps.isEmpty {
            return nil
        }
        return preferredUSBInspectableApp(from: apps) ?? usable.first
    }

    /// Launch / MCP: prefer USB demo when iPhone is plugged in, else known demo bundle, else first usable.
    static func preferredInspectableApp(from apps: [LKInspectableApp]) -> LKInspectableApp? {
        let usable = usableInspectableApps(from: apps)
        guard !usable.isEmpty else { return nil }
        if let usb = preferredUSBInspectableApp(from: apps) {
            return usb
        }
        return LKDemoBundleID.firstMatch(in: usable) ?? usable.first
    }

    private let inspectingAppRelay = BehaviorRelay<LKInspectableApp?>(value: nil)
    var inspectingAppObservable: Observable<LKInspectableApp?> {
        inspectingAppRelay.asObservable()
    }

    public var inspectingApp: LKInspectableApp? {
        get { inspectingAppRelay.value }
        set {
            let oldValue = inspectingAppRelay.value
            guard oldValue !== newValue else { return }
            // Accept the new session before closing the old Peertalk channel. Otherwise
            // channelWillEnd on the previous channel fires while inspectingApp still points
            // at it and auto-reconnect steals the switch (sim ↔ USB).
            inspectingAppRelay.accept(newValue)
            if let newValue {
                willConnectToAppRelay.accept(newValue)
            }
            if let oldValue, let oldChannel = oldValue.channel, oldChannel !== newValue?.channel {
                LKConnectionManager.sharedInstance.releaseCachedChannel(oldChannel)
            }
            let shouldPostNotification = oldValue != nil && newValue == nil
            if shouldPostNotification {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LKInspectingAppDidEndNotificationName"),
                    object: self
                )
            }
        }
    }

    /// Launch tile or toolbar popover: re-resolve Peertalk (sim vs USB), close other links, fetch hierarchy.
    public func connectInspectableApp(_ selected: LKInspectableApp) -> Single<(LKInspectableApp, LookinHierarchyInfo)> {
        let conn = LKConnectionManager.sharedInstance
        let wantsUSB = Self.inspectSessionUsesUSB(selected)
        guard let targetInfo = selected.appInfo else {
            return .error(LKLookinClientErrors.inner)
        }
        intentionalSessionChange = true

        // Fast path: tile/popover already holds a live Peertalk channel — avoid fetchAppInfos lock + port scan.
        if selected.serverVersionError == nil,
           let channel = selected.channel,
           channel.isConnected {
            conn.releaseDiscoveryChannels(except: channel)
            return selected.fetchHierarchyData()
                .map { (selected, $0) }
                .catch { [weak self] _ -> Single<(LKInspectableApp, LookinHierarchyInfo)> in
                    guard let self else { return .error(LKLookinClientErrors.noConnect) }
                    return self.connectInspectableAppViaRediscover(
                        selected: selected,
                        targetInfo: targetInfo,
                        wantsUSB: wantsUSB
                    )
                }
                .do(onDispose: { [weak self] in
                    self?.intentionalSessionChange = false
                })
        }

        return connectInspectableAppViaRediscover(
            selected: selected,
            targetInfo: targetInfo,
            wantsUSB: wantsUSB
        )
        .do(onDispose: { [weak self] in
            self?.intentionalSessionChange = false
        })
    }

    private func connectInspectableAppViaRediscover(
        selected: LKInspectableApp,
        targetInfo: LookinAppInfo,
        wantsUSB: Bool
    ) -> Single<(LKInspectableApp, LookinHierarchyInfo)> {
        fetchHierarchyAfterRediscover(matching: selected, targetInfo: targetInfo, wantsUSB: wantsUSB)
    }

    /// Re-resolve Peertalk for the same inspect target (sim vs USB), close other links, fetch hierarchy.
    private func fetchHierarchyAfterRediscover(
        matching session: LKInspectableApp,
        targetInfo: LookinAppInfo,
        wantsUSB: Bool
    ) -> Single<(LKInspectableApp, LookinHierarchyInfo)> {
        let conn = LKConnectionManager.sharedInstance
        return fetchAppInfos(withImage: false, localInfos: [targetInfo], usbOnly: wantsUSB)
            .flatMap { [weak self] apps -> Single<(LKInspectableApp, LookinHierarchyInfo)> in
                guard let self else { return .error(LKLookinClientErrors.inner) }
                let fresh = apps.first(where: { candidate in
                    guard candidate.serverVersionError == nil, candidate.appInfo != nil else { return false }
                    guard conn.channelUsesUSB(candidate.channel) == wantsUSB else { return false }
                    let bundle = targetInfo.appBundleIdentifier ?? ""
                    if !bundle.isEmpty {
                        return targetInfo.isEqual(toAppInfo: candidate.appInfo)
                    }
                    return Self.isSameInspectableSession(session, candidate)
                }) ?? self.pickInspectableAppForReload(current: session, from: apps, wantsUSB: wantsUSB)
                guard let fresh else {
                    LookinDiagLog.log(
                        "client reconnect: no Peertalk match usb=\(wantsUSB) usable=\(apps.count)"
                    )
                    return .error(LKLookinClientErrors.noConnect)
                }
                if let icon = targetInfo.appIcon {
                    fresh.appInfo?.appIcon = icon
                }
                if let screenshot = targetInfo.screenshot {
                    fresh.appInfo?.screenshot = screenshot
                }
                conn.releaseDiscoveryChannels(except: fresh.channel)
                return fresh.fetchHierarchyData().map { (fresh, $0) }
            }
    }

    /// Toolbar App button: fetches the app list for the popover and blocks the button while loading.
    /// Only blocks when there are attached USB devices or a booted simulator (i.e. when the scan
    /// can take non-trivial time). Returns the same value as fetchAppInfos.
    public func fetchAppsForPopover(withImage needImages: Bool) -> Single<[LKInspectableApp]> {
        let conn = LKConnectionManager.sharedInstance
        let hasTargets = conn.hasAttachedUSBDevices || LKConnectionManager.mcpHasBootedIOSSimulator()
        if hasTargets {
            switchStatusRelay.accept(.fetchingAppList)
        }
        let needsDualTargets = inspectingApp != nil
            && LKConnectionManager.sharedInstance.hasAttachedUSBDevices
        return fetchAppInfosForPopoverUnlocked(withImage: needImages, needsDualTargets: needsDualTargets)
            .do(onDispose: { [weak self] in
                // Only reset if we're still in fetchingAppList; don't overwrite a connecting state
                // that started while this fetch was in flight (shouldn't happen, but be safe).
                guard let self, case .fetchingAppList = self.switchStatusRelay.value else { return }
                self.switchStatusRelay.accept(.idle)
            })
    }

    /// Popover list while inspecting: prefer a light fetch; full relisten only if sim+USB list is incomplete.
    private func fetchAppInfosForPopoverUnlocked(
        withImage needImages: Bool,
        needsDualTargets: Bool
    ) -> Single<[LKInspectableApp]> {
        func usableCount(_ apps: [LKInspectableApp]) -> Int {
            Self.usableInspectableApps(from: apps).count
        }
        return fetchAppInfos(withImage: needImages, localInfos: nil, forceFreshDiscovery: false)
            .flatMap { [weak self] apps -> Single<[LKInspectableApp]> in
                guard let self, needsDualTargets, usableCount(apps) < 2 else {
                    return .just(apps)
                }
                return self.fetchAppInfos(withImage: needImages, localInfos: nil, forceFreshDiscovery: true)
            }
    }

    /// Toolbar app popover: cancels any in-flight switch and starts a fresh one.
    /// Observe switchSuccessObservable / switchFailureObservable for results.
    public func switchToInspectableApp(_ selected: LKInspectableApp) {
        let previousApp = inspectingApp
        // Set flag before resetting the bag so the old subscription's onDispose (which clears the flag)
        // cannot leave a window where channelWillEnd triggers a spurious auto-reconnect.
        intentionalSessionChange = true
        autoReconnectDisposeBag = DisposeBag()
        currentSwitchDisposeBag = DisposeBag()
        switchStatusRelay.accept(.connecting(selected))
        connectInspectableApp(selected)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onSuccess: { [weak self] pair in
                    guard let self else { return }
                    let (freshApp, info) = pair
                    self.inspectingApp = freshApp
                    self.switchStatusRelay.accept(.idle)
                    self.switchSuccessRelay.accept(SwitchSuccess(
                        previousApp: previousApp,
                        freshApp: freshApp,
                        hierarchyInfo: info
                    ))
                },
                onFailure: { [weak self] error in
                    self?.switchStatusRelay.accept(.idle)
                    self?.switchFailureRelay.accept(error)
                }
            )
            .disposed(by: currentSwitchDisposeBag)
    }

    private let didAutoReconnectSuccRelay = PublishRelay<Void>()

    public var didAutoReconnectSuccObservable: Observable<Void> {
        didAutoReconnectSuccRelay.asObservable()
    }

    private let willConnectToAppRelay = PublishRelay<LKInspectableApp>()
    /// Suppresses auto-reconnect while closing the previous Peertalk link during sim ↔ USB connect.
    private var intentionalSessionChange = false
    private let disposeBag = DisposeBag()
    private var autoReconnectDisposeBag = DisposeBag()

    private static let autoReconnectMaxAttempts = 10
    private static let autoReconnectIntervalSec: RxTimeInterval = .seconds(3)

    private let switchStatusRelay = BehaviorRelay<SwitchStatus>(value: .idle)
    public var switchStatusObservable: Observable<SwitchStatus> { switchStatusRelay.asObservable() }

    private let switchSuccessRelay = PublishRelay<SwitchSuccess>()
    public var switchSuccessObservable: Observable<SwitchSuccess> { switchSuccessRelay.asObservable() }

    private let switchFailureRelay = PublishRelay<Error>()
    public var switchFailureObservable: Observable<Error> { switchFailureRelay.asObservable() }

    private var currentSwitchDisposeBag = DisposeBag()

    private override init() {
        super.init()
        setupAutoReconnect()
    }

    /// Ends the current inspect session and closes Peertalk so the demo can accept a new client.
    public func endInspectingSession() {
        autoReconnectDisposeBag = DisposeBag()
        LKStaticAsyncUpdateManager.sharedInstance.endUpdating()
        inspectingApp?.cancelHierarchyDetailFetching()
        let channel = inspectingApp?.channel
        let hadActiveInspection = inspectingApp != nil
        inspectingApp = nil
        LKConnectionManager.sharedInstance.cancelAllActivePeerRequests()
        if let channel {
            LKConnectionManager.sharedInstance.releaseCachedChannel(channel)
        }
        if hadActiveInspection {
            LKConnectionManager.sharedInstance.releaseAllDiscoveryChannels()
        }
        LKConnectionManager.sharedInstance.clearMCPSessionSnapshots()
        LKStaticHierarchyDataSource.sharedInstance.clearSessionHierarchy()
    }

    /// Re-discovers simulator/USB apps with a fresh Peertalk scan (use on toolbar Reload after switching demo).
    public func fetchAppInfosForReload(localInfos: [LookinAppInfo]? = nil) -> Single<[LKInspectableApp]> {
        if let channel = inspectingApp?.channel {
            LKConnectionManager.sharedInstance.releaseCachedChannel(channel)
        }
        return fetchAppInfos(withImage: false, localInfos: localInfos, forceFreshDiscovery: true)
    }

    /// Re-fetch hierarchy on the live channel, or reattach to the same app when Peertalk dropped (USB watchdog / Mac quit).
    public func fetchHierarchyDataForReload(from app: LKInspectableApp) -> Single<LookinHierarchyInfo> {
        guard let targetInfo = app.appInfo else {
            return .error(LKLookinClientErrors.inner)
        }
        let wantsUSB = Self.inspectSessionUsesUSB(app)
        intentionalSessionChange = true

        return prepareInspectableChannel(app.channel)
            .andThen(
                Single.deferred { [self] in
                    let conn = LKConnectionManager.sharedInstance
                    let reloadSingle: Single<(LKInspectableApp, LookinHierarchyInfo)>
                    if let channel = app.channel, channel.isConnected {
                        conn.releaseDiscoveryChannels(except: channel)
                        reloadSingle = app.fetchHierarchyData()
                            .map { (app, $0) }
                            .catch { [weak self] _ -> Single<(LKInspectableApp, LookinHierarchyInfo)> in
                                guard let self else { return .error(LKLookinClientErrors.noConnect) }
                                LookinDiagLog.log(
                                    "client reload: live hierarchy failed — reattach usb=\(wantsUSB)"
                                )
                                return self.fetchHierarchyAfterRediscover(
                                    matching: app,
                                    targetInfo: targetInfo,
                                    wantsUSB: wantsUSB
                                )
                            }
                    } else {
                        LookinDiagLog.log("client reload: channel down — reattach usb=\(wantsUSB)")
                        reloadSingle = self.fetchHierarchyAfterRediscover(
                            matching: app,
                            targetInfo: targetInfo,
                            wantsUSB: wantsUSB
                        )
                    }
                    return reloadSingle
                }
            )
            .do(onSuccess: { [weak self] fresh, _ in
                self?.inspectingApp = fresh
            })
            .map { $0.1 }
            .do(onDispose: { [weak self] in
                self?.intentionalSessionChange = false
            })
    }

    /// Picks the app to inspect after reload. Returns nil when multiple apps are running and none matches the current session.
    public func pickInspectableAppForReload(
        current: LKInspectableApp?,
        from apps: [LKInspectableApp],
        wantsUSB: Bool? = nil
    ) -> LKInspectableApp? {
        let conn = LKConnectionManager.sharedInstance
        var usable = apps.filter { $0.serverVersionError == nil && $0.appInfo != nil }
        if let wantsUSB {
            usable = usable.filter { conn.channelUsesUSB($0.channel) == wantsUSB }
        }
        guard !usable.isEmpty else { return nil }
        if usable.count == 1 { return usable[0] }
        if let current,
           let match = usable.first(where: { Self.isSameInspectableSession(current, $0) }) {
            return match
        }
        return nil
    }

    private static let fetchAppInfosLock = NSLock()
    private static let fetchAppInfosQueue = DispatchQueue(label: "lookin.client.fetchAppInfos", qos: .userInitiated)
    private static var fetchLockAcquiredAt: TimeInterval?

    static func mcpFetchBlockedAgeSec() -> TimeInterval {
        guard let acquired = fetchLockAcquiredAt else { return 0 }
        return Date().timeIntervalSince1970 - acquired
    }

    public func fetchAppInfos(
        withImage needImages: Bool,
        localInfos: [LookinAppInfo]?,
        forceFreshDiscovery: Bool = false,
        usbOnly: Bool? = nil
    ) -> Single<[LKInspectableApp]> {
        let transportFilter: LKInspectTransportFilter?
        switch usbOnly {
        case true?: transportFilter = .usb
        case false?: transportFilter = .simulator
        default: transportFilter = nil
        }
        return Single.deferred { [self] in
            Single.create { observer in
                var terminated = false
                let terminate: (Result<[LKInspectableApp], Error>) -> Void = { result in
                    guard !terminated else { return }
                    terminated = true
                    switch result {
                    case .success(let apps):
                        observer(.success(apps))
                    case .failure(let error):
                        observer(.failure(error))
                    }
                }
                var innerDisposable: Disposable?
                let work = DispatchWorkItem { [self] in
                    Self.fetchLockAcquiredAt = Date().timeIntervalSince1970
                    Self.fetchAppInfosLock.lock()
                    innerDisposable = self.fetchAppInfosUnlocked(
                        withImage: needImages,
                        localInfos: localInfos,
                        forceFreshDiscovery: forceFreshDiscovery,
                        transportFilter: transportFilter
                    )
                    .do(onDispose: {
                        Self.fetchAppInfosLock.unlock()
                        Self.fetchLockAcquiredAt = nil
                    })
                    .subscribe(
                        onSuccess: { terminate(.success($0)) },
                        onFailure: { terminate(.failure($0)) }
                    )
                }
                Self.fetchAppInfosQueue.async(execute: work)
                return Disposables.create {
                    work.cancel()
                    innerDisposable?.dispose()
                    terminate(.failure(LKLookinClientErrors.discard()))
                }
            }
        }
    }

    /// Restart read loop on async Peertalk before toolbar reload / rediscover.
    private func prepareInspectableChannel(_ channel: LKPeerChannel?) -> Completable {
        Completable.create { done in
            guard let async = channel as? LKAsyncPeerChannel else {
                done(.completed)
                return Disposables.create()
            }
            Task {
                await async.reconcileTransportState()
                done(.completed)
            }
            return Disposables.create()
        }
    }

    private func fetchAppInfosUnlocked(
        withImage needImages: Bool,
        localInfos: [LookinAppInfo]?,
        forceFreshDiscovery: Bool = false,
        transportFilter: LKInspectTransportFilter? = nil
    ) -> Single<[LKInspectableApp]> {
        let validAppInfos = (localInfos ?? []).filter { info in
            Date().timeIntervalSince1970 - info.cachedTimestamp <= 8
        }
        let localInfoIdentifiers = validAppInfos.map { NSNumber(value: $0.appInfoIdentifier) }
        let appParams = WireAppRequestParams(
            needImages: needImages,
            localIdentifiers: localInfoIdentifiers.map(\.uintValue)
        )

        return LKConnectionManager.sharedInstance.tryToConnectAllPorts(forceFreshDiscovery: forceFreshDiscovery)
            .flatMap { connectedChannels -> Single<[LKInspectableApp]> in
                let scopedChannels: [LKPeerChannel]
                if let transportFilter {
                    scopedChannels = Self.filterChannels(connectedChannels, transport: transportFilter)
                    if scopedChannels.isEmpty {
                        let tag = LKMCPChannelTag(usb: transportFilter == .usb).rawValue
                        LookinDiagLog.log(
                            "client fetchAppInfos: 0 \(tag) channel(s) after transport filter (connected=\(connectedChannels.count))"
                        )
                    }
                } else {
                    scopedChannels = connectedChannels
                }
                guard !scopedChannels.isEmpty else {
                    LookinDiagLog.log("client fetchAppInfos: no Peertalk channels (is demo running with LookinServer?)")
                    return .just([])
                }
                let liveChannels = scopedChannels.filter(\.isConnected)
                if liveChannels.isEmpty {
                    let ports = scopedChannels.map { String($0.targetPort) }.joined(separator: ",")
                    LookinDiagLog.log(
                        "client fetchAppInfos: \(scopedChannels.count) channel(s) ports=[\(ports)] but none connected"
                    )
                    return .just([])
                }

                let discoverPerChannelTimeout = LKWireClientRequestTimeout.appInfo
                    + LKWireClientRequestTimeout.preflightPingBeforeApp
                    + 2
                let requestSingles: [Single<LKInspectableApp?>] = liveChannels.map { [weak self] channel in
                    // The active inspection channel is busy streaming hierarchy data (LookinRequestTypeHierarchy)
                    // and won't respond to a new LookinRequestTypeApp — request times out with code -405.
                    // Reuse the already-known app info instead of sending a fresh discovery request.
                    if let inspecting = self?.inspectingApp,
                       inspecting.channel === channel,
                       let cachedInfo = inspecting.appInfo {
                        let reuse = LKInspectableApp()
                        reuse.appInfo = cachedInfo
                        reuse.channel = channel
                        LookinDiagLog.log(
                            "client fetchAppInfos: reuse cached app info for active inspection channel port=\(channel.targetPort)"
                        )
                        return .just(reuse)
                    }
                    return LKConnectionManager.sharedInstance.request(
                        withType: UInt32(LookinRequestTypeApp),
                        data: nil,
                        channel: channel,
                        wirePayload: .app(appParams)
                    )
                    .take(1)
                    .timeout(.seconds(Int(discoverPerChannelTimeout)), scheduler: MainScheduler.instance)
                    .asSingle()
                    .map { pair -> LKInspectableApp? in
                        Self.inspectableApp(
                            from: pair,
                            validAppInfos: validAppInfos,
                            channel: channel
                        )
                    }
                    .catch { error in
                        let nsError = error as NSError
                        let port = channel.targetPort
                        if nsError.code == LookinErrCode_ServerVersionTooHigh || nsError.code == LookinErrCode_ServerVersionTooLow {
                            LookinDiagLog.log(
                                "client App request version mismatch port=\(port) code=\(nsError.code)"
                            )
                            let app = LKInspectableApp()
                            app.serverVersionError = nsError
                            return .just(app)
                        }
                        LookinDiagLog.log(
                            "client App request FAIL port=\(port) code=\(nsError.code) \(nsError.localizedDescription)"
                        )
                        return .just(nil)
                    }
                }

                return Single.zip(requestSingles)
                    .map { results in
                        let apps = results.compactMap { $0 }
                        let usable = apps.filter { $0.serverVersionError == nil && $0.appInfo != nil }
                        if usable.isEmpty, !liveChannels.isEmpty {
                            let ports = liveChannels.map { String($0.targetPort) }.joined(separator: ",")
                            LookinDiagLog.log(
                                "client fetchAppInfos: 0 apps from \(liveChannels.count) channel(s) ports=[\(ports)] — iPhone: Run CollLayout demo on device (pod install + rebuild); Simulator: launch demo, bring Simulator to front"
                            )
                        }
                        let channels = usable.map { app -> [String: Any] in
                            let tag = LKMCPChannelTag(
                                usb: LKConnectionManager.sharedInstance.channelUsesUSB(app.channel)
                            ).rawValue
                            return [
                                "channel": tag,
                                "port": app.channel?.targetPort ?? 0,
                                "bundleId": app.appInfo?.appBundleIdentifier ?? "",
                                "appName": app.appInfo?.appName ?? "",
                            ]
                        }
                        let summary: [String: Any] = [
                            "usableAppCount": usable.count,
                            "rawAppCount": apps.count,
                            "appNames": usable.compactMap { $0.appInfo?.appName },
                            "bundleIds": usable.compactMap { $0.appInfo?.appBundleIdentifier },
                            "channels": channels,
                            "channelCount": LKConnectionManager.sharedInstance.mcpLastConnectSnapshot?.channelCount ?? 0,
                            "timestamp": Date().timeIntervalSince1970,
                        ]
                        LKMCPClientDiagnostics.shared.recordDiscoverSummary(summary)
                        return apps
                    }
            }
    }

    private static func inspectableApp(
        from pair: LookinPair,
        validAppInfos: [LookinAppInfo],
        channel: LKPeerChannel
    ) -> LKInspectableApp? {
        guard let response = pair.first as? LookinConnectionResponseAttachment,
              let relatedChannel = pair.second as? LKPeerChannel else {
            NSLog(
                "LookinClient - App discovery unexpected zip item: %@",
                String(describing: type(of: pair.first as Any))
            )
            return nil
        }
        if let wireError = response.error {
            NSLog(
                "LookinClient - App request wire error: %@",
                wireError.localizedDescription
            )
            return nil
        }
        guard let receivedInfo = response.data as? LookinAppInfo else {
            NSLog(
                "LookinClient - App request unexpected data type: %@",
                String(describing: type(of: response.data as Any))
            )
            return nil
        }
        var infoToUse = receivedInfo
        receivedInfo.cachedTimestamp = Date().timeIntervalSince1970
        if receivedInfo.shouldUseCache,
           let localInfo = validAppInfos.first(where: {
               // Cache-only responses only carry appInfoIdentifier (deviceType defaults to .others).
               // Match by identifier alone so simulator apps (deviceType=.simulator) are found.
               $0.appInfoIdentifier == receivedInfo.appInfoIdentifier
           }) {
            infoToUse = localInfo
        }

        let app = LKInspectableApp()
        app.appInfo = infoToUse
        app.channel = relatedChannel
        return app
    }

    private func tryToConnectAllPorts() -> Single<[LKPeerChannel]> {
        LKConnectionManager.sharedInstance.tryToConnectAllPorts()
    }

    private func setupAutoReconnect() {
        LKConnectionManager.sharedInstance.channelWillEnd
            .subscribe(with: self) { owner, channel in
                if owner.intentionalSessionChange { return }
                // Guard against spurious triggers during manual app switching.
                if owner.switchStatusRelay.value.isConnecting { return }
                guard channel === owner.inspectingApp?.channel else { return }

                NSLog("LookinClient - connection dropped, starting auto-reconnect")

                let targetSession = owner.inspectingApp
                owner.inspectingApp = nil
                owner.startAutoReconnectLoop(for: targetSession)
            }
            .disposed(by: disposeBag)
    }

    private func startAutoReconnectLoop(for session: LKInspectableApp?) {
        autoReconnectDisposeBag = DisposeBag()

        // Stop signal: fires when the user initiates a new manual connection.
        let stopSignal: Observable<Void> = willConnectToAppRelay.map { _ in () }

        let onReconnected: (LKInspectableApp) -> Void = { [weak self] newApp in
            guard let self else { return }
            NSLog("LookinClient - auto-reconnect succeeded")
            self.inspectingApp = newApp
            self.didAutoReconnectSuccRelay.accept(())
        }

        // Fast path: server signals Peertalk is ready — skip the 3s wait.
        // flatMap (not flatMapLatest): never cancel an in-flight fetchInspectableApp since
        // fetchAppInfos holds a lock; cancelling before innerDisposable is assigned leaves
        // the lock permanently held, blocking all subsequent fetchAppInfos calls.
        LKConnectionManager.sharedInstance.didReceivePush
            .filter { ($0.second as? NSNumber)?.uint32Value == LookinWirePushTypes.serverReady }
            .take(until: stopSignal)
            .flatMap { [weak self] _ -> Observable<LKInspectableApp> in
                guard let self else { return .empty() }
                return self.fetchInspectableApp(matching: session)
                    .asObservable()
                    .catch { _ in .empty() }
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: onReconnected)
            .disposed(by: autoReconnectDisposeBag)

        // Polling path: retry every 3s, bounded to maxAttempts to avoid infinite limbo.
        Observable<Int>.interval(Self.autoReconnectIntervalSec, scheduler: MainScheduler.instance)
            .take(Self.autoReconnectMaxAttempts)
            .take(until: stopSignal)
            .flatMap { [weak self] _ -> Observable<LKInspectableApp> in
                guard let self else { return .empty() }
                return self.fetchInspectableApp(matching: session)
                    .asObservable()
                    .catch { _ in .empty() }
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: onReconnected)
            .disposed(by: autoReconnectDisposeBag)
    }

    private func fetchInspectableApp(matching session: LKInspectableApp?) -> Single<LKInspectableApp> {
        guard let session, let appInfo = session.appInfo else {
            return .error(LKLookinClientErrors.inner)
        }
        let wasUSB = Self.inspectSessionUsesUSB(session)
        return fetchAppInfos(withImage: false, localInfos: [appInfo], usbOnly: wasUSB)
            .flatMap { allApps -> Single<LKInspectableApp> in
                let conn = LKConnectionManager.sharedInstance
                guard let targetApp = allApps.first(where: { candidate in
                    guard appInfo.isEqual(toAppInfo: candidate.appInfo) else { return false }
                    return conn.channelUsesUSB(candidate.channel) == wasUSB
                }) ?? self.pickInspectableAppForReload(current: session, from: allApps, wantsUSB: wasUSB) else {
                    return .error(LKLookinClientErrors.inner)
                }
                targetApp.appInfo?.appIcon = appInfo.appIcon
                return .just(targetApp)
            }
    }
}
