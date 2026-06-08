//
//  LKVerifyCustomInfoLogger.swift
//  LookinClient
//

import Foundation
import LookinShared

enum LKVerifyCustomInfoLogger {
    private static let logFile: FileHandle? = {
        let path = ProcessInfo.processInfo.environment["LOOKIN_VERIFY_LOG"] ?? "/tmp/lookin-verify-custominfo.log"
        FileManager.default.createFile(atPath: path, contents: nil)
        return FileHandle(forWritingAtPath: path)
    }()

    private static func logLine(_ line: String) {
        NSLog("%@", line)
        guard let data = (line + "\n").data(using: .utf8) else { return }
        logFile?.seekToEndOfFile()
        logFile?.write(data)
    }

    private static func valueSummary(for attr: LookinAttribute) -> String {
        guard let value = attr.value else { return "nil" }
        var desc = "\(value)"
        if desc.count > 120 {
            desc = String(desc.prefix(120)) + "…"
        }
        return desc
    }

    static func logHierarchyReload(
        flatItems: [LookinDisplayItem],
        displayingCount: Int,
        selectedItem: LookinDisplayItem?
    ) {
        var customSubviewLines: [String] = []
        var customAttrLines: [String] = []
        var customSubviewCount = 0
        var customAttrItemCount = 0

        for obj in flatItems {
            if obj.isUserCustom() {
                customSubviewCount += 1
                let title = obj.customInfo?.title ?? ""
                let subtitle = obj.customInfo?.subtitle ?? ""
                let validFrame = obj.hasValidFrameToRoot()
                let frame = obj.calculateFrameToRoot()
                customSubviewLines.append(
                    "LookinVerify - customSubview: title=\(title) subtitle=\(subtitle) validFrame=\(validFrame ? "1" : "0") frame=\(NSStringFromRect(frame))"
                )
            }

            for group in obj.customAttrGroupList ?? [] {
                let itemTitle = obj.title() ?? ""
                let groupTitle = (group.userCustomTitle?.isEmpty == false) ? (group.userCustomTitle ?? "") : (group.identifier ?? "")
                for section in group.attrSections ?? [] {
                    for attr in section.attributes ?? [] {
                        customAttrItemCount += 1
                        let attrTitle = (attr.displayTitle?.isEmpty == false) ? (attr.displayTitle ?? "") : (attr.identifier ?? "")
                        customAttrLines.append(
                            "LookinVerify - customAttr: item=\(itemTitle) group=\(groupTitle) attr=\(attrTitle) type=\(attr.attrType.rawValue) value=\(valueSummary(for: attr))"
                        )
                    }
                }
            }
        }

        let selectedTitle = selectedItem?.title() ?? ""
        logLine(
            "LookinVerify - hierarchy reload: flatCount=\(flatItems.count) customSubviewCount=\(customSubviewCount) customAttrCount=\(customAttrItemCount) displayingCount=\(displayingCount) selectedTitle=\(selectedTitle)"
        )

        for line in customSubviewLines.sorted() {
            logLine(line)
        }
        for line in customAttrLines.sorted() {
            logLine(line)
        }
    }

    static func logDetailModify(detail: LookinDisplayItemDetail, displayItem: LookinDisplayItem) {
        let itemTitle = displayItem.title() ?? ""
        let customGroupCount = detail.customAttrGroupList?.count ?? 0
        let builtinGroupCount = detail.attributesGroupList?.count ?? 0
        let subitemCount = detail.subitems?.count ?? 0

        logLine(
            "LookinVerify - detail modify: item=\(itemTitle) oid=\(detail.displayItemOid) customGroups=\(customGroupCount) builtinGroups=\(builtinGroupCount) subitems=\(subitemCount)"
        )

        var customAttrLines: [String] = []
        for group in detail.customAttrGroupList ?? [] {
            let groupTitle = (group.userCustomTitle?.isEmpty == false) ? (group.userCustomTitle ?? "") : (group.identifier ?? "")
            for section in group.attrSections ?? [] {
                for attr in section.attributes ?? [] {
                    let attrTitle = (attr.displayTitle?.isEmpty == false) ? (attr.displayTitle ?? "") : (attr.identifier ?? "")
                    customAttrLines.append(
                        "LookinVerify - customAttr: item=\(itemTitle) group=\(groupTitle) attr=\(attrTitle) type=\(attr.attrType.rawValue) value=\(valueSummary(for: attr))"
                    )
                }
            }
        }
        for line in customAttrLines.sorted() {
            logLine(line)
        }
    }

    static func logAsyncUpdate(_ message: String) {
        logLine("LookinVerify - asyncUpdate: \(message)")
    }
}
