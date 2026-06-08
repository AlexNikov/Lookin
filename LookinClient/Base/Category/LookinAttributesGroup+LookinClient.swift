//
//  LookinAttributesGroup+LookinClient.swift
//  LookinClient
//
//  Created by LikaiMacStudioWork on 2023/10/31.
//  Copyright © 2023 hughkli. All rights reserved.
//

import Foundation
import LookinShared

extension LookinAttributesGroup {
    func queryDisplayTitle() -> String {
        if let userCustomTitle, userCustomTitle.count > 0 {
            return userCustomTitle
        }
        return LookinDashboardBlueprint.groupTitle(withGroupID: identifier ?? "")
    }
}
