//
//  LKMessageManager.swift
//  LookinClient
//
//  Created by likai.123 on 2023/10/30.
//  Copyright © 2023 hughkli. All rights reserved.
//

import Foundation
import LookinShared

class LKMessageConstants: NSObject {
    static let jobs = "LKMessage_Jobs"
    static let newServerVersion = "LKMessage_NewServerVersion"
    static let swiftSubspec = "LKMessage_SwiftSubspec"
}

let LKMessage_Jobs = LKMessageConstants.jobs
let LKMessage_NewServerVersion = LKMessageConstants.newServerVersion
let LKMessage_SwiftSubspec = LKMessageConstants.swiftSubspec

final class LKMessageManager: NSObject {
    static let sharedInstance = LKMessageManager()

    private var messages = Set<String>()

    private override init() {
        super.init()
    }

    func addMessage(_ message: String) {
        messages.insert(message)
    }

    func removeMessage(_ message: String) {
        messages.remove(message)
        if message == LKMessage_Jobs {
            UserDefaults.standard.set(true, forKey: "LKMessageManager_HasReadJobs")
        }
    }

    func queryMessages() -> [String] {
        messages.sorted { $0.count > $1.count }
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: "LKMessageManager_HasReadJobs")
    }
}
