//
//  LKWireClientRequestTimeout.swift
//  Lookin
//
//  Named Peertalk request timeouts — values match legacy magic numbers.
//

import Foundation
import LookinShared

enum LKWireClientRequestTimeout {
    // Heavy iOS main-thread work
    static let hierarchyDetails: TimeInterval = 45
    static let hierarchy: TimeInterval = 30
    static let appInfo: TimeInterval = 20
    static let allAttrGroups: TimeInterval = 15
    static let inbuiltAttrModification: TimeInterval = 12
    static let `default`: TimeInterval = 5

    static let preflightPing: TimeInterval = 2
    static let preflightPingBeforeApp: TimeInterval = 3

    static func interval(forRequestType requestType: UInt32) -> TimeInterval {
        switch requestType {
        case UInt32(LookinRequestTypeHierarchyDetails): return hierarchyDetails
        case UInt32(LookinRequestTypeHierarchy): return hierarchy
        case UInt32(LookinRequestTypeInbuiltAttrModification): return inbuiltAttrModification
        case UInt32(LookinRequestTypeApp): return appInfo
        case UInt32(LookinRequestTypeAllAttrGroups): return allAttrGroups
        default: return `default`
        }
    }

    static func pingInterval(beforeRequestType requestType: UInt32) -> TimeInterval {
        requestType == UInt32(LookinRequestTypeApp) ? preflightPingBeforeApp : preflightPing
    }
}
