//
//  LKOutlineView.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/28.
//  https://lookin.work
//

import AppKit

protocol LKOutlineViewDelegate: AnyObject {
    func outlineView(_ view: LKOutlineView, configureRowView rowView: LKOutlineRowView, withItem item: LKOutlineItem)
}

class LKOutlineView: LKBaseView {
    private(set) var tableView: LKTableView!
    private(set) var displayingItems: [LKOutlineItem] = []

    var items: [LKOutlineItem] = [] {
        didSet { updateDisplayingItems() }
    }

    weak var delegate: LKOutlineViewDelegate?
    var itemHeight: CGFloat = 24

    private var rowViewClass: LKOutlineRowView.Type = LKOutlineRowView.self

    init(rowViewClass: AnyClass) {
        itemHeight = 24
        guard let rowClass = rowViewClass as? LKOutlineRowView.Type else {
            fatalError("rowViewClass must be LKOutlineRowView or subclass")
        }
        self.rowViewClass = rowClass
        displayingItems = []
        super.init(frame: .zero)

        tableView = LKTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.adjustsSelectionAutomatically = false
        addSubview(tableView)
    }

    override convenience init(frame frameRect: NSRect) {
        self.init(rowViewClass: LKOutlineRowView.self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        lk(tableView).fullFrame()
    }

    @objc private func handleDisclosureButton(_ button: NSButton) {
        let row = button.tag
        guard row >= 0, row < displayingItems.count else { return }
        let item = displayingItems[row]
        if item.status == .notExpandable { return }
        if item.status == .expanded {
            item.status = .collapsed
        } else {
            item.status = .expanded
        }
        updateDisplayingItems()
    }

    private func updateDisplayingItems() {
        displayingItems = LKOutlineItem.flatItems(fromRootItems: items)
        tableView.reloadData()
    }
}

extension LKOutlineView: LKTableViewDelegate, LKTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        displayingItems.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        itemHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard row >= 0, row < displayingItems.count else {
            return rowViewClass.init()
        }
        let item = displayingItems[row]

        let identifier = NSUserInterfaceItemIdentifier("cell")
        var view = tableView.makeView(withIdentifier: identifier, owner: self) as? LKOutlineRowView
        if view == nil {
            view = rowViewClass.init()
            view?.identifier = identifier
        }
        guard let view else { return nil }

        view.disclosureButton.tag = row
        view.disclosureButton.target = self
        view.disclosureButton.action = #selector(handleDisclosureButton(_:))

        switch item.status {
        case .notExpandable:
            view.status = .notExpandable
        case .expanded:
            view.status = .expanded
        case .collapsed:
            view.status = .collapsed
        }

        view.indentLevel = item.indentation
        view.titleLabel.stringValue = item.titleText ?? ""
        view.image = item.image

        delegate?.outlineView(self, configureRowView: view, withItem: item)
        view.needsLayout = true
        return view
    }
}
