//
//  AppDelegate+LookinMacMCP.swift
//  Lookin
//
//  MCP HTTP server (:47192) data source for verify scripts and automation.
//

import AppKit
import LookinMacMCP
import LookinShared

// MARK: - MCP (LookinMacMCPDataSource)

extension AppDelegate: LookinMacMCPDataSource {
    func mcpCurrentHierarchyInfo() -> NSObject? {
        LKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo
    }

    func mcpCurrentAppInfo() -> NSObject? {
        LKStaticHierarchyDataSource.sharedInstance.appInfo
    }

    func mcpInspectorUIState() -> [String: Any] {
        var state: [String: Any] = ["uiMode": Self.lookinMCPUIMode()]
        let ds = LKStaticHierarchyDataSource.sharedInstance
        if let item = ds.selectedItem {
            state["selectedTitle"] = item.title() ?? ""
            state["selectedSubtitle"] = item.subtitle() ?? ""
            let oid = item.viewObject?.oid ?? item.layerObject?.oid ?? 0
            state["selectedOid"] = NSNumber(value: oid)
        }
        return state
    }

    func mcpOpenInspectorForAutomation() {
        DispatchQueue.main.async {
            let nav = LKNavigationManager.sharedInstance
            if nav.staticWindowController?.window?.isVisible == true {
                if LKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo != nil {
                    nav.staticWindowController?.mcpForceReload()
                    return
                }
                // Empty inspector (MCP reconnect) — return to launch and enter a live app.
                LKAppsManager.sharedInstance.endInspectingSession()
                nav.showLaunch()
            }
            if LKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo != nil {
                nav.showStaticWorkspace()
                nav.closeLaunch()
                return
            }
            if nav.launchWindowController == nil {
                nav.showLaunch()
            }
            NSApp.activate(ignoringOtherApps: true)
            nav.launchWindowController?.launchViewController?.lookin_mcpTryEnterInspector()
        }
    }

    func mcpOpenAppSwitcherPopover() {
        DispatchQueue.main.async {
            LKNavigationManager.sharedInstance.staticWindowController?
                .popupAllInspectableApps(with: .appButton)
        }
    }

    func mcpFetchAndOpenAppSwitcher(timeout: TimeInterval) -> [String: Any] {
        LKMCPAppSwitcher.fetchAndOpen(timeout: timeout)
    }

    func mcpClientState() -> [String: Any]? {
        let ds = LKStaticHierarchyDataSource.sharedInstance
        guard let flatItems = ds.flatItems else { return nil }
        let items: [[String: Any]] = flatItems.map { item in
            var fields = LKMCPInspectorParity.itemFields(item)
            fields["isExpanded"] = item.isExpanded
            fields["computedExpandable"] = item.subitems?.isEmpty == false
            fields["subitemsCount"] = item.subitems?.count ?? -1
            fields["superItemNil"] = item.superItem == nil
            return fields
        }
        var result: [String: Any] = [
            "flatItemsCount": flatItems.count,
            "displayingFlatItemsCount": ds.displayingFlatItems?.count ?? 0,
            "items": items,
        ]
        if let sel = ds.selectedItem {
            result["selectedOid"] = NSNumber(value: sel.viewObject?.oid ?? sel.layerObject?.oid ?? 0)
        }
        if let pv = LKPreviewView.sharedForMCP {
            result["preview"] = pv.mcpDebugInfo()
        }
        let nav = LKNavigationManager.sharedInstance
        let sc = nav.staticWindowController
        result["isFetchingDetails"] = sc?.mcpFetchingDetails ?? false
        result["isFetchingHierarchy"] = sc?.mcpFetchingHierarchy ?? false
        result["uiMode"] = Self.lookinMCPUIMode()
        return result
    }

    func mcpEventLog() -> [Any]? {
        LKDebugEventLog.shared.allEvents
    }

    func mcpClearEventLog() {
        LKDebugEventLog.shared.clear()
    }

    func mcpConnectionDiagnostics() -> [String: Any] {
        LKMCPClientDiagnostics.shared.connectionStateDictionary() as? [String: Any] ?? [:]
    }

    func mcpDiagLogLines(limit: Int) -> [String] {
        LKMCPClientDiagnostics.shared.diagLogLines(limit: limit)
    }

    func mcpClearDiagLog() {
        LKMCPClientDiagnostics.shared.clearDiagLog()
    }

    func mcpDiscoverAppsSync(timeout: TimeInterval) -> [String: Any] {
        LKMCPClientDiagnostics.shared.discoverAppsSync(timeout: timeout) as? [String: Any] ?? [:]
    }

    func mcpEndInspectSession() {
        LKAppsManager.sharedInstance.endInspectingSession()
        LKNavigationManager.sharedInstance.showLaunch()
        LookinDiagLog.log("client MCP end-inspect-session")
    }

    func mcpSimulatorPeertalkPortProbe() -> [String: Any] {
        LKMCPClientDiagnostics.shared.simulatorPeertalkPortProbe() as? [String: Any] ?? [:]
    }

    func mcpWireV2PingSync(timeout: TimeInterval) -> [String: Any] {
        mcpOnMain {
            LKMCPClientDiagnostics.shared.wireV2PingSync(timeout: timeout) as? [String: Any] ?? [:]
        }
    }

    func mcpReloadHierarchy() {
        LKNavigationManager.sharedInstance.staticWindowController?.mcpForceReload()
    }

    func mcpToggleFastMode() -> Bool {
        mcpOnMain {
            let manager = LKPreferenceMain()
            manager.fastMode = !manager.fastMode
            LKConnectionTiming.shared.recordInstant(
                "fastMode.toggle",
                durationMs: 0,
                attrs: ["enabled": manager.fastMode, "source": "mcp"]
            )
            return manager.fastMode
        }
    }

    func mcpSelectHierarchyRowMacView(_ view: NSView) -> Bool {
        var candidate: NSView? = view
        while let current = candidate {
            if let row = current as? LKHierarchyRowView, let item = row.displayItem {
                LKStaticHierarchyDataSource.sharedInstance.selectedItem = item
                return true
            }
            candidate = current.superview
        }
        return false
    }

    func mcpIosPreviewState() -> [String: Any]? {
        mcpOnMain { LKPreviewView.sharedForMCP?.mcpPreviewStateDictionary() as? [String: Any] }
    }

    func mcpIosPreviewScreenshotPNG() -> Data? {
        mcpOnMain { LKPreviewView.sharedForMCP?.mcpSnapshotPNGData() }
    }

    func mcpIosPreviewLighting() -> [String: Any]? {
        mcpOnMain { LKPreviewView.sharedForMCP?.mcpLightingInfo() as? [String: Any] }
    }

    func mcpIosPreviewSceneGraph() -> [String: Any]? {
        mcpOnMain { LKPreviewView.sharedForMCP?.mcpSceneGraphDump() as? [String: Any] }
    }

    func mcpIosPreviewTextureSources() -> [String: Any]? {
        mcpOnMain { LKPreviewView.sharedForMCP?.mcpTextureSourcesInfo() as? [String: Any] }
    }

    func mcpExportPreviewLayerScreenshots(to directory: String) -> [String: Any]? {
        mcpOnMain { LKPreviewView.sharedForMCP?.mcpExportLayerScreenshots(toDirectory: directory) }
    }

    func mcpInspectorParitySnapshot() -> [String: Any]? {
        mcpOnMain {
            let nav = LKNavigationManager.sharedInstance
            guard nav.staticWindowController?.window?.isVisible == true,
                  let staticVC = nav.staticWindowController?.viewController else {
                return nil
            }
            return staticVC.mcpInspectorParitySnapshot(uiMode: Self.lookinMCPUIMode())
        }
    }

    func mcpLaunchInspectTargets() -> [[String: Any]] {
        LKMCPInspectTarget.launchTargets()
    }

    func mcpSelectInspectTarget(
        channel: String?,
        accessibilityIdentifier: String?,
        index: Int,
        timeout: TimeInterval
    ) -> [String: Any] {
        let resolvedIndex: Int? = index == Int(NSNotFound) ? nil : (index >= 0 ? index : nil)
        return LKMCPInspectTarget.selectInspectTarget(
            channel: channel,
            accessibilityIdentifier: accessibilityIdentifier,
            index: resolvedIndex,
            timeout: timeout
        )
    }

    func mcpRefreshLaunchTargets(timeout: TimeInterval) -> [String: Any] {
        LKMCPInspectTarget.refreshLaunchTargets(timeout: timeout)
    }

    func mcpLaunchHealth() -> [String: Any] {
        LKMCPLaunchHealth.snapshot()
    }

    private func mcpOnMain<T>(_ work: () -> T) -> T {
        if Thread.isMainThread {
            return work()
        }
        return DispatchQueue.main.sync(execute: work)
    }

    private static func lookinMCPUIMode() -> String {
        let nav = LKNavigationManager.sharedInstance
        if nav.staticWindowController?.window?.isVisible == true {
            return "inspector"
        }
        if nav.launchWindowController?.window?.isVisible == true {
            return "launch"
        }
        return "unknown"
    }
}
