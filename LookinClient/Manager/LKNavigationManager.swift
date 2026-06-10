//
//  LKNavigationManager.swift
//  Lookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//

import AppKit
import LookinShared

class LKNavigationManager: NSObject, NSWindowDelegate {
    private static let _lookinShared = LKNavigationManager()
    static let sharedInstance = _lookinShared

    private(set) var launchWindowController: LKLaunchWindowController?
    private(set) var staticWindowController: LKStaticWindowController?
    var readWindowControllers = NSMutableArray()

    var windowTitleBarHeight: CGFloat = 0

    private var preferenceWindowController: LKPreferenceWindowController?
    private var jsonWindowController: LKJSONAttributeWindowController?
    private var aboutWindowController: LKAboutWindowController?

    private override init() {
        super.init()
    }

    func showLaunch() {
        // End inspect only when leaving the static workspace (avoid killing Peertalk during launch polling).
        if staticWindowController?.window?.isVisible == true {
            LKAppsManager.sharedInstance.endInspectingSession()
            staticWindowController?.close()
        }
        launchWindowController = LKLaunchWindowController()
        launchWindowController?.showWindow(self)
    }

    func showStaticWorkspace() {
        if staticWindowController == nil {
            staticWindowController = LKStaticWindowController()
            staticWindowController?.window?.delegate = self
        }
        staticWindowController?.showWindow(self)
    }

    func closeLaunch() {
        launchWindowController?.close()
        launchWindowController = nil
    }

    func showPreference() {
        if preferenceWindowController == nil {
            preferenceWindowController = LKPreferenceWindowController()
            preferenceWindowController?.window?.delegate = self
        }
        preferenceWindowController?.showWindow(self)
    }

    func showAbout() {
        if aboutWindowController == nil {
            aboutWindowController = LKAboutWindowController()
            aboutWindowController?.window?.delegate = self
        }
        aboutWindowController?.showWindow(self)
    }

    func currentKeyWindowController() -> LKWindowController? {
        guard let keyWindow = NSApplication.shared.keyWindow,
              let controller = keyWindow.windowController as? LKWindowController else {
            return nil
        }
        return controller
    }

    func showReader(withFilePath filePath: String, error: NSErrorPointer) -> Bool {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let dataObj = try LKWireCodec.loadHierarchyFile(from: data)
            let hierarchyFile = dataObj

            if let verifyError = LookinHierarchyFile.verify(hierarchyFile) {
                if let error {
                    error.pointee = verifyError as NSError
                }
                return false
            }

            let title = FileManager.default.displayName(atPath: filePath)
            showReader(withHierarchyFile: hierarchyFile, title: title)
            return true
        } catch let readError as NSError {
            if let error {
                error.pointee = readError
            }
            return false
        }
    }

    func showReader(withHierarchyFile file: LookinHierarchyFile, title: String?) {
        let wc = LKReadWindowController(file: file)
        wc.window?.title = title ?? ""
        wc.window?.delegate = self
        wc.showWindow(self)
        readWindowControllers.add(wc)
    }

    func showJsonWindow(_ json: String) {
        if jsonWindowController == nil {
            jsonWindowController = LKJSONAttributeWindowController()
            jsonWindowController?.window?.delegate = self
        }
        if let controller = jsonWindowController?.contentViewController as? LKJSONAttributeViewController {
            controller.render(withJSON: json)
        }
        jsonWindowController?.showWindow(self)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }

        if closingWindow == preferenceWindowController?.window {
            preferenceWindowController = nil
        } else if closingWindow == staticWindowController?.window {
            LKAppsManager.sharedInstance.endInspectingSession()
            closingWindow.saveFrame(usingName: LKWindowSizeName_Static)
        } else if closingWindow == aboutWindowController?.window {
            aboutWindowController = nil
        } else {
            let controllers = readWindowControllers.compactMap { $0 as? LKReadWindowController }
            if let wc = controllers.first(where: { $0.window == closingWindow }) {
                readWindowControllers.remove(wc)
            }
        }
    }
}
