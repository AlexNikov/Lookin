//
//  LKImageControl.swift
//  Lookin
//
//  Created by Li Kai on 2018/9/1.
//  https://lookin.work
//

import AppKit

class LKImageControl: LKBaseControl {
    var imageView: NSImageView!
    var image: NSImage? {
        didSet {
            imageView.image = image
            needsLayout = true
        }
    }

    static func button(withImage image: NSImage?) -> LKImageControl {
        let button = LKImageControl()
        button.image = image
        return button
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView = NSImageView()
        imageView.wantsLayer = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
        imageView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        imageView.layer?.frame = imageView.frame
    }

    override func sizeThatFits(_ size: NSSize) -> NSSize {
        imageView.image?.size ?? .zero
    }
}
