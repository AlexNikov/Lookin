import AppKit
import Foundation

/// Bridges Swift `LookinMacMCPDataSource` to ObjC `LKOsAppMCPDataSource` for the legacy HTTP handler.
@objc(LKOsAppMCPDataSourceSwiftBridge)
@objcMembers
final class LKOsAppMCPDataSourceSwiftBridge: NSObject, LKOsAppMCPDataSource {
    private weak var swift: LookinMacMCPDataSource?

    init(swift dataSource: LookinMacMCPDataSource) {
        swift = dataSource
        super.init()
    }

    func mcp_currentHierarchyInfo() -> NSObject? {
        swift?.mcpCurrentHierarchyInfo()
    }

    func mcp_currentAppInfo() -> NSObject? {
        swift?.mcpCurrentAppInfo()
    }

    func mcp_inspectorUIState() -> [AnyHashable: Any] {
        (swift?.mcpInspectorUIState() as? [AnyHashable: Any]) ?? [:]
    }

    func mcp_openInspectorForAutomation() {
        swift?.mcpOpenInspectorForAutomation()
    }

    func mcp_openAppSwitcherPopover() {
        swift?.mcpOpenAppSwitcherPopover()
    }

    func mcp_fetchAndOpenAppSwitcher(withTimeout timeout: TimeInterval) -> [AnyHashable: Any] {
        (swift?.mcpFetchAndOpenAppSwitcher(timeout: timeout) as? [AnyHashable: Any]) ?? [:]
    }

    func mcp_clientState() -> [AnyHashable: Any]? {
        swift?.mcpClientState() as? [AnyHashable: Any]
    }

    func mcp_eventLog() -> [Any]? {
        swift?.mcpEventLog()
    }

    func mcp_clearEventLog() {
        swift?.mcpClearEventLog()
    }

    func mcp_connectionDiagnostics() -> [AnyHashable: Any] {
        (swift?.mcpConnectionDiagnostics() as? [AnyHashable: Any]) ?? [:]
    }

    func mcp_diagLogLines(withLimit limit: Int) -> [String] {
        swift?.mcpDiagLogLines(limit: limit) ?? []
    }

    func mcp_clearDiagLog() {
        swift?.mcpClearDiagLog()
    }

    func mcp_discoverAppsSync(withTimeout timeout: TimeInterval) -> [AnyHashable: Any] {
        (swift?.mcpDiscoverAppsSync(timeout: timeout) as? [AnyHashable: Any]) ?? [:]
    }

    func mcp_endInspectSession() {
        swift?.mcpEndInspectSession()
    }

    func mcp_simulatorPeertalkPortProbe() -> [AnyHashable: Any] {
        (swift?.mcpSimulatorPeertalkPortProbe() as? [AnyHashable: Any]) ?? [:]
    }

    func mcp_wireV2PingSync(withTimeout timeout: TimeInterval) -> [AnyHashable: Any] {
        (swift?.mcpWireV2PingSync(timeout: timeout) as? [AnyHashable: Any]) ?? [:]
    }

    func mcp_reloadHierarchy() {
        swift?.mcpReloadHierarchy()
    }

    func mcp_selectHierarchyRowMacView(_ view: NSView) -> Bool {
        swift?.mcpSelectHierarchyRowMacView(view) ?? false
    }

    func mcp_iosPreviewState() -> [AnyHashable: Any]? {
        swift?.mcpIosPreviewState() as? [AnyHashable: Any]
    }

    func mcp_iosPreviewScreenshotPNG() -> Data? {
        swift?.mcpIosPreviewScreenshotPNG()
    }

    func mcp_iosPreviewLighting() -> [AnyHashable: Any]? {
        swift?.mcpIosPreviewLighting() as? [AnyHashable: Any]
    }

    func mcp_iosPreviewSceneGraph() -> [AnyHashable: Any]? {
        swift?.mcpIosPreviewSceneGraph() as? [AnyHashable: Any]
    }

    func mcp_iosPreviewTextureSources() -> [AnyHashable: Any]? {
        swift?.mcpIosPreviewTextureSources() as? [AnyHashable: Any]
    }

    func mcp_exportPreviewLayerScreenshots(to directory: String) -> [AnyHashable: Any]? {
        swift?.mcpExportPreviewLayerScreenshots(to: directory) as? [AnyHashable: Any]
    }

    func mcp_inspectorParitySnapshot() -> [AnyHashable: Any]? {
        swift?.mcpInspectorParitySnapshot() as? [AnyHashable: Any]
    }

    func mcp_launchInspectTargets() -> [NSDictionary] {
        let targets = swift?.mcpLaunchInspectTargets() ?? []
        return targets.map { $0 as NSDictionary }
    }

    func mcp_selectInspectTarget(
        withChannel channel: String?,
        accessibilityIdentifier: String?,
        index: Int,
        timeout: TimeInterval
    ) -> [AnyHashable: Any] {
        (swift?.mcpSelectInspectTarget(
            channel: channel,
            accessibilityIdentifier: accessibilityIdentifier,
            index: index,
            timeout: timeout
        ) as? [AnyHashable: Any]) ?? [:]
    }

    func mcp_refreshLaunchTargets(withTimeout timeout: TimeInterval) -> [AnyHashable: Any] {
        (swift?.mcpRefreshLaunchTargets(timeout: timeout) as? [AnyHashable: Any]) ?? [:]
    }

    func mcp_launchHealth() -> [AnyHashable: Any] {
        (swift?.mcpLaunchHealth() as? [AnyHashable: Any]) ?? [:]
    }
}
