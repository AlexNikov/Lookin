import Foundation
import LookinShared
import RxSwift

extension LKDashboardAttributeView {
    @discardableResult
    func subscribeAttributeModification(
        newValue: AttributeValue?,
        onError: @escaping () -> Void = {},
        onSuccess: (() -> Void)? = nil
    ) -> Disposable? {
        guard let dashboardViewController, let attribute else { return nil }
        return LookinRACSignalRx.observeMainThread(
            dashboardViewController.modifyAttribute(attribute, newValue: newValue)
        )
        .subscribe(
            onSuccess: {
                onSuccess?()
            },
            onFailure: { _ in
                onError()
            }
        )
    }
}
