//
//  LKLabel.swift
//  Lookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//

import AppKit

class LKLabel: NSTextField {
    var textColors: LKTwoColors? {
        didSet { updateColors() }
    }

    var backgroundColors: LKTwoColors? {
        didSet { updateColors() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        backgroundColor = .clear
        isBezeled = false
        drawsBackground = true
        isEditable = false
        isSelectable = false
        updateColors()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var stringValue: String {
        get { super.stringValue }
        set { super.stringValue = newValue }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        if let textColors {
            textColor = textColors.color
        }
        if let backgroundColors {
            backgroundColor = backgroundColors.color
        }
    }
}
