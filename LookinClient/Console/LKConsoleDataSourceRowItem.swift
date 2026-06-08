//
//  LKConsoleDataSourceRowItem.swift
//  Lookin
//
//  Created by Li Kai on 2019/6/1.
//  https://lookin.work
//

import Foundation

enum LKConsoleDataSourceRowItemType: Int {
    case input
    case submit
    case `return`
}

class LKConsoleDataSourceRowItem: NSObject {
    var type: LKConsoleDataSourceRowItemType = .input
    var normalText: String?
    var highlightText: String?
}
