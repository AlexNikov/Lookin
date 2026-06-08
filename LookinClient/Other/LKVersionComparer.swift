//
//  LKVersionComparer.swift
//  LookinClient
//
//  Created by likai.123 on 2023/10/30.
//  Copyright © 2023 hughkli. All rights reserved.
//

import Foundation
import LookinShared

class LKVersionComparer: NSObject {
    static func compare(withNewest latest: String, user: String) -> Bool {
        compare(withExpectedVersion: latest, realVersion: user)
    }

    static func compare(withExpectedVersion expectedVersion: String, realVersion: String) -> Bool {
        let expectedNumber = expectedVersion.lookin_numbericOSVersion()
        let realNumber = realVersion.lookin_numbericOSVersion()
        if expectedNumber == 0 || realNumber == 0 {
            assertionFailure()
            return false
        }
        return realNumber >= expectedNumber
    }
}
