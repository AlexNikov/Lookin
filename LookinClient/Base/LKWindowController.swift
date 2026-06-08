//
//  LKWindowController.swift
//  Lookin
//
//  Created by Li Kai on 2019/4/18.
//  https://lookin.work
//

import AppKit

class LKWindowController: NSWindowController, LKAppMenuManagerDelegate {
    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        NSLog("%@ dealloc", String(describing: type(of: self)))
    }
}
