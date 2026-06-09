//
//  LookinCustomDisplayItemInfo+LookinClient.swift
//  LookinClient
//
//  Created by likai.123 on 2023/11/1.
//  Copyright © 2023 hughkli. All rights reserved.
//

import AppKit
import Foundation
import LookinShared

extension LookinCustomDisplayItemInfo {
    func hasValidFrame() -> Bool {
        guard let frameInWindow else { return false }
        return LKHelper.validateFrame(frameInWindow)
    }
}
