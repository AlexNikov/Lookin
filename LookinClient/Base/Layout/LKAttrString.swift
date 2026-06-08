//
//  LKAttrString.swift
//  Lookin
//

import AppKit
import Foundation

enum LKAttrStyle {
    case plain
    case searchMethodLink
    case searchRevealLink
    case dashboardAlias
    case dashboardListItem
}

struct LKAttrString {
    private var storage: NSMutableAttributedString

    init(_ text: String, style: LKAttrStyle = .plain) {
        storage = LKAttrStringConversion.attributedString(from: text)
        if style != .plain {
            self = applyingStyle(style)
        }
    }

    init(_ attributed: NSAttributedString) {
        storage = attributed.mutableCopy() as? NSMutableAttributedString ?? NSMutableAttributedString()
    }

    private init(storage: NSMutableAttributedString) {
        self.storage = storage
    }

    func build() -> NSAttributedString {
        storage.copy() as? NSAttributedString ?? NSAttributedString()
    }

    func font(size: CGFloat) -> LKAttrString {
        applyingAttribute(.font, value: LKAttrStringConversion.font(size: size))
    }

    func font(_ font: NSFont) -> LKAttrString {
        applyingAttribute(.font, value: font)
    }

    func textColor(_ color: NSColor) -> LKAttrString {
        applyingAttribute(.foregroundColor, value: color)
    }

    func textColor(named: String) -> LKAttrString {
        guard let color = NSColor(named: named) else { return self }
        return textColor(color)
    }

    func textColor(rgb: String) -> LKAttrString {
        guard let color = LKAttrStringConversion.color(fromRGB: rgb) else { return self }
        return textColor(color)
    }

    func textColor(rgb pair: LookinRGBPair) -> LKAttrString {
        guard let color = pair.resolvedColor() else { return self }
        return textColor(color)
    }

    func lineHeight(_ value: CGFloat) -> LKAttrString {
        guard storage.length > 0 else { return self }
        let copy = self
        let paraStyle = LKAttrStringConversion.paragraphStyle(for: storage)
        paraStyle.minimumLineHeight = value
        paraStyle.maximumLineHeight = value
        copy.storage.addAttribute(.paragraphStyle, value: paraStyle.copy(), range: copy.fullRange)
        return copy
    }

    func addImage(named: String, baseline: CGFloat, left: CGFloat, right: CGFloat) -> LKAttrString {
        guard let image = LKAttrStringConversion.image(named: named),
              let attachment = attributedString(with: image, baselineOffset: baseline, leftMargin: left, rightMargin: right) else {
            return self
        }
        let copy = self
        copy.storage.append(attachment)
        return copy
    }

    func highlight(
        _ substring: String,
        options: NSString.CompareOptions = .caseInsensitive,
        attributes: [NSAttributedString.Key: Any]
    ) -> LKAttrString {
        let copy = self
        let range = (copy.storage.string as NSString).range(of: substring, options: options)
        if range.location != NSNotFound {
            copy.storage.addAttributes(attributes, range: range)
        }
        return copy
    }

    private var fullRange: NSRange {
        NSRange(location: 0, length: storage.length)
    }

    private func applyingAttribute(_ key: NSAttributedString.Key, value: Any?) -> LKAttrString {
        guard storage.length > 0, let value else { return self }
        let copy = self
        copy.storage.addAttribute(key, value: value, range: copy.fullRange)
        return copy
    }

    private func applyingStyle(_ style: LKAttrStyle) -> LKAttrString {
        switch style {
        case .plain:
            return self
        case .searchMethodLink:
            return font(size: 13)
                .textColor(rgb: "74, 144, 226")
                .addImage(named: "icon_arrowRight_blue", baseline: -1, left: 2, right: 0)
        case .searchRevealLink:
            return font(size: 11)
                .textColor(rgb: LookinRGBPair(light: "229, 135, 67", dark: "245, 166, 30"))
                .addImage(named: "icon_arrowRight_orange", baseline: 0, left: 2, right: 0)
        case .dashboardAlias:
            return font(NSFontMake(11)).lineHeight(18)
        case .dashboardListItem:
            return textColor(.labelColor).font(NSFontMake(12)).lineHeight(18)
        }
    }

    private func attributedString(
        with image: NSImage,
        baselineOffset: CGFloat,
        leftMargin: CGFloat,
        rightMargin: CGFloat
    ) -> NSAttributedString? {
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        guard let string = NSAttributedString(attachment: attachment).mutableCopy() as? NSMutableAttributedString else {
            return nil
        }
        string.addAttribute(.baselineOffset, value: baselineOffset, range: NSRange(location: 0, length: string.length))
        if leftMargin > 0, let space = fixedSpaceAttachment(width: leftMargin) {
            string.insert(space, at: 0)
        }
        if rightMargin > 0, let space = fixedSpaceAttachment(width: rightMargin) {
            string.append(space)
        }
        return string
    }

    private func fixedSpaceAttachment(width: CGFloat) -> NSAttributedString? {
        let image = NSImage(size: NSSize(width: width, height: 1))
        return attributedString(with: image, baselineOffset: 0, leftMargin: 0, rightMargin: 0)
    }
}
