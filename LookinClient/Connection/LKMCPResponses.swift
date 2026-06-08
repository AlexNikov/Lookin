//
//  LKMCPResponses.swift
//  Lookin
//
//  Typed MCP select-inspect / launch-tile payloads → NSDictionary contract.
//

import Foundation
import LookinShared

struct LKMCPSelectInspectSuccess {
    let freshApp: LKInspectableApp
    let previousMode: LKMCPUIMode
    let keepState: Bool
}

struct LKMCPSelectInspectResult {
    let ok: Bool
    var error: LKMCPInspectError?
    var errorMessage: String?
    var errorCode: Int?
    var uiMode: LKMCPUIMode
    var previousUiMode: LKMCPUIMode?
    var channel: LKMCPChannelTag
    var channelTargetPort: Int?
    var bundleId: String?
    var appName: String?
    var deviceDescription: String?
    var keepState: Bool?
    var hasHierarchy: Bool?
    var launchTargets: [LKMCPLaunchTile]?

    static func success(_ s: LKMCPSelectInspectSuccess) -> Self {
        let app = s.freshApp
        return LKMCPSelectInspectResult(
            ok: true,
            uiMode: .inspector,
            previousUiMode: s.previousMode,
            channel: LKAppsManager.mcpChannelTag(for: app),
            channelTargetPort: app.channel?.targetPort ?? 0,
            bundleId: app.appInfo?.appBundleIdentifier ?? "",
            appName: app.appInfo?.appName ?? "",
            deviceDescription: app.appInfo?.deviceDescription ?? "",
            keepState: s.keepState,
            hasHierarchy: LKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo != nil
        )
    }

    static func noMatchingTarget(launchTargets tiles: [LKMCPLaunchTile]) -> Self {
        LKMCPSelectInspectResult(
            ok: false,
            error: .noMatchingTarget,
            uiMode: LKNavigationManager.sharedInstance.mcpUIMode,
            channel: .unknown,
            launchTargets: tiles
        )
    }

    static func timeout(channel: LKMCPChannelTag) -> Self {
        LKMCPSelectInspectResult(
            ok: false,
            error: .selectTimeout,
            uiMode: LKNavigationManager.sharedInstance.mcpUIMode,
            channel: channel
        )
    }

    static func failure(
        message: String,
        code: Int,
        channel: LKMCPChannelTag
    ) -> Self {
        LKMCPSelectInspectResult(
            ok: false,
            errorMessage: message,
            errorCode: code,
            uiMode: LKNavigationManager.sharedInstance.mcpUIMode,
            channel: channel
        )
    }

    func dictionaryRepresentation() -> [String: Any] {
        var dict: [String: Any] = [
            "ok": ok,
            "uiMode": uiMode.rawValue,
            "channel": channel.rawValue,
        ]
        if let error { dict["error"] = error.rawValue }
        if let errorMessage { dict["error"] = errorMessage }
        if let errorCode { dict["errorCode"] = errorCode }
        if let previousUiMode { dict["previousUiMode"] = previousUiMode.rawValue }
        if ok {
            dict["channelTargetPort"] = channelTargetPort ?? 0
            dict["bundleId"] = bundleId ?? ""
            dict["appName"] = appName ?? ""
            dict["deviceDescription"] = deviceDescription ?? ""
            dict["keepState"] = keepState ?? false
            dict["hasHierarchy"] = hasHierarchy ?? false
        }
        if let launchTargets {
            dict["launchTargets"] = launchTargets.map { $0.dictionaryRepresentation() }
        }
        return dict
    }
}

struct LKMCPLaunchTile {
    let index: Int
    let channel: LKMCPChannelTag
    let oid: UInt
    let accessibilityIdentifier: String
    let bundleId: String?
    let appName: String?
    let deviceDescription: String?
    let osDescription: String?
    let deviceType: Int?
    let label: String?

    func dictionaryRepresentation() -> [String: Any] {
        var dict: [String: Any] = [
            "index": index,
            "channel": channel.rawValue,
            "oid": oid,
            "accessibilityIdentifier": accessibilityIdentifier,
            "action": "openInspector",
            "effect": channel == .usb
                ? "Open inspector for USB-connected iOS app"
                : "Open inspector for Simulator iOS app",
        ]
        dict["bundleId"] = bundleId ?? ""
        dict["appName"] = appName ?? ""
        dict["deviceDescription"] = deviceDescription ?? ""
        if let osDescription { dict["osDescription"] = osDescription }
        if let deviceType { dict["deviceType"] = deviceType }
        if let label { dict["label"] = label }
        return dict
    }

    static func from(view: LKLaunchAppView, index: Int, channel: LKMCPChannelTag) -> Self {
        let info = view.app?.appInfo
        return LKMCPLaunchTile(
            index: index,
            channel: channel,
            oid: UInt(bitPattern: ObjectIdentifier(view)),
            accessibilityIdentifier: view.accessibilityIdentifier(),
            bundleId: info?.appBundleIdentifier,
            appName: info?.appName,
            deviceDescription: info?.deviceDescription,
            osDescription: info?.osDescription,
            deviceType: info.map { Int($0.deviceType.rawValue) },
            label: view.accessibilityLabel()
        )
    }
}
