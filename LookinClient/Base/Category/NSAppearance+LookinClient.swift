//
//  NSAppearance+LookinClient.swift
//  Lookin
//
//  Created by Li Kai on 2019/3/4.
//  https://lookin.work
//

import AppKit

extension NSAppearance {
    var lk_isDarkMode: Bool {
        if #available(macOS 10.14, *) {
            let darkNames: Set<NSAppearance.Name> = [
                .darkAqua,
                .vibrantDark,
                .accessibilityHighContrastDarkAqua,
                .accessibilityHighContrastVibrantDark,
            ]
            return darkNames.contains(name)
        }
        return false
    }
}
