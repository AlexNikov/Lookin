//
//  LKLogsManager.swift
//  Lookin
//

import Foundation
import LookinShared
import RxRelay
import RxSwift

enum LKLogLevel {
    case error
    case info
}

struct LKLogEntry {
    let timestamp: Date
    let title: String
    let detail: String?
    let level: LKLogLevel
}

extension Notification.Name {
    static let LKShowErrorNotification = Notification.Name("LKShowErrorNotification")
}

let LKShowErrorNotificationTitleKey = "title"

final class LKLogsManager {
    static let shared = LKLogsManager()
    private init() {}

    private let entriesRelay = BehaviorRelay<[LKLogEntry]>(value: [])
    private let hasUnreadErrorsRelay = BehaviorRelay<Bool>(value: false)

    var entriesObservable: Observable<[LKLogEntry]> {
        entriesRelay.asObservable()
    }

    var hasUnreadErrorsObservable: Observable<Bool> {
        hasUnreadErrorsRelay.asObservable()
    }

    var entries: [LKLogEntry] {
        entriesRelay.value
    }

    func logError(_ error: NSError) {
        guard error.code != Int(LookinErrCode_Discard) else { return }
        let detail = error.localizedRecoverySuggestion
        let entry = LKLogEntry(
            timestamp: Date(),
            title: error.localizedDescription,
            detail: (detail?.isEmpty == false) ? detail : nil,
            level: .error
        )
        entriesRelay.accept(entriesRelay.value + [entry])
        hasUnreadErrorsRelay.accept(true)
    }

    func markAllRead() {
        hasUnreadErrorsRelay.accept(false)
    }

    func clearEntries() {
        entriesRelay.accept([])
        hasUnreadErrorsRelay.accept(false)
    }
}
