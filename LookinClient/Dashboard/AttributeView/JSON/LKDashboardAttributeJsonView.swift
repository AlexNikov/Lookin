import AppKit
import LookinShared

final class LKDashboardAttributeJsonView: LKDashboardAttributeView {
    private var contentView: LKJSONAttributeContentView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = DashboardCardControlCornerRadius
        contentView = LKJSONAttributeContentView(bigFont: false)
        contentView.didReloadData = { [weak self] in
            self?.dashboardViewController?.view.needsLayout = true
        }
        addSubview(contentView)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func layout() {
        super.layout()
        lk(contentView).fullFrame()
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        NSSize(width: limitedSize.width, height: contentView.queryContentHeight())
    }

    override func renderWithAttribute() {
        super.renderWithAttribute()
        contentView.render(withJSONValue: attribute?.value)
    }

    func showInNewWindow() {
        guard let json = attribute?.value.flatMap({ value -> String? in
            if case .json(let doc) = value { return doc }
            return nil
        }) else {
            return
        }
        LKNavigationManager.sharedInstance.showJsonWindow(json)
    }
}
