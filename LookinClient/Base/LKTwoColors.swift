//
//  LKTwoColors.swift
//  Lookin
//
//  Created by Li Kai on 2019/9/30.
//  https://lookin.work
//

import AppKit

class LKTwoColors: NSObject {
    static func colors(withColorInLightMode colorInLightMode: NSColor, colorInDarkMode: NSColor) -> LKTwoColors {
        let colors = LKTwoColors()
        colors.colorInLightMode = colorInLightMode
        colors.colorInDarkMode = colorInDarkMode
        return colors
    }

    var colorInLightMode: NSColor?
    var colorInDarkMode: NSColor?

    var color: NSColor? {
        return LookinClientIsDarkMode() ? colorInDarkMode : colorInLightMode
    }
}
