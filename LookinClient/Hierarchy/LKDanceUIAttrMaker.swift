//
//  LKDanceUIAttrMaker.swift
//  LookinClient
//
//  Created by likai.123 on 2023/12/21.
//  Copyright © 2023 hughkli. All rights reserved.
//

import Foundation
import LookinShared

class LKDanceUIAttrMaker: NSObject {
    /// 给 item 的属性列表里填充上“跳转 DanceUI 文件”相关的信息
    class func makeDanceUIJumpAttribute(_ item: LookinDisplayItem, danceSource source: String) {
        guard let className = getClass(fromSource: source) else { return }

        let alreadyHas = item.attributesGroupList?.contains(where: { group in
            group.identifier == LookinAttrGroup_Class
        }) ?? false
        if alreadyHas { return }

        let attr = LookinAttribute()
        attr.identifier = LookinAttr_Class_Class_Class
        attr.attrType = .customObj
        attr.value = .customObject([[className]])

        var sec = LookinAttributesSection()
        sec.identifier = LookinAttrSec_Class_Class
        sec.attributes = [attr]

        var group = LookinAttributesGroup()
        group.identifier = LookinAttrGroup_Class
        group.attrSections = [sec]

        if let existing = item.attributesGroupList {
            item.attributesGroupList = existing + [group]
        } else {
            item.attributesGroupList = [group]
        }
    }

    private class func getClass(fromSource json: String) -> String? {
        guard let jsonData = json.data(using: .utf8) else { return nil }
        do {
            guard let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                assertionFailure()
                return nil
            }
            guard let type = dict["type"] as? String else {
                assertionFailure()
                return nil
            }
            return type
        } catch {
            assertionFailure()
            return nil
        }
    }
}
