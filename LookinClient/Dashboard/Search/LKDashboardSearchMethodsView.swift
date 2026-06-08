import AppKit
import LookinShared

final class LKDashboardSearchMethodsView: LKDashboardSearchCardView {
    weak var delegate: LKDashboardSearchMethodsViewDelegate?

    private var titleLabel: LKLabel!
    private var errorLabel: LKLabel?
    private var itemViews: [LKTextControl] = []
    private var oid: UInt = 0
    private let insetTop: CGFloat = 5
    private let contentMarginTop: CGFloat = 10
    private let itemInterspace: CGFloat = 8

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        titleLabel = LKLabel()
        titleLabel.font = NSFontMake(12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.stringValue = NSLocalizedString("Click to invoke methods below and get the return value.", comment: "")
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        let width = frame.width - DashboardSearchCardInset * 2
        if titleLabel.isVisible {
            lk(titleLabel).x(DashboardSearchCardInset).width(width).heightToFit().y(insetTop)
            var y = titleLabel.frame.maxY + contentMarginTop
            for view in itemViews where !view.isHidden {
                let size = view.sizeThatFits(NSSize(width: width, height: .greatestFiniteMagnitude))
                lk(view).size(size).x(DashboardSearchCardInset).y(y)
                y = view.frame.maxY + itemInterspace
            }
        } else if errorLabel?.isVisible == true, let errorLabel {
            lk(errorLabel).x(DashboardSearchCardInset).width(width).heightToFit().y(insetTop)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        let contentWidth = limitedSize.width - DashboardSearchCardInset * 2
        if titleLabel.isVisible {
            var height = titleLabel.heightForWidth(contentWidth) + insetTop + contentMarginTop
            for view in itemViews {
                height += view.heightForWidth(contentWidth) + itemInterspace
            }
            size.height = height
        } else if let errorLabel {
            size.height = errorLabel.heightForWidth(contentWidth) + insetTop * 2
        }
        return size
    }

    func render(withMethods methods: [String], oid: UInt) {
        self.oid = oid
        titleLabel.isHidden = false
        errorLabel?.isHidden = true
        let mutable = NSMutableArray(array: itemViews)
        mutable.lookin_dequeue(withCount: methods.count, add: { [weak self] _ in
            let control = LKTextControl()
            control.label.alignment = .left
            control.label.maximumNumberOfLines = 0
            control.adjustAlphaWhenClick = true
            control.addTarget(self, clickAction: #selector(LKDashboardSearchMethodsView.handleMethodControl(_:)))
            self?.addSubview(control)
            return control
        }, notDequeued: { _, view in
            (view as? NSView)?.isHidden = true
        }, doNext: { idx, view in
            guard let view = view as? LKTextControl else { return }
            view.isHidden = false
            view.lookin_bindObject(methods[Int(idx)], forKey: "methodName")
            view.label.attributedStringValue = LKAttrString(methods[Int(idx)], style: .searchMethodLink).build()
            view.needsLayout = true
        })
        itemViews = mutable as? [LKTextControl] ?? []
        needsLayout = true
    }

    func render(with error: NSError) {
        itemViews.forEach { $0.isHidden = true }
        titleLabel.isHidden = true
        if errorLabel == nil {
            let label = LKLabel()
            label.textColor = .labelColor
            label.font = NSFontMake(12)
            addSubview(label)
            errorLabel = label
        }
        errorLabel?.isHidden = false
        errorLabel?.stringValue = NSLocalizedString("Failed to search related methods: ", comment: "") + error.localizedDescription
        needsLayout = true
    }

    @objc private func handleMethodControl(_ control: NSControl) {
        guard let methodName = control.lookin_getBindObject(forKey: "methodName") as? String, !methodName.isEmpty else {
            assertionFailure()
            return
        }
        delegate?.dashboardSearchMethodsView(self, requestToInvokeMethod: methodName, oid: oid)
    }
}
