import AppKit
import LookinShared

final class LKDashboardAttributeConstraintsItemControl: LKTextControl {
    var constraint: LookinAutoLayoutConstraint? {
        didSet {
            guard let constraint else { return }
            label.stringValue = string(from: constraint)
            updateLabelColor()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.alignment = .left
        label.font = NSFontMake(12)
        didChangeAppearance = { [weak self] _, _ in
            self?.updateLabelColor()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func updateLabelColor() {
        guard let constraint else { return }
        if constraint.effective {
            label.textColor = .labelColor
        } else if effectiveAppearance.lk_isDarkMode {
            label.textColor = LookinColorMake(130, 131, 132)
        } else {
            label.textColor = LookinColorMake(150, 151, 152)
        }
    }

    private func string(from constraint: LookinAutoLayoutConstraint) -> String {
        var result = String(format: "%@.%@ %@",
                            LookinAutoLayoutConstraint.descriptionWithItemObject( constraint.firstItem, type: constraint.firstItemType, detailed: false),
                            LookinAutoLayoutConstraint.description(withAttributeInt: constraint.firstAttribute),
                            LookinAutoLayoutConstraint.symbol(with: constraint.relation))

        if constraint.secondAttribute == 0 {
            result += " \(NSString.lookin_string(from: constraint.constant, decimal: 3))"
        } else {
            result += String(format: " %@.%@",
                             LookinAutoLayoutConstraint.descriptionWithItemObject( constraint.secondItem, type: constraint.secondItemType, detailed: false),
                             LookinAutoLayoutConstraint.description(withAttributeInt: constraint.secondAttribute))
            if constraint.multiplier != 1 {
                result += " * \(NSString.lookin_string(from: constraint.multiplier, decimal: 3))"
            }
            if constraint.constant > 0 {
                result += " + \(NSString.lookin_string(from: constraint.constant, decimal: 3))"
            } else if constraint.constant < 0 {
                result += " - \(NSString.lookin_string(from: -constraint.constant, decimal: 3))"
            }
        }
        if constraint.priority != 1000 {
            result += " @ \(constraint.priority)"
        }
        return result
    }

    override func shouldTrackMouseEnteredAndExited() -> Bool { true }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        alphaValue = 0.5
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        alphaValue = 1
    }
}
