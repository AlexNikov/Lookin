import AppKit
import LookinShared

final class LKDashboardSearchPropView: LKDashboardSearchCardView {
    weak var delegate: LKDashboardSearchPropViewDelegate?

    private var titleLabel: LKLabel!
    private var contentLabel: LKLabel!
    private var revealControl: LKTextControl!
    private var attribute: LookinAttribute?
    private let contentLabelY: CGFloat = 21

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        titleLabel = LKLabel()
        titleLabel.font = NSFontMake(12)
        titleLabel.textColor = .secondaryLabelColor
        addSubview(titleLabel)

        contentLabel = LKLabel()
        contentLabel.font = NSFontMake(15)
        addSubview(contentLabel)

        revealControl = LKTextControl()
        revealControl.onClick = { [weak self] in
            guard let self, let attribute = self.attribute else { return }
            self.delegate?.dashboardSearchPropView(self, didClickRevealAttribute: attribute)
        }
        revealControl.adjustAlphaWhenClick = true
        addSubview(revealControl)
        updateColors()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        let width = frame.width - DashboardSearchCardInset * 2
        lk(titleLabel).x(DashboardSearchCardInset).width(width).heightToFit().y(5)
        lk(contentLabel).x(DashboardSearchCardInset).width(width).heightToFit().y(contentLabelY)
        lk(revealControl).sizeToFit().x(DashboardSearchCardInset).bottom(DashboardSearchCardInset)
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        let width = limitedSize.width - DashboardSearchCardInset * 2
        size.height = contentLabelY + contentLabel.heightForWidth(width) + DashboardSearchCardInset + 25
        return size
    }

    override func updateColors() {
        super.updateColors()
        contentLabel.textColor = LookinClientIsDarkMode() ? LookinColorMake(250, 251, 252) : LookinColorMake(56, 57, 58)
        let text = NSLocalizedString("Reveal in panel…", comment: "")
        revealControl.label.attributedStringValue = LKAttrString(text, style: .searchRevealLink).build()
    }

    func render(with attribute: LookinAttribute) {
        self.attribute = attribute
        titleLabel.stringValue = attribute.displayTitle ?? LookinDashboardBlueprint.fullTitle(withAttrID: attribute.identifier ?? "") ?? ""
        contentLabel.stringValue = stringValue(from: attribute)
        needsLayout = true
    }

    private func stringValue(from attribute: LookinAttribute) -> String {
        guard let value = attribute.value else {
            switch attribute.attrType {
            case .none, .void, .customObj:
                assertionFailure()
                return ""
            default:
                return ""
            }
        }
        switch attribute.attrType {
        case .none, .void, .customObj:
            assertionFailure()
            return ""
        case .char, .int, .short, .long, .longLong, .unsignedChar, .unsignedInt, .unsignedShort, .unsignedLong, .unsignedLongLong, .float, .double, .sel, .class, .CGVector, .CGAffineTransform, .UIOffset:
            return value.dashboardScalarDisplayString
        case .BOOL:
            return value.dashboardBoolValue ? "YES" : "NO"
        case .CGPoint:
            if case .cgPoint(let point) = value { return NSString.lookin_string(from: point) }
            return ""
        case .CGSize:
            if case .cgSize(let size) = value { return NSString.lookin_string(from: size) }
            return ""
        case .CGRect:
            if case .cgRect(let rect) = value { return NSString.lookin_string(from: rect) }
            return ""
        case .UIEdgeInsets:
            if case .edgeInsets(let insets) = value { return NSString.lookin_string(from: insets) }
            return ""
        case .NSString, .enumString:
            return value.dashboardStringValue ?? ""
        case .enumInt, .enumLong:
            let enumValue = value.dashboardIntValue
            let enumListName = LookinDashboardBlueprint.enumListName(withAttrID: attribute.identifier ?? "") ?? ""
            return LKEnumListRegistry.sharedInstance.desc(forEnumName: enumListName, value: enumValue) ?? ""
        case .UIColor:
            let color = NSColor.lk_colorFromAttributeValue(value)
            if let color {
                return LKPreferenceMain().rgbaFormat ? color.rgbaString : color.hexString
            }
            return "nil"
        case .shadow, .json:
            return "……"
        @unknown default:
            assertionFailure()
            return ""
        }
    }
}
