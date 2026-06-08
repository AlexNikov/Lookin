//
//  LKUserActionManager.swift
//  Lookin
//
//  Created by Li Kai on 2019/8/30.
//  https://lookin.work
//

import Foundation

final class LKUserActionManager {
    static let sharedInstance = LKUserActionManager()

    private struct WeakDelegate {
        weak var value: LKUserActionManagerDelegate?
    }

    private var delegates: [WeakDelegate] = []

    private init() {}

    func addDelegate(_ delegate: LKUserActionManagerDelegate) {
        guard !delegates.contains(where: { $0.value as AnyObject? === delegate as AnyObject }) else {
            return
        }
        delegates.append(WeakDelegate(value: delegate))
        compactDelegates()
    }

    func send(_ type: LKUserActionType) {
        sendAction(type)
    }

    func sendAction(_ type: LKUserActionType) {
        guard type != .none else {
            assertionFailure()
            return
        }
        compactDelegates()
        for entry in delegates {
            entry.value?.lkUserActionManager(self, didAct: type)
        }
    }

    private func compactDelegates() {
        delegates.removeAll { $0.value == nil }
    }
}
