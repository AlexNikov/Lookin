import AppKit
import LookinShared

final class LKJSONAttributeViewController: LKBaseViewController {
    private var contentView: LKJSONAttributeContentView!

    override func makeContainerView() -> NSView {
        let containerView = LKBaseView()
        contentView = LKJSONAttributeContentView(bigFont: true)
        containerView.addSubview(contentView)
        return containerView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        lk(contentView).fullFrame().toY(28)
    }

    func render(withJSON json: String) {
        render(withJSONValue: .json(json))
    }

    func render(withJSONValue value: AttributeValue?) {
        contentView.render(withJSONValue: value)
    }
}
