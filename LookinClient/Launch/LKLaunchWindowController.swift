//
//  LKLaunchWindowController.swift
//  Lookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//

import AppKit

class LKLaunchWindowController: LKWindowController {
    private(set) var launchViewController: LKLaunchViewController!

    convenience init() {
        let window = LKWindow(
            contentRect: NSRect(x: 0, y: 0, width: 252, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()

        self.init(window: window)

        window.setAccessibilityIdentifier("lookin.launch.window")

        launchViewController = LKLaunchViewController(window: window)
        window.contentView = launchViewController.view
        contentViewController = launchViewController
    }
}
