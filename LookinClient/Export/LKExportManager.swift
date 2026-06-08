//
//  LKExportManager.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//

import AppKit
import LookinShared

class LKExportManager: NSObject {
    static let sharedInstance: LKExportManager = {
        LKExportManager()
    }()

    func data(from info: LookinHierarchyInfo, imageCompression compression: CGFloat, fileName: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Data? {
        let file = LookinHierarchyFile()
        file.serverVersion = info.serverVersion
        file.hierarchyInfo = info

        var soloScreenshots: [NSNumber: Data] = [:]
        var groupScreenshots: [NSNumber: Data] = [:]

        let allItems = LookinDisplayItem.flatItems(fromHierarchicalItems: info.displayItems ?? [])
        for displayItem in allItems {
            guard let layerObject = displayItem.layerObject else { continue }
            displayItem.screenshotEncodeType = .none
            let oid = NSNumber(value: layerObject.oid)
            soloScreenshots[oid] = compressedData(from: displayItem.soloScreenshot, compression: compression)
            groupScreenshots[oid] = compressedData(from: displayItem.groupScreenshot, compression: compression)
        }
        file.soloScreenshots = soloScreenshots
        file.groupScreenshots = groupScreenshots

        let document = LookinDocument()
        document.hierarchyFile = file
        let exportedData: Data?
        do {
            exportedData = try document.data(ofType: "com.lookin.lookin")
        } catch {
            assertionFailure()
            exportedData = nil
        }

        if let fileName, let appInfo = info.appInfo {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMddHHmm"
            let timeString = formatter.string(from: Date())
            var iOSVersion = appInfo.osDescription ?? ""
            if let dotIdx = iOSVersion.firstIndex(of: ".") {
                iOSVersion = String(iOSVersion[..<dotIdx])
            }
            fileName.pointee = "\(appInfo.appName ?? "")_ios\(iOSVersion)_\(timeString).lookin" as NSString
        }

        return exportedData
    }

    private func compressedData(from sourceImage: LookinImage?, compression: CGFloat) -> Data? {
        guard let sourceImage else { return nil }
        let compression = max(min(compression, 1), 0.01)
        let targetSize = NSSize(width: sourceImage.size.width * compression, height: sourceImage.size.height * compression)
        let targetFrame = NSRect(origin: .zero, size: targetSize)
        guard let sourceImageRep = sourceImage.bestRepresentation(for: targetFrame, context: nil, hints: nil) else {
            return nil
        }
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        sourceImageRep.draw(in: targetFrame)
        resizedImage.unlockFocus()
        guard let imageRep = NSBitmapImageRep(data: resizedImage.tiffRepresentation!) else { return nil }
        return imageRep.tiffRepresentation(using: .lzw, factor: 1)
    }

    static func exportScreenshot(with displayItem: LookinDisplayItem) {
        guard let image = displayItem.groupScreenshot else {
            AlertError(LKLookinClientErrors.inner, CurrentKeyWindow)
            return
        }
        guard let imageData = image.tiffRepresentation(using: .lzw, factor: 1) else {
            AlertError(LKLookinClientErrors.inner, CurrentKeyWindow)
            return
        }
        let fileName = displayItem.title() ?? "LookinImage"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.allowsOtherFileTypes = false
        panel.allowedFileTypes = ["tiff"]
        panel.isExtensionHidden = true
        panel.canCreateDirectories = true
        guard let window = CurrentKeyWindow else { return }
        panel.beginSheetModal(for: window) { result in
            if result == .OK, let path = panel.url?.path {
                do {
                    try imageData.write(to: URL(fileURLWithPath: path))
                } catch {
                    AlertError(error as NSError, CurrentKeyWindow)
                    assertionFailure()
                }
            }
        }
    }
}
