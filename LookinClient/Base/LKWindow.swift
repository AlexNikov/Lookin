//
//  LKWindow.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/14.
//  https://lookin.work
//

import AppKit

class LKWindow: NSWindow, NSDraggingDestination {
    static func panelWindow(withWidth width: CGFloat, height: CGFloat, contentView: LKPanelContentView) -> LKWindow {
        let window = LKWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: .titled,
                              backing: .buffered,
                              defer: true)
        window.contentView = contentView
        return window
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        registerForDraggedTypes([.fileURL])
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let path = NSURL(from: sender.draggingPasteboard)?.path else { return false }
        var error: NSError?
        let isSucc = LKNavigationManager.sharedInstance.showReader(withFilePath: path, error: &error)
        if !isSucc, let error {
            AlertError(error, self)
        }
        return isSucc
    }
}
