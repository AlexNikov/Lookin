//
//  LKMCPConstants.swift
//  Lookin
//
//  Typed MCP wire strings (uiMode, channel) — JSON contract uses rawValue.
//

import Foundation

enum LKMCPUIMode: String, Codable {
    case inspector
    case launch
    case unknown
}

enum LKMCPChannelTag: String, Codable {
    case usb
    case sim
    case unknown

    init(usb: Bool) {
        self = usb ? .usb : .sim
    }

    init(rawChannel: String?) {
        guard let raw = rawChannel?.lowercased() else {
            self = .unknown
            return
        }
        self = LKMCPChannelTag(rawValue: raw) ?? .unknown
    }
}

enum LKMCPInspectError: String {
    case noMatchingTarget = "no_matching_target"
    case selectTimeout = "select_timeout"
}

extension LKNavigationManager {
    var mcpUIMode: LKMCPUIMode {
        if staticWindowController?.window?.isVisible == true { return .inspector }
        if launchWindowController?.window?.isVisible == true { return .launch }
        return .unknown
    }
}

extension LKAppsManager {
    static func mcpChannelTag(for app: LKInspectableApp?) -> LKMCPChannelTag {
        guard let app else { return .unknown }
        return LKMCPChannelTag(usb: inspectSessionUsesUSB(app))
    }
}
