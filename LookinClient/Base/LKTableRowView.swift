//
//  LKTableRowView.swift
//  Lookin
//
//  Created by Li Kai on 2019/4/20.
//  https://lookin.work
//

import AppKit
import LookinShared

class LKTableRowView: NSTableRowView {
    private(set) var titleLabel: LKLabel!
    private(set) var subtitleLabel: LKLabel!
    private var backgroundColorLayer: CALayer!

    private var _lookinSelected = false
    private var _lookinHovered = false
    private var _isDarkMode = false

    override var isSelected: Bool {
        get { _lookinSelected }
        set {
            _lookinSelected = newValue
            updateBackgroundLayerColor()
        }
    }

    var isHovered: Bool {
        get { _lookinHovered }
        set {
            _lookinHovered = newValue
            updateBackgroundLayerColor()
        }
    }

    var isDarkMode: Bool {
        _isDarkMode
    }

    weak var horizontalScrollWidthManager: LKTableViewHorizontalScrollWidthManager?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        backgroundColorLayer = CALayer()
        backgroundColorLayer.lookin_removeImplicitAnimations()
        layer?.addSublayer(backgroundColorLayer)

        titleLabel = LKLabel()
        titleLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        subtitleLabel = LKLabel()
        addSubview(subtitleLabel)

        _isDarkMode = effectiveAppearance.lk_isDarkMode
        updateBackgroundLayerColor()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        lk(backgroundColorLayer).fullFrame()
    }

    override var isFlipped: Bool { true }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        _isDarkMode = effectiveAppearance.lk_isDarkMode
        updateBackgroundLayerColor()
    }

    func setIsDarkMode(_ isDarkMode: Bool) {
        _isDarkMode = isDarkMode
        updateBackgroundLayerColor()
    }

    private func updateBackgroundLayerColor() {
        if _lookinSelected {
            backgroundColorLayer.backgroundColor = LKHelper.accentColor().cgColor
        } else if _lookinHovered {
            backgroundColorLayer.backgroundColor = _isDarkMode
                ? LookinColorRGBAMake(255, 255, 255, 0.15).cgColor
                : LookinColorRGBAMake(0, 0, 0, 0.1).cgColor
        } else {
            backgroundColorLayer.backgroundColor = NSColor.clear.cgColor
        }
    }
}

class LKTableBlankRowView: LKTableRowView {}
