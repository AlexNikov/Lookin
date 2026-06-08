import AppKit
import LookinShared
import RxSwift

final class LKDashboardSearchMethodsDataSource: NSObject {
    private var classesToSelsDict: [String: [String]] = [:]

    func fetchNonArgMethodsList(withClass className: String) -> Single<[String]> {
        guard !className.isEmpty else {
            return .error(LKLookinClientErrors.inner)
        }
        guard let app = LKAppsManager.sharedInstance.inspectingApp else {
            return .error(LKLookinClientErrors.noConnect)
        }
        if let cached = classesToSelsDict[className] {
            return .just(cached)
        }
        return app.fetchSelectorNames(withClass: className, hasArg: false).do(onSuccess: { [weak self] sels in
            self?.classesToSelsDict[className] = sels
        })
    }

    func clearAllCache() {
        classesToSelsDict.removeAll()
    }
}
