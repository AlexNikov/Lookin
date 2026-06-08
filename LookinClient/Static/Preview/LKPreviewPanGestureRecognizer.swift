//
//  LKPreviewPanGestureRecognizer.swift
//  Lookin
//
//  Created by Li Kai on 2018/8/31.
//  https://lookin.work
//

import AppKit

enum PreviewPanGesturePurpose: UInt {
    case rotate
    case translate
}

final class LKPreviewPanGestureRecognizer: NSPanGestureRecognizer {
    var purpose: PreviewPanGesturePurpose = .rotate
    var initialRotation: CGPoint = .zero
    var initialTranslation: NSPoint = .zero
}
