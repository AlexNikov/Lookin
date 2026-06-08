//
//  LKImageTextView.swift
//  Lookin
//
//  Created by Li Kai on 2019/6/19.
//  https://lookin.work
//

import AppKit

class LKImageTextView: LKBaseView {
    private(set) var imageView: NSImageView!
    private(set) var label: LKLabel!
    var imageMargins = HorizontalMarginsMake(0, 0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView = NSImageView()
        addSubview(imageView)
        label = LKLabel()
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        lk(imageView).sizeToFit().x(imageMargins.left).verAlign()
        lk(label).x(imageView.frame.maxX + imageMargins.right).toRight(0).heightToFit().verAlign()
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        let labelSize = label.sizeThatFits(NSSizeMax)
        var size = limitedSize
        size.width = imageMargins.left + (imageView.image?.size.width ?? 0) + imageMargins.right + labelSize.width
        size.height = max(imageView.image?.size.height ?? 0, labelSize.height)
        return size
    }
}
