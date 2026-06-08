import AppKit
import LookinShared

enum LKDashboardSectionManageState: Int {
    case none = 0
    case canAdd = 1
    case canRemove = 2
}

final class LKDashboardSectionView: LKBaseView {
    var attrSection: LookinAttributesSection? {
        didSet { applyAttrSection() }
    }

    var showTopSeparator = false {
        didSet { topSepLayer.isHidden = !showTopSeparator }
    }

    weak var dashboardViewController: LKDashboardViewController?

    var manageState: LKDashboardSectionManageState = .none {
        didSet { applyManageState() }
    }

    private var attrViews: [LKDashboardAttributeView] = []
    private var titleLabel: LKLabel?
    private let topSepLayer = CALayer()
    private var manageButton: NSButton?
    private var jsonPopupButton: NSButton?
    private let titleMarginTop: CGFloat = 6

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        topSepLayer.lookin_removeImplicitAnimations()
        layer?.addSublayer(topSepLayer)
        updateColors()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func manageButtonLayoutY() -> CGFloat {
        if topSepLayer.isHidden {
            return 0
        }
        if titleLabel?.isVisible == true {
            return 6
        }
        return 9
    }

    private func hasDisplayableContent(forWidth width: CGFloat) -> Bool {
        if titleLabel?.isVisible == true, let titleLabel {
            let titleWidth = width - (jsonPopupButton?.isVisible == true ? 20 : 0)
            if titleLabel.sizeThatFits(NSSize(width: titleWidth, height: .greatestFiniteMagnitude)).height > 0 {
                return true
            }
        }
        let limitedSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        return attrViews.contains { view in
            view.lk_clientIsVisible && view.sizeThatFits(limitedSize).height > 0
        }
    }

    override func layout() {
        super.layout()
        var contentsX: CGFloat = 0
        let selfWidth = frame.width
        var contentsY: CGFloat = 0

        if manageButton?.isVisible == true, let manageButton {
            let y = manageButtonLayoutY()
            lk(manageButton).sizeToFit().x(0).y(y)
            contentsX = manageButton.frame.maxX + 6
        }

        if jsonPopupButton?.isVisible == true, let jsonPopupButton {
            lk(jsonPopupButton).width(30).height(28).right(-5).y(0)
        }

        if !topSepLayer.isHidden {
            lk(topSepLayer).x(contentsX).width(selfWidth).height(1).y(0)
            contentsY = DashboardAttrItemVerInterspace
        }

        if titleLabel?.isVisible == true, let titleLabel {
            var titleWidth = selfWidth
            if jsonPopupButton?.isVisible == true { titleWidth -= 20 }
            lk(titleLabel).x(contentsX).width(titleWidth).heightToFit().y(topSepLayer.isHidden ? 0 : titleMarginTop)
            contentsY = titleLabel.frame.maxY + DashboardAttrItemVerInterspace
        }

        let visibleAttrViews = attrViews.filter { $0.lk_clientIsVisible }
        for (idx, view) in visibleAttrViews.enumerated() {
            let prevView = idx > 0 ? visibleAttrViews[idx - 1] : nil
            let numberOfColumns = view.numberOfColumnsOccupied()
            let width: CGFloat
            if numberOfColumns == 0 {
                width = view.sizeThatFits(NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width
            } else {
                width = floor((selfWidth + DashboardAttrItemHorInterspace) / CGFloat(numberOfColumns)) - DashboardAttrItemHorInterspace
            }
            let x: CGFloat
            let y: CGFloat
            if let prevView, prevView.frame.maxX + DashboardAttrItemHorInterspace + width <= selfWidth + contentsX {
                x = prevView.frame.maxX + DashboardAttrItemHorInterspace
                y = prevView.frame.origin.y
            } else {
                x = contentsX
                y = prevView.map { $0.frame.maxY + DashboardAttrItemVerInterspace } ?? contentsY
            }
            lk(view).width(width).heightToFit().x(x).y(y)
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var height: CGFloat = 0
        if !topSepLayer.isHidden {
            height += DashboardAttrItemVerInterspace
        }
        if titleLabel?.isVisible == true, let titleLabel {
            var titleWidth = limitedSize.width
            if jsonPopupButton?.isVisible == true { titleWidth -= 20 }
            height += titleLabel.sizeThatFits(NSSize(width: titleWidth, height: .greatestFiniteMagnitude)).height + titleMarginTop
        }
        let visibleAttrViews = attrViews.filter { $0.lk_clientIsVisible }
        var prevMaxX: CGFloat = 0
        for (idx, view) in visibleAttrViews.enumerated() {
            let numberOfColumns = view.numberOfColumnsOccupied()
            let width: CGFloat
            if numberOfColumns == 0 {
                width = view.sizeThatFits(limitedSize).width
            } else {
                width = floor((limitedSize.width + DashboardAttrItemHorInterspace) / CGFloat(numberOfColumns)) - DashboardAttrItemHorInterspace
            }
            if idx > 0, prevMaxX + DashboardAttrItemHorInterspace + width <= limitedSize.width {
                prevMaxX += DashboardAttrItemHorInterspace + width
            } else {
                height += view.sizeThatFits(limitedSize).height
                if idx > 0 { height += DashboardAttrItemVerInterspace }
                prevMaxX = width
            }
        }
        if manageButton?.isHidden == false, let manageButton {
            let buttonHeight = manageButton.sizeThatFits(limitedSize).height
            height = max(height, manageButtonLayoutY() + buttonHeight)
        }
        return NSSize(width: limitedSize.width, height: height)
    }

    override func updateColors() {
        super.updateColors()
        topSepLayer.backgroundColor = LookinClientIsDarkMode() ? SeparatorDarkModeColor.cgColor : SeparatorLightModeColor.cgColor
    }

    private func applyAttrSection() {
        guard let attrSection else {
            assertionFailure()
            return
        }
        let title = resolveSectionTitle()
        if !title.isEmpty {
            if titleLabel == nil {
                let label = LKLabel()
                label.font = NSFont.boldSystemFont(ofSize: 12)
                addSubview(label)
                titleLabel = label
            }
            titleLabel?.isHidden = false
            titleLabel?.stringValue = title
        } else {
            titleLabel?.isHidden = true
        }

        var notUsedViews = attrViews
        for attr in attrSection.attributes ?? [] {
            guard let attrViewClass = targetAttrClass(for: attr.attrType, identifier: attr.identifier ?? "") else {
                assertionFailure()
                continue
            }
            var view = notUsedViews.first { type(of: $0) == attrViewClass }
            if let view {
                notUsedViews.removeAll { $0 === view }
                view.isHidden = false
            } else {
                view = attrViewClass.init()
                guard let view else { continue }
                view.dashboardViewController = dashboardViewController
                attrViews.append(view)
                addSubview(view)
            }
            if let selectedItem = dashboardViewController?.currentDataSource()?.selectedItem {
                attr.targetDisplayItem = selectedItem
            }
            view?.attribute = attr
        }
        notUsedViews.forEach { $0.isHidden = true }

        let hasJSON = (attrSection.attributes ?? []).contains { $0.attrType == .json }
        if hasJSON {
            showJSONPopupButton()
        } else {
            hideJSONPopupButton()
        }
        if manageState != .none {
            applyManageState()
        }
        needsLayout = true
    }

    private func targetAttrClass(for type: LookinAttrType, identifier: LookinAttrIdentifier) -> LKDashboardAttributeView.Type? {
        switch type {
        case .CGRect: return LKDashboardAttributeRectView.self
        case .UIEdgeInsets: return LKDashboardAttributeInsetsView.self
        case .BOOL: return LKDashboardAttributeSwitchView.self
        case .float, .double, .long: return LKDashboardAttributeNumberInputView.self
        case .UIColor: return LKDashboardAttributeColorView.self
        case .enumInt, .enumLong, .enumString: return LKDashboardAttributeEnumsView.self
        case .CGPoint: return LKDashboardAttributePointView.self
        case .CGSize: return LKDashboardAttributeSizeView.self
        case .NSString: return LKDashboardAttributeTextView.self
        case .shadow: return LKDashboardAttributeShadowView.self
        case .json: return LKDashboardAttributeJsonView.self
        case .customObj:
            switch identifier {
            case LookinAttr_UITableView_RowsNumber_Number: return LKDashboardAttributeRowsCountView.self
            case LookinAttr_Class_Class_Class: return LKDashboardAttributeClassView.self
            case LookinAttr_Relation_Relation_Relation: return LKDashboardAttributeRelationView.self
            case LookinAttr_AutoLayout_Constraints_Constraints: return LKDashboardAttributeConstraintsView.self
            case LookinAttr_UIImageView_Open_Open: return LKDashboardAttributeOpenImageView.self
            case LookinAttr_UIVisualEffectView_Style_Style: return LKDashboardAttributeEnumsView.self
            default:
                assertionFailure()
                return nil
            }
        default:
            assertionFailure()
            return nil
        }
    }

    private func showJSONPopupButton() {
        guard jsonPopupButton == nil else { return }
        let button = NSButton(image: .lookinNamed("open_newwindow"), target: self, action: #selector(handleJSONPopupButton))
        button.bezelStyle = .rounded
        button.isBordered = false
        addSubview(button)
        jsonPopupButton = button
    }

    private func hideJSONPopupButton() {
        jsonPopupButton?.removeFromSuperview()
        jsonPopupButton = nil
    }

    @objc private func handleJSONPopupButton() {
        guard let view = attrViews.first(where: { $0.attribute?.attrType == .json }) as? LKDashboardAttributeJsonView else {
            assertionFailure()
            return
        }
        view.showInNewWindow()
    }

    private func applyManageState() {
        switch manageState {
        case .none:
            manageButton?.isHidden = true
            needsLayout = true
        case .canAdd, .canRemove:
            let imageName = manageState == .canAdd ? "icon_manage_add" : "icon_manage_remove"
            let sectionWidth = bounds.width > 0 ? bounds.width : DashboardViewWidth - DashboardHorInset * 2
            let shouldShowManageButton = manageState == .canAdd || hasDisplayableContent(forWidth: sectionWidth)
            if let manageButton {
                manageButton.image = .lookinNamed(imageName)
                manageButton.isHidden = !shouldShowManageButton
            } else if shouldShowManageButton {
                let button = NSButton(image: .lookinNamed(imageName), target: self, action: #selector(handleManageButton))
                button.bezelStyle = .rounded
                button.isBordered = false
                addSubview(button)
                manageButton = button
            }
            needsLayout = true
        }
    }

    @objc private func handleManageButton() {
        guard let identifier = attrSection?.identifier else { return }
        let manager = LKPreferenceMain()
        switch manageState {
        case .canAdd: manager.showSection(identifier)
        case .canRemove: manager.hideSection(identifier)
        default: assertionFailure()
        }
    }

    private func resolveSectionTitle() -> String {
        guard let attrSection else { return "" }
        if !attrSection.isUserCustom() {
            return LookinDashboardBlueprint.sectionTitle(withSectionID: attrSection.identifier ?? "") ?? ""
        }
        guard let attr = (attrSection.attributes ?? []).first else {
            assertionFailure()
            return ""
        }
        switch attr.attrType {
        case .BOOL: return ""
        default: return attr.displayTitle ?? ""
        }
    }
}
