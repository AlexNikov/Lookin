import AppKit
import LookinShared

private final class LKJSONAttributeContentRowView: LKOutlineRowView {
    override class func insetLeft() -> CGFloat { 0 }
}

final class LKJSONAttributeContentView: LKBaseView, LKTableViewDelegate, LKTableViewDataSource {
    var didReloadData: (() -> Void)?

    private let useBigFont: Bool
    private var rootItems: [LKJSONAttributeItem] = []
    private var flatItems: [LKJSONAttributeItem] = []
    private var tableView: LKTableView!
    private var invalidLabel: LKLabel?
    private var rowHeight: CGFloat = 20
    private let contentInset: CGFloat = 8
    private var invalidMessage: String?

    init(bigFont: Bool) {
        useBigFont = bigFont
        super.init(frame: .zero)
        tableView = LKTableView()
        tableView.drawsBackground = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.adjustsSelectionAutomatically = false
        tableView.adjustsHoverAutomatically = false
        tableView.automaticallyAdjustsContentInsets = false
        if bigFont {
            tableView.contentInsets = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
            rowHeight = 25
        } else {
            tableView.contentInsets = .zero
            rowHeight = 20
        }
        addSubview(tableView)
    }

    required init?(coder: NSCoder) {
        useBigFont = false
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        let width = bounds.width - contentInset * 2
        if let invalidLabel, !invalidLabel.isHidden {
            tableView.isHidden = true
            lk(invalidLabel).x(contentInset).width(width).heightToFit().y(contentInset)
        } else {
            tableView.isHidden = false
            invalidLabel?.isHidden = true
            lk(tableView).fullFrame()
        }
    }

    func render(withJSON json: String?) {
        render(withJSONValue: json.map { .json($0) })
    }

    /// Accepts wire v2 `WireAttrValueKind.json` text or any JSON object/array from Codable decode.
    func render(withJSONValue value: AttributeValue?) {
        switch LookinJSONAttributeSupport.dashboardParseState(from: value) {
        case .empty:
            showInvalidJSON(nil)
        case .valid(let rows):
            showInvalidJSON(nil)
            rootItems = createItems(from: rows) ?? []
            renderTree()
        case .invalid(let message):
            rootItems = []
            flatItems = []
            showInvalidJSON(message)
        }
    }

    private func showInvalidJSON(_ message: String?) {
        invalidMessage = message
        if let message {
            if invalidLabel == nil {
                let label = LKLabel()
                label.cell?.wraps = true
                label.cell?.isScrollable = false
                label.font = useBigFont ? NSFont.systemFont(ofSize: 13) : NSFont.systemFont(ofSize: 12)
                label.textColor = .systemRed
                addSubview(label)
                invalidLabel = label
            }
            invalidLabel?.isHidden = false
            invalidLabel?.stringValue = NSLocalizedString("Invalid JSON", comment: "") + ": " + message
        } else {
            invalidLabel?.isHidden = true
        }
        tableView.reloadData()
        needsLayout = true
        didReloadData?()
    }

    private func renderTree() {
        flatItems = rootItems.flatMap { $0.flatItems() }
        tableView.reloadData()
        needsLayout = true
        didReloadData?()
    }

    private func createItems(from rawArray: [[String: Any]]) -> [LKJSONAttributeItem]? {
        var result: [LKJSONAttributeItem] = []
        for dict in rawArray {
            let item = LKJSONAttributeItem()
            item.titleText = dict["title"] as? String
            item.desc = dict["desc"] as? String
            item.expanded = true
            if let details = dict["details"] as? [[String: Any]] {
                item.subItems = createItems(from: details) ?? []
            }
            result.append(item)
        }
        return result
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        flatItems.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        rowHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let item = flatItems[safe: row] else { return LKTableBlankRowView() }
        var view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("myView"), owner: self) as? LKJSONAttributeContentRowView
        if view == nil {
            view = LKJSONAttributeContentRowView(compactUI: true)
            view?.titleLabel.textColor = .secondaryLabelColor
            if useBigFont {
                view?.titleLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
                view?.subtitleLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
            } else {
                view?.titleLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
                view?.subtitleLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            }
            view?.titleLabel.isSelectable = true
            view?.subtitleLabel.textColor = .labelColor
            view?.subtitleLabel.isSelectable = true
            view?.disclosureButton.target = self
            view?.disclosureButton.action = #selector(handleExpand(_:))
            view?.identifier = NSUserInterfaceItemIdentifier("myView")
        }
        view?.titleLabel.stringValue = item.titleText ?? ""
        view?.subtitleLabel.stringValue = item.desc ?? ""
        view?.disclosureButton.tag = row
        view?.indentLevel = UInt(item.indentation)
        if !item.subItems.isEmpty {
            view?.status = item.expanded ? LKOutlineRowViewStatus.expanded : LKOutlineRowViewStatus.collapsed
        } else {
            view?.status = LKOutlineRowViewStatus.notExpandable
        }
        view?.needsLayout = true
        return view ?? LKTableBlankRowView()
    }

    @objc private func handleExpand(_ button: NSButton) {
        guard let item = flatItems[safe: button.tag] else { return }
        item.expanded.toggle()
        renderTree()
    }

    func queryContentHeight() -> CGFloat {
        if invalidMessage != nil, let invalidLabel, !invalidLabel.isHidden {
            let width = max(bounds.width, 200) - contentInset * 2
            return invalidLabel.heightForWidth(width) + contentInset * 2
        }
        if flatItems.isEmpty {
            return rowHeight + contentInset
        }
        return CGFloat(flatItems.count) * rowHeight
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
