import AppKit

class LKDashboardSearchCardView: LKBaseView {
    private var backgroundEffectView: LKVisualEffectView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = DashboardCardCornerRadius

        backgroundEffectView = LKVisualEffectView()
        backgroundEffectView.blendingMode = .withinWindow
        backgroundEffectView.state = .active
        addSubview(backgroundEffectView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        lk(backgroundEffectView).fullFrame()
    }
}
