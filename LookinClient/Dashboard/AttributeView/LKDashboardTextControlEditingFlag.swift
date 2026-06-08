import Foundation

final class LKDashboardTextControlEditingFlag: NSObject {
    static let sharedInstance = LKDashboardTextControlEditingFlag()

    var shouldIgnoreTextEditingChangeEvent = false

    private override init() {
        super.init()
    }
}
