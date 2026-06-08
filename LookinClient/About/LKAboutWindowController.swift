//
//  LKAboutWindowController.swift
//  LookinClient
//
//  Created by 李凯 on 2019/10/30.
//  Copyright © 2019 hughkli. All rights reserved.
//

import AppKit

class LKAboutWindowController: LKWindowController {
    convenience init() {
        let width: CGFloat = 500
        let height = width * 0.54
        let window = LKWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.isMovableByWindowBackground = true
        window.center()
        self.init(window: window)
        let vc = LKAboutViewController(containerView: nil)
        window.contentView = vc.view
        contentViewController = vc
    }
}
