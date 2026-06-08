//
//  LKSplitView.swift
//  Lookin
//
//  Created by Li Kai on 2018/11/4.
//  https://lookin.work
//

import AppKit

class LKSplitView: NSSplitView {
    var didFinishFirstLayout: ((LKSplitView) -> Void)?
    private var hasLayouted = false

    override var dividerThickness: CGFloat { 0 }

    override func layout() {
        super.layout()
        guard !hasLayouted else { return }
        if let didFinishFirstLayout, isVertical {
            let minWidth = HierarchyMinWidth + DashboardViewWidth + 100
            guard bounds.width >= minWidth else { return }
            didFinishFirstLayout(self)
        } else if didFinishFirstLayout != nil {
            didFinishFirstLayout?(self)
        }
        hasLayouted = true
    }
}
