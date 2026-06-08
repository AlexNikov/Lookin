//
//  LKMeasureTutorialView.swift
//  Lookin
//
//  Created by Li Kai on 2019/10/21.
//  https://lookin.work
//

import AppKit
import LookinShared

class LKMeasureTutorialView: LKBaseView {
    private var imageView: NSImageView!
    private var titleLabel: LKLabel!
    private var subtitleLabel: LKLabel!

    private let insets = NSEdgeInsets(top: 15, left: 5, bottom: 12, right: 5)
    private let titleTop: CGFloat = 11
    private let subtitleTop: CGFloat = 6

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        hasEffectedBackground = true
        layer?.cornerRadius = DashboardCardCornerRadius

        imageView = NSImageView()
        addSubview(imageView)

        titleLabel = LKLabel()
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.alignment = .center
        addSubview(titleLabel)

        subtitleLabel = LKLabel()
        subtitleLabel.font = NSFontMake(12)
        subtitleLabel.alignment = .center
        addSubview(subtitleLabel)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func render(image: NSImage?, title: String, subtitle: String) {
        imageView.image = image
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        needsLayout = true
    }

    override func layout() {
        super.layout()
        lk(imageView).sizeToFit().horAlign().y(insets.top)
        lk(titleLabel).sizeToFit().horAlign().y(imageView.frame.maxY + titleTop)
        lk(subtitleLabel).x(insets.left).toRight(insets.right).heightToFit().y(titleLabel.frame.maxY + subtitleTop)
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        let contentWidth = size.width - insets.left - insets.right
        var resultHeight = insets.top + insets.bottom
        resultHeight += imageView.sizeThatFits(NSSize(width: contentWidth, height: .greatestFiniteMagnitude)).height
        resultHeight += titleTop
        resultHeight += titleLabel.heightForWidth(contentWidth)
        resultHeight += subtitleTop
        resultHeight += subtitleLabel.heightForWidth(contentWidth)
        size.height = resultHeight
        return size
    }
}
