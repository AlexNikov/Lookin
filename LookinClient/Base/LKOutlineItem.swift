//
//  LKOutlineItem.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/28.
//  https://lookin.work
//

import AppKit
import Foundation

enum LKOutlineItemStatus: UInt {
    case notExpandable
    case expanded
    case collapsed
}

class LKOutlineItem: NSObject {
    var subItems: [LKOutlineItem]? {
        didSet {
            if subItems != nil {
                status = .collapsed
            } else {
                status = .notExpandable
            }
        }
    }

    var status: LKOutlineItemStatus = .notExpandable
    var titleText: String?
    var image: NSImage?
    private(set) var indentation: UInt = 0

    func flatItems() -> [LKOutlineItem] {
        var array: [LKOutlineItem] = [self]
        if status == .expanded {
            for obj in subItems ?? [] {
                obj.indentation = indentation + 1
                array.append(contentsOf: obj.flatItems())
            }
        }
        return array
    }

    class func flatItems(fromRootItems items: [LKOutlineItem]) -> [LKOutlineItem] {
        items.flatMap { $0.flatItems() }
    }
}
