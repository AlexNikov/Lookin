import AppKit
import LookinShared

extension LKStaticWindowController: LKStaticAsyncUpdateManagerDelegate {
    // MARK: - LKStaticAsyncUpdateManagerDelegate

    func detailUpdateTasksTotalCount(_ totalCount: UInt, finishedCount: UInt) {
        guard let reloadItem = toolbarItemsMap[NSToolbarItem.Identifier.LKToolBarIdentifier_Reload],
              let reloadButton = reloadItem.view as? NSButton else { return }

        let isFetching = totalCount > finishedCount
        if isFetching {
            if !isFetchingDetails {
                isFetchingDetails = true
                let image = NSImageMake("icon_stop")
                image?.isTemplate = true
                reloadButton.image = image
            }
            reloadItem.label = "\(finishedCount) / \(totalCount)"
        } else if isFetchingDetails {
            isFetchingDetails = false
            reloadItem.label = NSLocalizedString("Reload", comment: "")
            let image = NSImageMake("icon_reload")
            image?.isTemplate = true
            reloadButton.image = image
        }
    }

    func detailUpdateReceivedError(_ error: NSError) {
        AlertError(error, window)
    }

    func resetDetailFetchingToolbarState() {
        isFetchingDetails = false
        guard let reloadItem = toolbarItemsMap[NSToolbarItem.Identifier.LKToolBarIdentifier_Reload],
              let reloadButton = reloadItem.view as? NSButton else { return }
        reloadItem.label = NSLocalizedString("Reload", comment: "")
        let image = NSImageMake("icon_reload")
        image?.isTemplate = true
        reloadButton.image = image
    }
}
