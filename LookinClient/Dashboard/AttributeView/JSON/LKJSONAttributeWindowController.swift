import AppKit
import LookinShared

final class LKJSONAttributeWindowController: LKWindowController {
    init() {
        let window = LKWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 320),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 200, height: 200)
        window.center()
        super.init(window: window)
        let vc = LKJSONAttributeViewController()
        window.contentView = vc.view
        contentViewController = vc
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
