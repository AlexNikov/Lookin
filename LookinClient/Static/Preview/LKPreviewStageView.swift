//
//  LKPreviewStageView.swift
//  Lookin
//
//  Created by Li Kai on 2018/8/6.
//  https://lookin.work
//

import AppKit

protocol LKPreviewStageViewDelegate: AnyObject {
    func previewStageView(_ view: LKPreviewStageView, mouseMoved event: NSEvent)
    func previewStageView(_ view: LKPreviewStageView, mouseExited event: NSEvent)
    func didResetCursorRects(in previewStageView: LKPreviewStageView)
}

final class LKPreviewStageView: LKBaseView {
    weak var delegate: LKPreviewStageViewDelegate?

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        delegate?.previewStageView(self, mouseMoved: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        delegate?.previewStageView(self, mouseExited: event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for oldArea in trackingAreas {
            removeTrackingArea(oldArea)
        }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newArea)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        delegate?.didResetCursorRects(in: self)
    }
}
