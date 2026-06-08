import AppKit
import LookinShared

class LKDashboardAttributeView: LKBaseView {
    var attribute: LookinAttribute? {
        didSet { renderWithAttribute() }
    }

    var valueView: Any?

    weak var dashboardViewController: LKDashboardViewController?

    func canEdit() -> Bool {
        guard let attribute else { return false }
        if attribute.isUserCustom() {
            return !(attribute.customSetterID ?? "").isEmpty
        }
        let setter = LookinDashboardBlueprint.setter(withAttrID: attribute.identifier ?? "")
        return setter != nil && (dashboardViewController?.isStaticMode ?? false)
    }

    func renderWithAttribute() {}

    func numberOfColumnsOccupied() -> UInt {
        1
    }
}
