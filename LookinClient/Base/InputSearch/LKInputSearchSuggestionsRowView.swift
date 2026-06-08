//
//  LKInputSearchSuggestionsRowView.swift
//  Lookin
//
//  Created by Li Kai on 2019/6/3.
//  https://lookin.work
//

import AppKit

class LKInputSearchSuggestionsRowView: NSTableRowView {
    private(set) var titleLabel: LKLabel!
    private(set) var imageView: NSImageView!

    private let horInset: CGFloat = 10
    private let titleLeft: CGFloat = 5

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView = NSImageView()
        addSubview(imageView)

        titleLabel = LKLabel()
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.font = NSFontMake(14)
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        lk(imageView).sizeToFit().x(horInset).verAlign()
        lk(titleLabel)
            .x(imageView.frame.maxX + titleLeft)
            .toRight(horInset)
            .lookin_heightToFit()
            .verAlign()
            .offsetY(-1)
    }

    func bestWidth() -> CGFloat {
        horInset * 2 + (imageView.image?.size.width ?? 0) + titleLeft + titleLabel.sizeThatFits(NSSizeMax).width
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        let color = NSAppearance.current?.lk_isDarkMode == true
            ? LKHelper.accentColor()
            : LookinColorRGBAMake(0, 0, 0, 0.24)
        color.setFill()
        NSBezierPath(rect: bounds).fill()
    }
}
