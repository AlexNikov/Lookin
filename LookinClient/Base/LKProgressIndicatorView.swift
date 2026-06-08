//
//  LKProgressIndicatorView.swift
//  Lookin
//
//  Created by Li Kai on 2018/10/7.
//  https://lookin.work
//

import AppKit

let InitialIndicatorProgressWhenFetchHierarchy: CGFloat = 0.7

class LKProgressIndicatorView: LKBaseView {
    @objc private(set) dynamic var progress: CGFloat = 0 {
        didSet { updateFillLayer() }
    }

    private var fillLayer: CALayer!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        fillLayer = CALayer()
        fillLayer.backgroundColor = LKHelper.accentColor().cgColor
        layer?.addSublayer(fillLayer)
        fillLayer.lookin_removeImplicitAnimations()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        updateFillLayer()
    }

    override func animation(forKey key: NSAnimatablePropertyKey) -> Any? {
        if key == "progress" {
            return CABasicAnimation()
        }
        return super.animation(forKey: key)
    }

    private func updateFillLayer() {
        lk(fillLayer).x(0).width(bounds.width * progress).height(bounds.height).y(0)
    }

    func resetToZero() {
        progress = 0
    }

    func animate(toProgress progress: CGFloat) {
        animate(toProgress: progress, duration: 0.5)
    }

    func animate(toProgress progress: CGFloat, duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            self.animator().progress = progress
        })
    }

    func finish(completion completionBlock: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            self.animator().progress = 1
        }, completionHandler: {
            completionBlock?()
            DispatchQueue.main.asyncAfter(deadline: .now() + LKUITiming.brief) {
                self.progress = 0
            }
        })
    }
}
