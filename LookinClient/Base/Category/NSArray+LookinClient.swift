//
//  NSArray+LookinClient.swift
//  Lookin
//
//  Created by Li Kai on 2019/8/14.
//  https://lookin.work
//

import AppKit

extension NSArray {
    func lk_visibleViews() -> [Any] {
        lookin_filter { obj in
            if let view = obj as? NSView {
                return !view.isHidden
            }
            assertionFailure()
            return false
        } as? [Any] ?? []
    }
}
