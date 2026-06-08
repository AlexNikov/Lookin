//
//  LKHierarchyItem.swift
//  Lookin
//
//  Created by Li Kai on 2019/4/29.
//  https://lookin.work
//

import Foundation

enum LKHierarchyItemStatus: UInt {
    case notExpandable
    case expanded
    case collapsed
}

class LKHierarchyItem: NSObject {
    var subItems: [LKHierarchyItem]?

    private(set) weak var superItem: LKHierarchyItem?

    var status: LKHierarchyItemStatus = .notExpandable

    private(set) var indentation: UInt = 0

    func flatItems() -> [LKHierarchyItem] {
        var array: [LKHierarchyItem] = [self]

        if status == .expanded {
            subItems?.forEach { obj in
                obj.indentation = indentation + 1
                array.append(contentsOf: obj.flatItems())
            }
        }

        return array
    }

    class func flatItems(fromRootItems items: [LKHierarchyItem]) -> [LKHierarchyItem] {
        items.flatMap { $0.flatItems() }
    }
}
