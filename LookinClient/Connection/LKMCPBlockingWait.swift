//
//  LKMCPBlockingWait.swift
//  Lookin
//
//  Block background MCP threads until main-queue Rx work completes (sem, not spin).
//

import Foundation

enum LKMCPBlockingWait {
    /// Run `work` on main; block calling thread until `signal` or timeout.
    static func onMain<T>(
        timeout: TimeInterval,
        work: @escaping (@escaping (Result<T, Error>) -> Void) -> Void
    ) -> Result<T, Error> {
        if Thread.isMainThread {
            fatalError("LKMCPBlockingWait.onMain must not run on main thread")
        }
        let sem = DispatchSemaphore(value: 0)
        var outcome: Result<T, Error>?
        DispatchQueue.main.async {
            work { result in
                outcome = result
                sem.signal()
            }
        }
        let hopOk = sem.wait(timeout: .now() + LKMCPTiming.mainQueueHop) == .success
        guard hopOk else {
            return .failure(LKLookinClientErrors.inner)
        }
        let waitOk = sem.wait(timeout: .now() + timeout) == .success
        if let outcome { return outcome }
        if waitOk {
            return .failure(LKLookinClientErrors.inner)
        }
        return .failure(LKLookinClientErrors.timeout())
    }
}
