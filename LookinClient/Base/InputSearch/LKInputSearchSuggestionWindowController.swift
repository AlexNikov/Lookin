//
//  LKInputSearchSuggestionWindowController.swift
//  Lookin
//
//  Created by Li Kai on 2019/6/2.
//  https://lookin.work
//

import AppKit

class LKInputSearchSuggestionWindowController: LKWindowController {
    var suggestionsView: LKInputSearchSuggestionsContentView!

    convenience init() {
        let view = LKInputSearchSuggestionsContentView()
        let suggestionPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.utilityWindow],
            backing: .buffered,
            defer: true
        )
        suggestionPanel.contentView = view
        suggestionPanel.isFloatingPanel = true
        suggestionPanel.becomesKeyOnlyIfNeeded = true
        suggestionPanel.backgroundColor = .clear
        self.init(window: suggestionPanel)
        suggestionsView = view
    }
}
