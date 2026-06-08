//
//  LKReloadSingleItemUpdateTaskMaker.swift
//  LookinClient
//
//  Created by likai.123 on 2024/3/3.
//  Copyright © 2024 hughkli. All rights reserved.
//

import AppKit
import Foundation
import LookinShared

final class LKReloadSingleItemUpdateTaskMaker: NSObject {
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

        var tasks: [LookinStaticAsyncUpdateTask] = []
        if item.doNotFetchScreenshotReason == .permitted {
            let task = taskFromItem(item)
            task.taskType = .groupScreenshot
            tasks.append(task)
            if item.isExpandable {
                let task2 = taskFromItem(item)
                task2.taskType = .soloScreenshot
                tasks.append(task2)
            }
        } else {
            let task = taskFromItem(item)
            task.taskType = .noScreenshot
            tasks.append(task)
        }
        tasks.first?.needBasisVisualInfo = true
        return tasks
    }

    private static func taskFromItem(_ item: LookinDisplayItem) -> LookinStaticAsyncUpdateTask {
        let task = LookinStaticAsyncUpdateTask()
        task.oid = item.layerObject?.oid ?? 0
        task.frameSize = item.frame.size
        task.clientReadableVersion = LKHelper.lookinReadableVersion()
        return task
    }
}
