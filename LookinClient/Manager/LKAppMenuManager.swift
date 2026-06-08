//
//  LKAppMenuManager.swift
//  Lookin
//
//  Created by Li Kai on 2019/3/20.
//  https://lookin.work
//

import AppCenterAnalytics
import AppKit
import Sparkle

protocol LKAppMenuManagerDelegate: AnyObject {
    func appMenuManagerDidSelectReload()
    func appMenuManagerDidSelectDimension()
    func appMenuManagerDidSelectZoomIn()
    func appMenuManagerDidSelectZoomOut()
    func appMenuManagerDidSelectDecreaseInterspace()
    func appMenuManagerDidSelectIncreaseInterspace()
    func appMenuManagerDidSelectExpansionIndex(_ index: UInt)
    func appMenuManagerDidSelectFilter()
    func appMenuManagerDidSelectExport()
    func appMenuManagerDidSelectOpenInNewWindow()
}

extension LKAppMenuManagerDelegate {
    func appMenuManagerDidSelectReload() {}
    func appMenuManagerDidSelectDimension() {}
    func appMenuManagerDidSelectZoomIn() {}
    func appMenuManagerDidSelectZoomOut() {}
    func appMenuManagerDidSelectDecreaseInterspace() {}
    func appMenuManagerDidSelectIncreaseInterspace() {}
    func appMenuManagerDidSelectExpansionIndex(_ index: UInt) {}
    func appMenuManagerDidSelectFilter() {}
    func appMenuManagerDidSelectExport() {}
    func appMenuManagerDidSelectOpenInNewWindow() {}
}

private enum MenuTag: Int {
    case about = 11
    case preferences = 12
    case checkUpdates = 13
    case reload = 21
    case dimension = 22
    case zoomIn = 23
    case zoomOut = 24
    case decreaseInterspace = 25
    case increaseInterspace = 26
    case expansion = 27
    case filter = 28
    case openInNewWindow = 31
    case export = 32
    case cocoaPods = 51
    case showWebsite = 52
    case showConfig = 53
    case showLookiniOS = 54
    case gitHub = 57
    case lookinClientGitHub = 58
    case lookinServerGitHub = 59
    case reportIssues = 60
    case lookinClientGitHubIssues = 62
    case lookinServerGitHubIssues = 63
    case weibo = 64
    case copyPod = 66
    case copySPM = 67
    case moreIntegrationGuide = 68
    case jobs = 69
    case documentCollection = 70
    case customInformation = 71
    case acknowledgements = 72
}

class LKAppMenuManager: NSObject, NSMenuDelegate {
    private static let _shared = LKAppMenuManager()

    class func sharedInstance() -> LKAppMenuManager {
        _shared
    }

    private typealias WindowMenuAction = (LKWindowController) -> Void

    private var delegatingTagActions: [Int: WindowMenuAction] = [:]

    func setup() {
        delegatingTagActions = [
            MenuTag.reload.rawValue: { $0.appMenuManagerDidSelectReload() },
            MenuTag.dimension.rawValue: { $0.appMenuManagerDidSelectDimension() },
            MenuTag.zoomIn.rawValue: { $0.appMenuManagerDidSelectZoomIn() },
            MenuTag.zoomOut.rawValue: { $0.appMenuManagerDidSelectZoomOut() },
            MenuTag.decreaseInterspace.rawValue: { $0.appMenuManagerDidSelectDecreaseInterspace() },
            MenuTag.increaseInterspace.rawValue: { $0.appMenuManagerDidSelectIncreaseInterspace() },
            MenuTag.export.rawValue: { $0.appMenuManagerDidSelectExport() },
            MenuTag.openInNewWindow.rawValue: { $0.appMenuManagerDidSelectOpenInNewWindow() },
            MenuTag.filter.rawValue: { $0.appMenuManagerDidSelectFilter() },
        ]

        guard let menu = NSApp.mainMenu else { return }

        let menuLookin = menu.item(at: 0)?.submenu
        menuLookin?.autoenablesItems = false
        menuLookin?.delegate = self

        menuLookin?.item(withTag: MenuTag.about.rawValue)?.target = self
        menuLookin?.item(withTag: MenuTag.about.rawValue)?.action = #selector(handleAbout)
        menuLookin?.item(withTag: MenuTag.preferences.rawValue)?.target = self
        menuLookin?.item(withTag: MenuTag.preferences.rawValue)?.action = #selector(handlePreferences)
        menuLookin?.item(withTag: MenuTag.checkUpdates.rawValue)?.target = self
        menuLookin?.item(withTag: MenuTag.checkUpdates.rawValue)?.action = #selector(handleCheckUpdates)

        let menuFile = menu.item(at: 1)?.submenu
        menuFile?.autoenablesItems = false
        menuFile?.delegate = self

        let menuView = menu.item(at: 3)?.submenu
        menuView?.autoenablesItems = false
        menuView?.delegate = self

        let menuHelp = menu.item(at: 5)?.submenu
        menuHelp?.autoenablesItems = true
        menuHelp?.delegate = self

        configureHelpMenu(menuHelp)

        let itemArray = (menuFile?.items ?? []) + (menuView?.items ?? [])
        for item in itemArray {
            guard delegatingTagActions[item.tag] != nil || item.tag == MenuTag.expansion.rawValue else { continue }
            if item.hasSubmenu, item.tag == MenuTag.expansion.rawValue {
                item.submenu?.items.enumerated().forEach { idx, expansionItem in
                    expansionItem.target = self
                    expansionItem.representedObject = NSNumber(value: idx)
                    expansionItem.action = #selector(routeMenuItem(_:))
                }
            } else {
                item.target = self
                item.action = #selector(routeMenuItem(_:))
            }
        }
    }

    private func configureHelpMenu(_ menuHelp: NSMenu?) {
        menuHelp?.item(withTag: MenuTag.cocoaPods.rawValue)?.target = self
        menuHelp?.item(withTag: MenuTag.cocoaPods.rawValue)?.action = #selector(handleShowCocoaPods)
        menuHelp?.item(withTag: MenuTag.showWebsite.rawValue)?.target = self
        menuHelp?.item(withTag: MenuTag.showWebsite.rawValue)?.action = #selector(handleShowWebsite)
        menuHelp?.item(withTag: MenuTag.showConfig.rawValue)?.target = self
        menuHelp?.item(withTag: MenuTag.showConfig.rawValue)?.action = #selector(handleShowConfig)
        menuHelp?.item(withTag: MenuTag.showLookiniOS.rawValue)?.target = self
        menuHelp?.item(withTag: MenuTag.showLookiniOS.rawValue)?.action = #selector(handleShowLookiniOS)

        let sourceCodeMenu = menuHelp?.item(withTag: MenuTag.gitHub.rawValue)?.submenu
        sourceCodeMenu?.item(withTag: MenuTag.lookinClientGitHub.rawValue)?.target = self
        sourceCodeMenu?.item(withTag: MenuTag.lookinClientGitHub.rawValue)?.action = #selector(handleShowLookinClientGithub)
        sourceCodeMenu?.item(withTag: MenuTag.lookinServerGitHub.rawValue)?.target = self
        sourceCodeMenu?.item(withTag: MenuTag.lookinServerGitHub.rawValue)?.action = #selector(handleShowLookinServerGithub)

        let issuesMenu = menuHelp?.item(withTag: MenuTag.reportIssues.rawValue)?.submenu
        issuesMenu?.item(withTag: MenuTag.lookinClientGitHubIssues.rawValue)?.target = self
        issuesMenu?.item(withTag: MenuTag.lookinClientGitHubIssues.rawValue)?.action = #selector(handleClientIssues)
        issuesMenu?.item(withTag: MenuTag.lookinServerGitHubIssues.rawValue)?.target = self
        issuesMenu?.item(withTag: MenuTag.lookinServerGitHubIssues.rawValue)?.action = #selector(handleServerIssues)
        issuesMenu?.item(withTag: MenuTag.weibo.rawValue)?.target = self
        issuesMenu?.item(withTag: MenuTag.weibo.rawValue)?.action = #selector(handleWeibo)

        bindHelpItem(menuHelp, tag: .copyPod, action: #selector(handleCopyPod))
        bindHelpItem(menuHelp, tag: .copySPM, action: #selector(handleCopySPM))
        bindHelpItem(menuHelp, tag: .moreIntegrationGuide, action: #selector(handleOpenMoreIntegrationGuide))
        bindHelpItem(menuHelp, tag: .jobs, action: #selector(handleJobs))
        bindHelpItem(menuHelp, tag: .documentCollection, action: #selector(handleDocumentCollection))
        bindHelpItem(menuHelp, tag: .customInformation, action: #selector(handleCustomInformation))
        bindHelpItem(menuHelp, tag: .acknowledgements, action: #selector(handleAcknowledgements))
    }

    private func bindHelpItem(_ menu: NSMenu?, tag: MenuTag, action: Selector) {
        menu?.item(withTag: tag.rawValue)?.target = self
        menu?.item(withTag: tag.rawValue)?.action = action
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let delegate = LKNavigationManager.sharedInstance.currentKeyWindowController()
        for item in menu.items {
            if delegatingTagActions[item.tag] != nil || item.tag == MenuTag.expansion.rawValue {
                item.isEnabled = delegate != nil
            } else {
                item.isEnabled = true
            }
        }
    }

    @objc private func handlePreferences() {
        LKNavigationManager.sharedInstance.showPreference()
    }

    @objc private func routeMenuItem(_ item: NSMenuItem) {
        guard let delegate = LKNavigationManager.sharedInstance.currentKeyWindowController() else {
            assertionFailure()
            return
        }
        if item.tag == MenuTag.expansion.rawValue {
            guard let idxNum = item.representedObject as? NSNumber else {
                assertionFailure()
                return
            }
            delegate.appMenuManagerDidSelectExpansionIndex(idxNum.uintValue)
            Analytics.trackEvent("Hierarchy Expansion", withProperties: ["level": "\(idxNum)"])
            return
        }
        guard let action = delegatingTagActions[item.tag] else {
            assertionFailure()
            return
        }
        action(delegate)
    }

    @objc private func handleShowConfig() {
        LKHelper.openLookinWebsite(withPath: "faq/config-file/")
    }

    @objc private func handleShowLookiniOS() {
        LKHelper.openLookinWebsite(withPath: "faq/lookin-ios/")
    }

    @objc private func handleShowLookinClientGithub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/hughkli/Lookin")!)
    }

    @objc private func handleShowLookinServerGithub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/QMUI/LookinServer")!)
    }

    @objc private func handleClientIssues() {
        NSWorkspace.shared.open(URL(string: "https://github.com/hughkli/Lookin/issues")!)
    }

    @objc private func handleServerIssues() {
        NSWorkspace.shared.open(URL(string: "https://github.com/QMUI/LookinServer/issues")!)
    }

    @objc private func handleWeibo() {
        NSWorkspace.shared.open(URL(string: "https://weibo.com/234885306")!)
    }

    @objc private func handleShowWebsite() {
        LKHelper.openLookinOfficialWebsite()
    }

    @objc private func handleCopyPod() {
        let paste = NSPasteboard.general
        paste.clearContents()
        paste.writeObjects(["pod 'LookinServer', :configurations => ['Debug']"] as [NSString])
    }

    @objc private func handleCopySPM() {
        let paste = NSPasteboard.general
        paste.clearContents()
        paste.writeObjects(["https://github.com/QMUI/LookinServer/"] as [NSString])
    }

    @objc private func handleOpenMoreIntegrationGuide() {
        NSWorkspace.shared.open(URL(string: "https://github.com/QMUI/LookinServer/blob/master/README.md")!)
    }

    @objc private func handleJobs() {
        NSWorkspace.shared.open(URL(string: "https://bytedance.feishu.cn/docx/SAcgdoQuAouyXAxAqy8cmrT2n4b")!)
    }

    @objc private func handleCheckUpdates() {
        SUUpdater.shared()?.checkForUpdates(self)
    }

    @objc private func handleShowCocoaPods() {
        LKHelper.openLookinWebsite(withPath: "faq/integration-guide/")
    }

    @objc private func handleAbout() {
        LKNavigationManager.sharedInstance.showAbout()
    }

    @objc private func handleDocumentCollection() {
        NSWorkspace.shared.open(URL(string: "https://bytedance.larkoffice.com/docx/Yvv1d57XQoe5l0xZ0ZRc0ILfnWb")!)
    }

    @objc private func handleCustomInformation() {
        NSWorkspace.shared.open(URL(string: "https://bytedance.larkoffice.com/docx/TRridRXeUoErMTxs94bcnGchnlb")!)
    }

    @objc private func handleAcknowledgements() {
        NSWorkspace.shared.open(URL(string: "https://qxh1ndiez2w.feishu.cn/docx/YIFjdE4gIolp3hxn1tGckiBxnWf")!)
    }
}
