//
//  LKTableViewHorizontalScrollWidthManager.swift
//  LookinClient
//
//  Created by likaimacbookhome on 2023/12/17.
//  Copyright © 2023 hughkli. All rights reserved.
//

import Foundation

class LKTableViewHorizontalScrollWidthManager: NSObject {
    var maxRowWidth: CGFloat = 0
    var didReachNewMaxWidth: (() -> Void)?

    func rowDidLayout(withWidth width: CGFloat) {
        if width > maxRowWidth {
            maxRowWidth = width
            didReachNewMaxWidth?()
        }
    }
}
