//
//  LKInputSearchSuggestionsContentView.swift
//  Lookin
//
//  Created by Li Kai on 2019/6/3.
//  https://lookin.work
//

import AppKit

private let kInputSearchSuggestionsItemViewHeight: CGFloat = 28

class LKInputSearchSuggestionsContentView: LKBaseView, NSTableViewDelegate, NSTableViewDataSource {
    var items: [LKInputSearchSuggestionItem] = [] {
        didSet { tableView.reloadData() }
    }

    private(set) var tableView: NSTableView!
    private var backgroundEffectView: LKVisualEffectView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = 4

        backgroundEffectView = LKVisualEffectView()
        backgroundEffectView.blendingMode = .behindWindow
        backgroundEffectView.state = .active
        addSubview(backgroundEffectView)

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.wantsLayer = true
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("column"))
        column.isEditable = false
        tableView.addTableColumn(column)
        addSubview(tableView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        lk(backgroundEffectView, tableView).fullFrame()
    }

    func currentSelectedItem() -> LKInputSearchSuggestionItem? {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < items.count else { return nil }
        return items[selectedRow]
    }

    func bestSize() -> NSSize {
        let rowView: LKInputSearchSuggestionsRowView
        if let cached = lookin_getBindObject(forKey: "calculatingRowView") as? LKInputSearchSuggestionsRowView {
            rowView = cached
        } else {
            rowView = LKInputSearchSuggestionsRowView()
            lookin_bindObject(rowView, forKey: "calculatingRowView")
        }

        let width = items.reduce(CGFloat(0)) { accumulator, obj in
            rowView.imageView.image = obj.image
            rowView.titleLabel.stringValue = obj.text ?? ""
            return max(rowView.bestWidth(), accumulator)
        }
        let height = kInputSearchSuggestionsItemViewHeight * CGFloat(items.count)
        return NSSize(width: width, height: height)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        kInputSearchSuggestionsItemViewHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let item = (items as NSArray).lookin_safeObject(at: row) as? LKInputSearchSuggestionItem else {
            return LKInputSearchSuggestionsRowView()
        }
        var view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("cell"), owner: self) as? LKInputSearchSuggestionsRowView
        if view == nil {
            view = LKInputSearchSuggestionsRowView()
            view?.identifier = NSUserInterfaceItemIdentifier("cell")
        }
        view?.titleLabel.stringValue = item.text ?? ""
        view?.imageView.image = item.image
        view?.needsLayout = true
        return view
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        nil
    }
}
