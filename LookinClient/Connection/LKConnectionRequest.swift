//
//  LKConnectionRequest.swift
//  Lookin
//
//  Created by Li Kai on 2019/6/24.
//  https://lookin.work
//

import Foundation

class LKConnectionRequest: NSObject {
    var type: UInt32 = 0
    var tag: UInt32 = 0
    var receivedDataCount: UInt = 0
    var succBlock: ((Any) -> Void)?
    var completionBlock: (() -> Void)?
    var failBlock: ((NSError) -> Void)?

    var timeoutInterval: TimeInterval = 0
    var timeoutBlock: ((LKConnectionRequest) -> Void)?

    private var timeoutWorkItem: DispatchWorkItem?

    func resetTimeoutCount() {
        endTimeoutCount()
        guard timeoutInterval > 0 else {
            assertionFailure("timeoutInterval 为 0")
            return
        }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.timeoutBlock?(self)
        }
        timeoutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutInterval, execute: item)
    }

    func endTimeoutCount() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }

    private func _handleTimeout() {
        timeoutBlock?(self)
    }
}
