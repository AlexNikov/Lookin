//
//  LKPopPanel.swift
//  Lookin
//
//  Created by Li Kai on 2019/9/28.
//  https://lookin.work
//

import AppKit
import LookinShared

class LKPopPanel: NSPanel {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: .nonactivatingPanel,
                   backing: .buffered,
                   defer: true)
        let contentView = LKBaseView()
        contentView.layer?.cornerRadius = 6
        contentView.layer?.borderWidth = 1
        contentView.didChangeAppearanceBlock = { view, isDarkMode in
            view.backgroundColor = isDarkMode ? LookinColorMake(44, 44, 44) : LookinColorMake(236, 236, 236)
            view.layer?.borderColor = isDarkMode ? SeparatorDarkModeColor.cgColor : SeparatorLightModeColor.cgColor
        }
        self.contentView = contentView
        backgroundColor = .clear
    }

    override var canBecomeKey: Bool { true }
}
