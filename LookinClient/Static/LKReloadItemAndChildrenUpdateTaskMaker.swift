//
//  LKReloadItemAndChildrenUpdateTaskMaker.swift
//  LookinClient
//
//  Created by likai.123 on 2024/3/3.
//  Copyright © 2024 hughkli. All rights reserved.
//

import AppKit
import Foundation
import LookinShared

final class LKReloadItemAndChildrenUpdateTaskMaker: NSObject {
    static func make(with item: LookinDisplayItem?) -> [LookinStaticAsyncUpdateTask]? {
        guard let item, !LKStaticAsyncUpdateManager.sharedInstance.isUpdating else {
            assertionFailure()
            return nil
        }
        let serverVersion = LKAppsManager.sharedInstance.inspectingApp?.appInfo?.serverReadableVersion
        let supported = LKVersionComparer.compare(
            withExpectedVersion: "1.2.7",
            realVersion: serverVersion ?? ""
        )
        if !supported {
            let title = NSLocalizedString("Operation failed.", comment: "")
            let detail = NSLocalizedString(
                "Please upgrade the LookinServer SDK version in your iOS project to 1.2.7 or higher.",
                comment: ""
            )
            let error = LookinErrorMake(title, detail)
            if let window = NSApplication.shared.keyWindow {
                NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
            }
            return nil
        }

        let task = LookinStaticAsyncUpdateTask()
        guard let layerObject = item.layerObject else { return nil }
        task.oid = layerObject.oid
        task.taskType = .noScreenshot
        task.attrRequest = .notNeed
        task.needBasisVisualInfo = true
        task.needSubitems = true
        task.frameSize = item.frame.size
        task.clientReadableVersion = LKHelper.lookinReadableVersion()
        return [task]
    }
}
