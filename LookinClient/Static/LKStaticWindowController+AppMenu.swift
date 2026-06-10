import AppKit
import AppCenterAnalytics
import LookinShared
import RxSwift

extension LKStaticWindowController {
    // MARK: - LKAppMenuManagerDelegate

    func appMenuManagerDidSelectReload() {
        if isFetchingDetails {
            let error = LookinErrorMake(
                NSLocalizedString("Cannot reload at this time", comment: ""),
                NSLocalizedString(
                    "Please wait until current sync is completed. You can get sync progress in the upper-left corner of this window.",
                    comment: ""
                )
            )
            if let window {
                NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
            }
            return
        }
        handleReload()
    }

    func mcpForceReload() {
        LKStaticAsyncUpdateManager.sharedInstance.endUpdating()
        isFetchingDetails = false
        isFetchingHierarchy = false
        handleReload()
    }

    func appMenuManagerDidSelectDimension() {
        let manager = LKPreferenceMain()
        if manager.previewDimension == Int(LookinPreviewDimension.dimension2D.rawValue) {
            manager.previewDimension = Int(LookinPreviewDimension.dimension3D.rawValue)
        } else {
            manager.previewDimension = Int(LookinPreviewDimension.dimension2D.rawValue)
        }
    }

    func appMenuManagerDidSelectZoomIn() {
        let manager = LKPreferenceMain()
        let target = min(max(manager.previewScale + 0.1, LookinPreviewMinScale), LookinPreviewMaxScale)
        manager.previewScale = target
    }

    func appMenuManagerDidSelectZoomOut() {
        let manager = LKPreferenceMain()
        let target = min(max(manager.previewScale - 0.1, LookinPreviewMinScale), LookinPreviewMaxScale)
        manager.previewScale = target
    }

    func appMenuManagerDidSelectDecreaseInterspace() {
        let manager = LKPreferenceMain()
        var newValue = manager.zInterspace - 0.1
        newValue = min(max(newValue, LookinPreviewMinZInterspace), LookinPreviewMaxZInterspace)
        manager.zInterspace = newValue
    }

    func appMenuManagerDidSelectIncreaseInterspace() {
        let manager = LKPreferenceMain()
        var newValue = manager.zInterspace + 0.1
        newValue = min(max(newValue, LookinPreviewMinZInterspace), LookinPreviewMaxZInterspace)
        manager.zInterspace = newValue
    }

    func appMenuManagerDidSelectExpansionIndex(_ index: UInt) {
        LKStaticHierarchyDataSource.sharedInstance.adjustExpansionByIndex(
            Int(index),
            referenceDict: nil,
            selectedItem: nil
        )
        if !TutorialMng.hasAlreadyShowedTipsThisLaunch, !TutorialMng.quickSelection, index <= 1 {
            viewController.showQuickSelectionTutorialTips()
        }
    }

    func appMenuManagerDidSelectExport() {
        let exportManager = LKExportManager.sharedInstance
        guard let hierarchyInfo = LKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo else { return }

        var fileNameRef: NSString?
        var exportedData: Data?
        let accessoryView = LKExportAccessoryView()
        accessoryView.sizeToFit()

        LKPreferenceMain().preferredExportCompressionObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { compression in
                fileNameRef = nil
                exportedData = exportManager.data(
                    from: hierarchyInfo,
                    imageCompression: compression,
                    fileName: &fileNameRef
                )
                accessoryView.dataSize = UInt(exportedData?.count ?? 0)
            })
            .disposed(by: disposeBag)

        let panel = NSSavePanel()
        panel.accessoryView = accessoryView
        panel.nameFieldStringValue = fileNameRef as String? ?? ""
        panel.allowsOtherFileTypes = false
        panel.allowedFileTypes = ["lookin"]
        panel.isExtensionHidden = true
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window!) { result in
            if result == .OK, let path = panel.url?.path {
                guard let exportedData else {
                    assertionFailure("LookinClient - write fail, no data")
                    return
                }
                do {
                    try exportedData.write(to: URL(fileURLWithPath: path))
                } catch {
                    NSLog("LookinClient - write fail:%@", error.localizedDescription)
                }
            }
        }
        Analytics.trackEvent("Export Document")
    }

    func appMenuManagerDidSelectOpenInNewWindow() {
        let newHierarchyInfo = LKStaticHierarchyDataSource.sharedInstance.rawHierarchyInfo?.copy() as? LookinHierarchyInfo
        var file = LookinHierarchyFile()
        file.serverVersion = newHierarchyInfo?.serverVersion ?? 0
        file.hierarchyInfo = newHierarchyInfo
        LKNavigationManager.sharedInstance.showReader(withHierarchyFile: file, title: nil)
        Analytics.trackEvent("Open New Window")
    }

    func appMenuManagerDidSelectFilter() {
        viewController.currentHierarchyView().activateSearchBar()
    }
}
