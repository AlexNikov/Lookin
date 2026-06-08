//
//  LKDemoBundleID.swift
//  Lookin
//
//  Known Lookin iOS demo bundles for MCP auto-select and launch auto-enter.
//  Keep in sync with Lookin/Scripts/lookin_demo_bundle_ids.env (sourced by verify scripts).
//

import Foundation

enum LKDemoBundleID: String, CaseIterable {
    case mcpSample = "Lookin.LookinMCPSample"
    case customInfoSwift = "Lookin.LookinCustomInfoDemoSwift"
    case customInfoLegacy = "Lookin.LookinCustomInfoDemo"
    case collectionLayoutSwift = "Lookin.LookinCollectionLayoutDemo"
    case collectionLayoutObjC = "Lookin.LookinCollectionLayoutDemoObjC"

    static let preferredOrder: [LKDemoBundleID] = [
        .mcpSample, .customInfoSwift, .customInfoLegacy,
        .collectionLayoutSwift, .collectionLayoutObjC,
    ]

    static func matches(_ bundleId: String?) -> Bool {
        guard let bundleId else { return false }
        return Self(rawValue: bundleId) != nil
    }

    /// First demo app in preferred order from discovered list.
    static func firstMatch(in apps: [LKInspectableApp]) -> LKInspectableApp? {
        for id in preferredOrder {
            if let app = apps.first(where: { $0.appInfo?.appBundleIdentifier == id.rawValue }) {
                return app
            }
        }
        return nil
    }
}
