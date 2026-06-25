#import <Foundation/Foundation.h>

@class NSView;

NS_ASSUME_NONNULL_BEGIN

@protocol LKOsAppMCPDataSource <NSObject>
- (nullable NSObject *)mcp_currentHierarchyInfo;
- (nullable NSObject *)mcp_currentAppInfo;
/// Launch vs inspector selection state for MCP automation (Lookin client implements).
- (NSDictionary *)mcp_inspectorUIState;
/// Open the inspector UI (launch → static workspace). Safe to call when already in inspector.
- (void)mcp_openInspectorForAutomation;
/// Toolbar App button — open sim/USB switcher popover.
- (void)mcp_openAppSwitcherPopover;
@optional
/// Client-side hierarchy state: expansion flags, displaying counts, preview node counts.
- (nullable NSDictionary *)mcp_clientState;
/// All recorded debug events as an array of dictionaries.
- (nullable NSArray *)mcp_eventLog;
/// Clear the event log.
- (void)mcp_clearEventLog;
/// Trigger a hierarchy reload from the connected iOS app (equivalent to pressing the Reload toolbar button).
- (void)mcp_reloadHierarchy;
/// Toggle fast mode toolbar state. Returns new enabled value.
- (BOOL)mcp_toggleFastMode;
/// Select the iOS display item for a mac hierarchy row view (or its subview). Returns NO if not a hierarchy row.
- (BOOL)mcp_selectHierarchyRowMacView:(NSView *)view;
/// iOS 3D preview state for ObjC vs Swift parity (planes, camera, dimension).
- (nullable NSDictionary *)mcp_iosPreviewState;
/// PNG bytes of fixed-size SCNView snapshot (640×480).
- (nullable NSData *)mcp_iosPreviewScreenshotPNG;
/// Write per-layer preview PNGs + structure.json into `directory` (NSString path).
- (nullable NSDictionary *)mcp_exportPreviewLayerScreenshotsToDirectory:(NSString *)directory;
/// Lighting nodes of the SCNScene (type, position, category bit mask, sharedLightWith).
/// For ObjC↔Swift parity of light setup in `LKPreviewView`.
- (nullable NSDictionary *)mcp_iosPreviewLighting;
/// Full SCNNode tree dump under the scene root (name, class, position, opacity, hidden, geometry).
/// For diagnosing `pruneOrphanPreviewNodes` / `discardCache` divergence vs ObjC baseline.
- (nullable NSDictionary *)mcp_iosPreviewSceneGraph;
/// Per-display-item A/B of `appropriateScreenshot()` (ObjC behavior) vs `imageForPreviewPlane()`
/// (Swift behavior) — pixel size, hash, and which one is currently bound to the contentPlane.
/// Lets verify-scripts spot the parent-texture-suppression divergence without launching baseline.
- (nullable NSDictionary *)mcp_iosPreviewTextureSources;

#pragma mark - Client diagnostics (Peertalk / launch / LookinDiag)

/// Peertalk cache, last connect/discover, uiMode, inspectingApp (NSDictionary).
- (NSDictionary *)mcp_connectionDiagnostics;
/// Recent `LookinDiag - …` lines (newest last), up to `limit`.
- (NSArray<NSString *> *)mcp_diagLogLinesWithLimit:(NSInteger)limit;
- (void)mcp_clearDiagLog;
/// Run `fetchAppInfos` on main; blocks up to `timeout` seconds (call from background queue).
- (NSDictionary *)mcp_discoverAppsSyncWithTimeout:(NSTimeInterval)timeout;
/// Leave inspector, release Peertalk channels (verify / reconnect).
- (void)mcp_endInspectSession;
/// Host TCP probe 127.0.0.1:47164–47169 (simulator port forwarding).
- (NSDictionary *)mcp_simulatorPeertalkPortProbe;
/// Wire v2 Ping on active `inspectingApp.channel`.
- (NSDictionary *)mcp_wireV2PingSyncWithTimeout:(NSTimeInterval)timeout;
/// Hierarchy tree + mac row selection + preview background + dashboard attributes (Swift client).
- (nullable NSDictionary *)mcp_inspectorParitySnapshot;
/// Launch screen / app-switcher tiles (`channel`: `sim` | `usb`).
- (NSArray<NSDictionary *> *)mcp_launchInspectTargets;
/// Enter inspector from launch or switch sim ↔ USB (`channel`, `accessibilityIdentifier`, or `index`).
- (NSDictionary *)mcp_selectInspectTargetWithChannel:(nullable NSString *)channel
                             accessibilityIdentifier:(nullable NSString *)accessibilityIdentifier
                                               index:(NSInteger)index
                                             timeout:(NSTimeInterval)timeout;
/// Reload launch screen and wait for sim/USB tiles.
- (NSDictionary *)mcp_refreshLaunchTargetsWithTimeout:(NSTimeInterval)timeout;
/// Launch screen freeze / stall detection.
- (NSDictionary *)mcp_launchHealth;
/// Discover apps (no images, fast), open app-switcher popover, return tiles. Blocks until done.
- (NSDictionary *)mcp_fetchAndOpenAppSwitcherWithTimeout:(NSTimeInterval)timeout;
@end

NS_ASSUME_NONNULL_END
