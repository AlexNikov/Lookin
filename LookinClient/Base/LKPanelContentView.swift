//
//  LKPanelContentView.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/24.
//  https://lookin.work
//

import AppKit

class LKPanelContentView: LKBaseView {
    private(set) var submitButton: NSButton!
    private(set) var contentView: LKBaseView!
    private var titleImageView: NSImageView!
    private var titleLabel: LKLabel!
    private var titleContainerView: LKBaseView!
    private var cancelButton: NSButton!

    var titleImage: NSImage? {
        didSet {
            titleImageView.image = titleImage
            needsLayout = true
        }
    }

    var titleText: String? {
        didSet {
            titleLabel.stringValue = titleText ?? ""
            needsLayout = true
        }
    }

    var needExit: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColorName = "DashboardBackgroundColor"

        titleContainerView = LKBaseView()
        titleContainerView.backgroundColorName = "PanelTitleBackgroundColor"
        addSubview(titleContainerView)

        titleImageView = NSImageView()
        titleContainerView.addSubview(titleImageView)

        titleLabel = LKLabel()
        titleLabel.font = NSFontMake(13)
        titleContainerView.addSubview(titleLabel)

        cancelButton = NSButton.lk_normalButton(
            withTitle: NSLocalizedString("Cancel", comment: ""),
            target: self,
            action: #selector(handleCancelButton)
        )
        cancelButton.keyEquivalent = "\u{1b}"
        addSubview(cancelButton)

        submitButton = NSButton.lk_normalButton(
            withTitle: NSLocalizedString("Done", comment: ""),
            target: self,
            action: #selector(handleSubmitButton)
        )
        submitButton.keyEquivalent = "\r"
        addSubview(submitButton)

        contentView = LKBaseView()
        contentView.layer?.masksToBounds = false
        addSubview(contentView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        let insets = NSEdgeInsets(top: 0, left: 14, bottom: 6, right: 14)
        lk(titleContainerView).fullWidth().height(40).y(0)
        lk(titleImageView).sizeToFit().x(insets.left).verAlign()
        lk(titleLabel).sizeToFit().x(titleImageView.frame.maxX + 6).verAlign()
        lk(submitButton).right(insets.right).bottom(insets.bottom)
        lk(cancelButton).maxX(submitButton.frame.origin.x - 5).bottom(insets.bottom)
        lk(contentView).x(insets.left).toRight(insets.right).y(titleContainerView.frame.maxY + 10).toMaxY(submitButton.frame.origin.y - 10)
    }

    @objc private func handleCancelButton() {
        needExit?()
    }

    @objc private func handleSubmitButton() {
        didClickSubmitButton()
    }

    func didClickSubmitButton() {
        assertionFailure("should implement by subclass")
    }
}
