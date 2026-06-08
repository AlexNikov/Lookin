import AppKit
import LookinShared
import RxSwift

final class LKDashboardAttributeShadowView: LKDashboardAttributeView {
    private var colorContainerView: LKBaseView!
    private var colorIndicatorLayer: LKColorIndicatorLayer!
    private var colorDescLabel: LKLabel!
    private var inputViews: [LKNumberInputView] = []
    private let disposeBag = DisposeBag()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        colorContainerView = LKBaseView()
        colorContainerView.layer?.cornerRadius = DashboardCardControlCornerRadius
        colorContainerView.backgroundColorName = "DashboardCardValueBGColor"
        addSubview(colorContainerView)

        colorIndicatorLayer = LKColorIndicatorLayer()
        colorContainerView.layer?.addSublayer(colorIndicatorLayer)

        colorDescLabel = LKLabel()
        colorDescLabel.textColor = NSColor(named: "DashboardCardValueColor")
        colorDescLabel.font = NSFontMake(13)
        colorContainerView.addSubview(colorDescLabel)

        inputViews = ["Opacity", "Radius", "OffsetW", "OffsetH"].map { title in
            let view = LKNumberInputView()
            view.textFieldView.textField.isEditable = false
            view.inputTitle = title
            view.viewStyle = .vertical
            addSubview(view)
            return view
        }

        LKPreferenceMain().rgbaFormatObservable
            .skip(1)
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, _ in
                owner.renderWithAttribute()
            }
            .disposed(by: disposeBag)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func layout() {
        super.layout()
        lk(colorContainerView).fullWidth().height(30).y(0)
        lk(colorIndicatorLayer).width(16).height(16).x(8).verAlign()
        lk(colorDescLabel).x(28).toRight(20).heightToFit().verAlign().offsetY(-1)

        let itemWidth = (frame.width - DashboardAttrItemHorInterspace * 3) / 4
        var x: CGFloat = 0
        let y = colorContainerView.frame.maxY + DashboardAttrItemVerInterspace
        for view in inputViews {
            lk(view).width(itemWidth).height(LKNumberInputVerticalHeight).x(x).y(y)
            x += itemWidth + DashboardAttrItemHorInterspace
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        NSSize(width: limitedSize.width, height: 30 + DashboardAttrItemVerInterspace + LKNumberInputVerticalHeight)
    }

    override func renderWithAttribute() {
        guard case .shadow(let shadow)? = attribute?.value else { assertionFailure(); return }
        let color = NSColor.lk_colorFromRGBAComponents(shadow.colorRGBA?.map { NSNumber(value: $0) })
        colorIndicatorLayer.color = color ?? LookinColorMake(0, 0, 0)
        if let color {
            colorDescLabel.stringValue = LKPreferenceMain().rgbaFormat ? color.rgbaString : color.hexString
        } else {
            colorDescLabel.stringValue = "nil"
        }
        let offset = CGSize(width: shadow.offsetWidth, height: shadow.offsetHeight)
        let strings = [
            NSString.lookin_string(from: Double(shadow.opacity), decimal: 2),
            NSString.lookin_string(from: shadow.radius, decimal: 2),
            NSString.lookin_string(from: offset.width, decimal: 2),
            NSString.lookin_string(from: offset.height, decimal: 2),
        ]
        for (idx, view) in inputViews.enumerated() {
            view.textFieldView.textField.stringValue = strings[idx]
        }
    }
}
