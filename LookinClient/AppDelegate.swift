//
//  AppDelegate.swift
//  Lookin
//
//  Created by Li Kai on 2018/8/4.
//  https://lookin.work
//

import AppCenter
import AppCenterAnalytics
import AppCenterCrashes
import AppKit
import LookinMacMCP
import LookinShared
import RxSwift

class AppDelegate: NSObject, NSApplicationDelegate {
    private var launchedToOpenFile = false
    private let disposeBag = DisposeBag()

    func applicationWillFinishLaunching(_ notification: Notification) {
        LKAppMenuManager.sharedInstance().setup()
        LKOsAppMCPServerSwift.shared.start(onPort: 47192, dataSource: self)

        LKPreferenceMain().appearanceTypeObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { _, type in
                switch type {
                case .dark:
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                case .light:
                    NSApp.appearance = NSAppearance(named: .aqua)
                case .system:
                    NSApp.appearance = nil
                @unknown default:
                    NSApp.appearance = nil
                }
            }
            .disposed(by: disposeBag)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LKOsAppMCPServerSwift.shared.start(onPort: 47192, dataSource: self)
        _ = LKConnectionManager.sharedInstance

        if LookinUITestSupport.isEnabled {
            LookinUITestSupport.applyLaunchConfiguration()
            if !launchedToOpenFile {
                LKNavigationManager.sharedInstance.showLaunch()
            }
            LookinUITestSupport.startInspectorReadinessObserver()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.openInspectorForUITestIfNeeded()
            }
        } else if !launchedToOpenFile {
            LKNavigationManager.sharedInstance.showLaunch()
        }

        if LookinUITestSupport.isEnabled {
            AppCenter.enabled = false
        } else if let key = resolveAppCenterKey() {
            AppCenter.start(withAppSecret: key, services: [
                Analytics.self,
                Crashes.self,
            ])
            AppCenter.enabled = LKPreferenceMain().enableReport
        } else {
            AppCenter.enabled = false
        }

        #if DEBUG
        runTests()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        launchedToOpenFile = true
        var error: NSError?
        let isSuccessful = LKNavigationManager.sharedInstance.showReader(
            withFilePath: filename,
            error: &error
        )
        return isSuccessful
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        LKAppsManager.sharedInstance.endInspectingSession()
        LookinDiagLog.log("client applicationWillTerminate — released Peertalk")
        let tempImageFilesToDelete = LKHelper.sharedInstance.tempImageFiles ?? []
        if tempImageFilesToDelete.count == 0 {
            return .terminateNow
        }
        for case let path as String in tempImageFilesToDelete {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                assertionFailure()
            }
        }
        return .terminateNow
    }

    private func resolveAppCenterKey() -> String? {
        let bundleID = Bundle.main.bundleIdentifier
        if bundleID == "hughkli.Lookin" {
            return "fce2565c-518c-4851-be73-fa8317dd1590"
        }
        assertionFailure()
        return nil
    }

    private func openInspectorForUITestIfNeeded() {
        DispatchQueue.main.async {
            let nav = LKNavigationManager.sharedInstance
            if nav.staticWindowController?.window?.isVisible == true {
                if LKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo != nil {
                    nav.staticWindowController?.mcpForceReload()
                }
                return
            }
            if LKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo != nil {
                nav.showStaticWorkspace()
                nav.closeLaunch()
                return
            }
            if nav.launchWindowController == nil {
                nav.showLaunch()
            }
            NSApp.activate(ignoringOtherApps: true)
            nav.launchWindowController?.launchViewController?.lookin_mcpTryEnterInspector()
        }
    }

    private func runTests() {
        let allGroupIDs = LookinDashboardBlueprint.groupIDs()
        let allGroupIDsUnique = Set(allGroupIDs)
        if allGroupIDs.count != allGroupIDsUnique.count {
            assertionFailure()
        }

        var allSecIDs: [LookinAttrSectionIdentifier] = []
        for groupID in allGroupIDs {
            let secIDs = LookinDashboardBlueprint.sectionIDs(forGroupID: groupID)
            allSecIDs.append(contentsOf: secIDs)
        }
        let allSecIDsUnique = Set(allSecIDs)
        if allSecIDs.count != allSecIDsUnique.count {
            assertionFailure()
        }

        var allAttrIDs: [LookinAttrIdentifier] = []
        for secID in allSecIDs {
            let attrIDs = LookinDashboardBlueprint.attrIDs(forSectionID: secID)
            allAttrIDs.append(contentsOf: attrIDs)
        }
        let allAttrIDsUnique = Set(allAttrIDs)
        if allAttrIDs.count != allAttrIDsUnique.count {
            assertionFailure()
        }
    }
}
