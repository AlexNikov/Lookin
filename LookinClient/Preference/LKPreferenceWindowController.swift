//
//  LKPreferenceWindowController.swift
//  Lookin
//
//  Created by Li Kai on 2019/1/4.
//  https://lookin.work
//

import AppKit

class LKPreferenceWindowController: LKWindowController {
    convenience init() {
        let window = LKWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        window.isMovableByWindowBackground = true
        window.title = NSLocalizedString("Preferences", comment: "")
        window.center()
        self.init(window: window)
        let vc = LKPreferenceViewController()
        window.contentView = vc.view
        contentViewController = vc
    }
}
