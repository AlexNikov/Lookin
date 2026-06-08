//
//  LKColorIndicatorLayer.swift
//  Lookin
//
//  Created by Li Kai on 2019/1/19.
//  https://lookin.work
//

import AppKit
import LookinShared

class LKColorIndicatorLayer: CALayer {
    var color: NSColor? = LookinColorMake(0, 0, 0) {
        didSet { applyColor() }
    }

    private var imageLayer: CALayer?
    private var colorLayer: CALayer!

    override init() {
        super.init()
        lookin_removeImplicitAnimations()
        borderWidth = 1

        colorLayer = CALayer()
        colorLayer.backgroundColor = color?.cgColor
        colorLayer.lookin_removeImplicitAnimations()
        addSublayer(colorLayer)
        masksToBounds = true
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyColor() {
        if let color {
            if color.alphaComponent < 1 {
                createImageLayerIfNeeded()
                imageLayer?.isHidden = false
                imageLayer?.contents = NSImageMake("Transparent_Background")
            } else {
                imageLayer?.isHidden = true
            }
        } else {
            createImageLayerIfNeeded()
            imageLayer?.isHidden = false
            imageLayer?.contents = NSImageMake("Nil_Color_Image")
        }
        colorLayer.backgroundColor = color?.cgColor
        borderColor = contrastColor(for: color).cgColor
    }

    private func contrastColor(for color: NSColor?) -> NSColor {
        guard let color else { return LookinColorMake(191, 191, 191) }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let newBrightness = brightness > 0.5 ? brightness - 0.2 : brightness + 0.2
        let newAlpha = min(1, alpha + 0.3)
        return NSColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: newAlpha)
    }

    private func createImageLayerIfNeeded() {
        guard imageLayer == nil else { return }
        let layer = CALayer()
        layer.lookin_removeImplicitAnimations()
        insertSublayer(layer, at: 0)
        imageLayer = layer
        setNeedsLayout()
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        lk(imageLayer, colorLayer).visibles().fullFrame()
        cornerRadius = min(bounds.width, bounds.height) / 2.0
    }

    static func image(with color: NSColor?, shapeSize: NSSize, insets: NSEdgeInsets) -> NSImage {
        let layer = LKColorIndicatorLayer()
        let image = NSImage(size: NSSize(
            width: shapeSize.width + insets.left + insets.right,
            height: shapeSize.height + insets.top + insets.bottom
        ))
        image.lockFocus()
        layer.frame = NSRect(origin: .zero, size: shapeSize)
        layer.color = color ?? LookinColorMake(0, 0, 0)
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.translateBy(x: insets.left, y: insets.top)
            layer.render(in: ctx)
        }
        image.unlockFocus()
        return image
    }
}
