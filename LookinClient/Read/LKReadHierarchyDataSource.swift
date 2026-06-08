//
//  LKReadHierarchyDataSource.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//

import AppKit
import LookinShared

class LKReadHierarchyDataSource: LKHierarchyDataSource {
    private var readPreferenceManager: LKPreferenceManager!

    init(file: LookinHierarchyFile, preferenceManager: LKPreferenceManager) {
        readPreferenceManager = preferenceManager
        super.init()

        if let info = file.hierarchyInfo {
            reload(with: info, keepState: false)
        }

        let hasSolo = !(file.soloScreenshots?.isEmpty ?? true)
        let hasGroup = !(file.groupScreenshots?.isEmpty ?? true)
        if hasSolo || hasGroup {
            flatItems?.forEach { obj in
                let oid = obj.layerObject!.oid

                if let soloData = file.soloScreenshots?[NSNumber(value: oid)] {
                    obj.soloScreenshot = NSImage(data: soloData)
                }

                if let groupData = file.groupScreenshots?[NSNumber(value: oid)] {
                    obj.groupScreenshot = NSImage(data: groupData)
                }
            }
        }
    }

    override func preferenceManager() -> LKPreferenceManager {
        readPreferenceManager
    }
}
