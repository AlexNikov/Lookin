//
//  LookinDisplayItem+LookinClient.swift
//  LookinClient
//
//  Created by likaimacbookhome on 2023/11/1.
//  Copyright © 2023 hughkli. All rights reserved.
//

import AppKit
import LookinShared

extension LookinDisplayItem {
    func title() -> String? {
        if let customInfo {
            return customInfo.title
        }
        if (customDisplayTitle?.count ?? 0) > 0 {
            return customDisplayTitle
        }
        if let viewObject {
            return viewObject.lk_simpleDemangledClassName
        }
        if let layerObject {
            return layerObject.lk_simpleDemangledClassName
        }
        return nil
    }

    func subtitle() -> String? {
        if customInfo != nil {
            return customInfo?.subtitle
        }

        let text = hostViewControllerObject?.lk_simpleDemangledClassName ?? ""
        if !text.isEmpty {
            return "\(text).view"
        }

        let representedObject = viewObject ?? layerObject
        guard let representedObject else { return nil }

        if (representedObject.specialTrace?.count ?? 0) > 0 {
            return representedObject.specialTrace
        }

        if let ivarTraces = representedObject.ivarTraces, !ivarTraces.isEmpty {
            let ivarNameList = ivarTraces.compactMap(\.ivarName)
            var seen = Set<String>()
            let unique = ivarNameList.filter { seen.insert($0).inserted }
            return unique.sorted().joined(separator: "   ")
        }

        return nil
    }

    var representedForSystemClass: Bool {
        guard let title = title() else { return false }
        return title.hasPrefix("UI") || title.hasPrefix("CA") || title.hasPrefix("_")
    }

    func appropriateScreenshot() -> NSImage? {
        if isExpandable && isExpanded {
            return soloScreenshot
        }
        return groupScreenshot
    }

    func isUserCustom() -> Bool {
        customInfo != nil
    }

    func hasPreviewBoxAbility() -> Bool {
        guard customInfo != nil else { return true }
        return customInfo?.hasValidFrame() ?? false
    }

    func hasValidFrameToRoot() -> Bool {
        if let customInfo {
            return customInfo.hasValidFrame()
        }
        return LKHelper.validateFrame(frame)
    }

    func calculateFrameToRoot() -> CGRect {
        if let customInfo, let frameValue = customInfo.frameInWindow {
            return frameValue.rectValue
        }
        guard let superItem else {
            return frame
        }
        let superFrameToRoot = superItem.calculateFrameToRoot()
        let superBounds = superItem.bounds
        let selfFrame = frame

        let x = selfFrame.origin.x - superBounds.origin.x + superFrameToRoot.origin.x
        let y = selfFrame.origin.y - superBounds.origin.y + superFrameToRoot.origin.y
        return CGRect(x: x, y: y, width: selfFrame.width, height: selfFrame.height)
    }

    func isMatched(withSearchString string: String) -> Bool {
        guard !string.isEmpty else {
            assertionFailure()
            return false
        }
        let searchString = string.lowercased()
        if let title = title()?.lowercased(), title.contains(searchString) {
            return true
        }
        if let subtitle = subtitle()?.lowercased(), subtitle.contains(searchString) {
            return true
        }
        if viewObject?.memoryAddress?.lowercased().contains(searchString) == true {
            return true
        }
        if layerObject?.memoryAddress?.lowercased().contains(searchString) == true {
            return true
        }
        return false
    }

    func enumerateSelfAndAncestors(_ block: ((LookinDisplayItem, UnsafeMutablePointer<ObjCBool>) -> Void)?) {
        guard let block else { return }
        var item: LookinDisplayItem? = self
        while let current = item {
            var shouldStop: ObjCBool = false
            block(current, &shouldStop)
            if shouldStop.boolValue { break }
            item = current.superItem
        }
    }

    func enumerateAncestors(_ block: ((LookinDisplayItem, UnsafeMutablePointer<ObjCBool>) -> Void)?) {
        superItem?.enumerateSelfAndAncestors(block)
    }

    func enumerateSelfAndChildren(_ block: ((LookinDisplayItem) -> Void)?) {
        guard let block else { return }
        block(self)
        for subitem in subitems ?? [] {
            subitem.enumerateSelfAndChildren(block)
        }
    }

    func itemIsKindOfClass(withName className: String?) -> Bool {
        guard let className else {
            assertionFailure()
            return false
        }
        return itemIsKindOfClasses(withNames: Set([className]))
    }

    func itemIsKindOfClasses(withNames targetClassNames: Set<String>) -> Bool {
        guard !targetClassNames.isEmpty else { return false }
        guard let selfObj = viewObject ?? layerObject else { return false }

        for targetClassName in targetClassNames {
            for selfClass in selfObj.classChainList ?? [] {
                let nonPrefixSelfClass = (selfClass as NSString).components(separatedBy: ".").last ?? selfClass
                if nonPrefixSelfClass == targetClassName {
                    return true
                }
            }
        }
        return false
    }
}
