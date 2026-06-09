//
//  LKLogsViewController.swift
//  Lookin
//

import AppKit
import LookinShared
import RxSwift

final class LKLogsViewController: LKBaseViewController, LKTableViewDelegate, LKTableViewDataSource {
    private var tableView: LKTableView!
    private var clearButton: NSButton!
    private var topBorderLayer: CALayer!

    private let disposeBag = DisposeBag()

    init() {
        super.init(containerView: nil)

        LKLogsManager.shared.entriesObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, _ in
                owner.tableView.reloadData()
                owner.tableView.layoutSubtreeIfNeeded()
                let count = LKLogsManager.shared.entries.count
                if count > 0 {
                    owner.tableView.scrollRowToVisible(count - 1)
                }
            }
            .disposed(by: disposeBag)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func makeContainerView() -> NSView {
        let containerView = LKBaseView()
        containerView.backgroundColorName = "ConsoleBackgroundColor"

        tableView = LKTableView()
        tableView.drawsBackground = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.canScrollHorizontally = false
        tableView.adjustsSelectionAutomatically = false
        tableView.adjustsHoverAutomatically = false
        tableView.automaticallyAdjustsContentInsets = false
        tableView.contentInsets = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        containerView.addSubview(tableView)

        let clearButtonImage = NSImageMake("icon_delete")
        clearButtonImage?.isTemplate = true
        clearButton = NSButton()
        clearButton.image = clearButtonImage
        clearButton.bezelStyle = .rounded
        clearButton.isBordered = false
        clearButton.target = self
        clearButton.action = #selector(handleClearButton)
        containerView.addSubview(clearButton)

        topBorderLayer = CALayer()
        topBorderLayer.lookin_removeImplicitAnimations()
        containerView.layer?.addSublayer(topBorderLayer)

        containerView.didChangeAppearanceBlock = { [weak self] _, isDarkMode in
            guard let self else { return }
            self.topBorderLayer.backgroundColor = isDarkMode
                ? NSColor(white: 1, alpha: 0.12).cgColor
                : NSColor(white: 0, alpha: 0.15).cgColor
        }

        return containerView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        lk(topBorderLayer).fullWidth().height(1).y(0)
        lk(tableView).fullFrame()
        lk(clearButton).sizeToFit().right(20).bottom(8)
    }

    @objc private func handleClearButton() {
        LKLogsManager.shared.clearEntries()
    }

    // MARK: LKTableViewDataSource / LKTableViewDelegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        LKLogsManager.shared.entries.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let entries = LKLogsManager.shared.entries
        guard row >= 0, row < entries.count else { return 0 }
        return LKLogRowView.rowHeight(for: entries[row])
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let entries = LKLogsManager.shared.entries
        guard row >= 0, row < entries.count else { return LKTableBlankRowView() }
        let entry = entries[row]

        var view = tableView.makeView(
            withIdentifier: NSUserInterfaceItemIdentifier("logRow"),
            owner: self
        ) as? LKLogRowView
        if view == nil {
            view = LKLogRowView()
            view?.identifier = NSUserInterfaceItemIdentifier("logRow")
        }
        view?.configure(with: entry)
        return view
    }

    func tableViewDidClickBlankArea(_ tableView: LKTableView) {}
}
