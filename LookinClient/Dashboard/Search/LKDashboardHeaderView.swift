import AppKit
import LookinShared
import RxSwift

final class LKDashboardHeaderView: LKBaseView, NSTextFieldDelegate {
    var isActive = false {
        didSet { applyActiveState(oldValue: oldValue) }
    }

    weak var delegate: LKDashboardHeaderViewDelegate?

    private var inputBorderView: NSView!
    private var iconImageView: NSImageView!
    private var textField: NSTextField!
    private var addButton: NSButton!
    private let iconXWhenActive: CGFloat = 11
    private let iconXWhenInactive: CGFloat = 89
    private let disposeBag = DisposeBag()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        inputBorderView = NSView()
        inputBorderView.wantsLayer = true
        inputBorderView.layer?.cornerRadius = DashboardCardCornerRadius
        inputBorderView.layer?.borderWidth = 1
        addSubview(inputBorderView)

        iconImageView = NSImageView()
        iconImageView.image = NSImageMake("icon_search")
        addSubview(iconImageView)

        textField = NSTextField()
        textField.placeholderString = NSLocalizedString("properties or methods", comment: "")
        textField.delegate = self
        textField.focusRingType = .none
        textField.isEditable = true
        textField.isBordered = false
        textField.isBezeled = false
        textField.usesSingleLineMode = true
        textField.backgroundColor = .clear
        textField.lineBreakMode = .byTruncatingTail
        textField.font = NSFontMake(13)
        textField.isHidden = true
        addSubview(textField)

        addButton = NSButton()
        addButton.image = NSImage(named: NSImage.addTemplateName)
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(handleAddButton)
        addButton.frame = NSRect(x: 0, y: 0, width: 84, height: 40)
        addSubview(addButton)

        textField.lk_textOrEmpty
            .throttle(.milliseconds(300), latest: false, scheduler: MainScheduler.instance)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] string in
                guard let self else { return }
                self.delegate?.dashboardHeaderView(self, didInputString: string)
            })
            .disposed(by: disposeBag)

        updateColors()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        if isActive {
            lk(inputBorderView).fullFrame()
            lk(iconImageView).sizeToFit().x(iconXWhenActive)
        } else {
            lk(addButton).width(50).fullHeight().right(-6).offsetY(1)
            lk(inputBorderView).x(0).toRight(48).fullHeight()
            lk(iconImageView).sizeToFit().verAlign().x(iconXWhenInactive)
        }
        lk(textField).x(30).toRight(2).heightToFit().verAlign()
    }

    override func updateColors() {
        super.updateColors()
        if isActive {
            inputBorderView.layer?.borderColor = LookinClientIsDarkMode() ? LookinColorMake(70, 71, 72).cgColor : LookinColorMake(198, 199, 200).cgColor
        } else {
            inputBorderView.layer?.borderColor = LookinClientIsDarkMode() ? LookinColorMake(47, 48, 49).cgColor : LookinColorMake(220, 221, 222).cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        isActive = true
    }

    func currentInputString() -> String {
        textField.stringValue
    }

    private func applyActiveState(oldValue: Bool) {
        guard oldValue != isActive else { return }
        updateColors()
        if isActive {
            addButton.animator().alphaValue = 0
            inputBorderView.animator().setFrameSize(frame.size)
            iconImageView.animator().setFrameOrigin(NSPoint(x: iconXWhenActive, y: iconImageView.frame.origin.y))
            textField.animator().isHidden = false
            window?.makeFirstResponder(textField)
        } else {
            addButton.animator().alphaValue = 1
            inputBorderView.animator().setFrameSize(NSSize(width: frame.width - 48, height: frame.height))
            iconImageView.animator().setFrameOrigin(NSPoint(x: iconXWhenInactive, y: iconImageView.frame.origin.y))
            textField.animator().isHidden = true
            textField.stringValue = ""
        }
        delegate?.dashboardHeaderView(self, didToggleActive: isActive)
    }

    @objc private func handleAddButton() {
        let menu = NSMenu()
        let item = NSMenuItem()
        item.image = NSImageMake("Icon_Inspiration_small")
        item.title = NSLocalizedString("How to add custom properties…", comment: "")
        item.target = self
        item.action = #selector(handleAddCustomAttr)
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: addButton)
    }

    @objc private func handleAddCustomAttr() {
        NSWorkspace.shared.open(URL(string: "https://bytedance.feishu.cn/docx/TRridRXeUoErMTxs94bcnGchnlb")!)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        isActive = false
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            isActive = false
            return true
        }
        return false
    }
}
