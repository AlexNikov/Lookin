//
//  LKPreferenceSwitchView.swift
//  Lookin
//
//  Created by Li Kai on 2019/2/28.
//  https://lookin.work
//

import AppKit

class LKPreferenceSwitchView: LKBaseView {
    private var button: NSButton!
    private var messageLabel: LKLabel!
    private var checkedMessage: String?
    private var uncheckedMessage: String?
    private let messageMarginTop: CGFloat = 3
    private let messageX: CGFloat = 19

    var isChecked = false {
        didSet {
            messageLabel.stringValue = isChecked ? (checkedMessage ?? "") : (uncheckedMessage ?? "")
            button.state = isChecked ? .on : .off
            didChange?(isChecked)
            needsLayout = true
        }
    }

    var didChange: ((Bool) -> Void)?

    init(title: String, checkedMessage: String, uncheckedMessage: String) {
        super.init(frame: .zero)
        self.checkedMessage = checkedMessage
        self.uncheckedMessage = uncheckedMessage

        button = NSButton()
        button.setButtonType(.switch)
        button.font = NSFontMake(15)
        button.title = title
        button.target = self
        button.action = #selector(handleButton)
        addSubview(button)

        messageLabel = LKLabel()
        messageLabel.font = NSFontMake(13)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.maximumNumberOfLines = 0
        addSubview(messageLabel)
    }

    convenience init(title: String, message: String) {
        self.init(title: title, checkedMessage: message, uncheckedMessage: message)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        lk(button).fullWidth().height(button.sizeThatFits(NSSizeMax).height + 2).y(0)
        lk(messageLabel).x(messageX).toRight(0).heightToFit().y(button.frame.maxY + messageMarginTop)
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        size.height = button.sizeThatFits(limitedSize).height + 2 + messageMarginTop +
            messageLabel.sizeThatFits(NSSize(width: limitedSize.width - messageX, height: limitedSize.height)).height
        return size
    }

    @objc private func handleButton() {
        isChecked = button.state == .on
        didChange?(isChecked)
    }
}
