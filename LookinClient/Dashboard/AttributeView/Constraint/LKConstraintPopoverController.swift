import AppKit
import LookinShared

final class LKConstraintPopoverController: LKBaseViewController {
    var requestJumpingToObject: ((LookinObject) -> Void)?

    private var titleView: LKTextFieldView?
    private var textsView: LKTextsMenuView!
    private let horInset: CGFloat = 5
    private let insetBottom: CGFloat = 10
    private let titleHeight: CGFloat = 26
    private let textsViewMarginTop: CGFloat = 10

    init(constraint: LookinAutoLayoutConstraint) {
        super.init(containerView: nil)
        if !constraint.effective {
            let labelView = LKTextFieldView.label()
            labelView.textField.font = NSFontMake(IsEnglish ? 12 : 13)
            labelView.textColors = LKColorsCombine(NSColorGray1, NSColorGray9)
            labelView.textField.alignment = .center
            labelView.textField.stringValue = NSLocalizedString("The layout of selected view is not affected by this constraint.", comment: "")
            labelView.backgroundColors = LKColorsCombine(LookinColorRGBAMake(0, 0, 0, 0.1), LookinColorRGBAMake(0, 0, 0, 0.2))
            labelView.image = NSImageMake("Constraint_Popover_Info")
            labelView.insets = NSEdgeInsets(top: 0, left: horInset, bottom: 0, right: horInset)
            view.addSubview(labelView)
            titleView = labelView
        }
        textsView = LKTextsMenuView()
        textsView.verSpace = 8
        textsView.horSpace = 4
        textsView.font = NSFontMake(13)
        textsView.type = .center
        view.addSubview(textsView)
        let texts: [LookinStringTwoTuple] = [
            LookinStringTwoTuple.tuple(withFirst: "FirstItem", second: LookinAutoLayoutConstraint.descriptionWithItemObject(constraint.firstItem, type: constraint.firstItemType, detailed: true)),
            LookinStringTwoTuple.tuple(withFirst: "FirstAttribute", second: LookinAutoLayoutConstraint.description(withAttributeInt: constraint.firstAttribute).lk_capitalizedString()),
            LookinStringTwoTuple.tuple(withFirst: "Relation", second: LookinAutoLayoutConstraint.description(with: constraint.relation)),
            LookinStringTwoTuple.tuple(withFirst: "SecondItem", second: LookinAutoLayoutConstraint.descriptionWithItemObject(constraint.secondItem, type: constraint.secondItemType, detailed: true)),
            LookinStringTwoTuple.tuple(withFirst: "SecondAttribute", second: LookinAutoLayoutConstraint.description(withAttributeInt: constraint.secondAttribute).lk_capitalizedString()),
            LookinStringTwoTuple.tuple(withFirst: "Multiplier", second: "\(constraint.multiplier)"),
            LookinStringTwoTuple.tuple(withFirst: "Constant", second: "\(constraint.constant)"),
            LookinStringTwoTuple.tuple(withFirst: "Priority", second: "\(constraint.priority)"),
            LookinStringTwoTuple.tuple(withFirst: "Active", second: constraint.active ? "YES" : "NO"),
            LookinStringTwoTuple.tuple(withFirst: "ShouldBeArchived", second: constraint.shouldBeArchived ? "YES" : "NO"),
            LookinStringTwoTuple.tuple(withFirst: "Identifier", second: constraint.identifier ?? ""),
        ]
        if constraint.firstItemType == .view, let image = NSImageMake("Icon_JumpDisclosure") {
            let button = NSButton.lk_button(with: image, target: self, action: #selector(handleJumpButton(_:)))
            button.lookin_bindObject(constraint.firstItem, forKey: "jumpObject")
            textsView.add(button, atIndex: 0)
        }
        if constraint.secondItemType == .view, let image = NSImageMake("Icon_JumpDisclosure") {
            let button = NSButton.lk_button(with: image, target: self, action: #selector(handleJumpButton(_:)))
            button.lookin_bindObject(constraint.secondItem, forKey: "jumpObject")
            textsView.add(button, atIndex: 3)
        }
        textsView.texts = texts
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func viewDidLayout() {
        super.viewDidLayout()
        if let titleView {
            lk(titleView).fullWidth().height(titleHeight).y(0)
        }
        let y = titleView != nil ? titleHeight : 0
        lk(textsView).sizeToFit().horAlign().y(y + textsViewMarginTop)
    }

    func contentSize() -> NSSize {
        var result = textsView.sizeThatFits(NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        if let titleView {
            result.width = max(result.width, titleView.sizeThatFits(NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width)
            result.height += titleHeight
        }
        result.width += horInset * 2
        result.height += insetBottom + textsViewMarginTop
        return result
    }

    @objc private func handleJumpButton(_ button: NSButton) {
        guard let object = button.lookin_getBindObject(forKey: "jumpObject") as? LookinObject else {
            assertionFailure(); return
        }
        requestJumpingToObject?(object)
    }
}
