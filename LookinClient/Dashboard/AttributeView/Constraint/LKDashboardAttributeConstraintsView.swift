import AppKit
import LookinShared

final class LKDashboardAttributeConstraintsView: LKDashboardAttributeView {
    private var textControls: [LKDashboardAttributeConstraintsItemControl] = []
    private let verInterSpace: CGFloat = 8

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textControls = []
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func renderWithAttribute() {
        super.renderWithAttribute()
        let rawData: [LookinAutoLayoutConstraint]
        if case .customObject(let rawValue)? = attribute?.value,
           let constraints = rawValue as? [LookinAutoLayoutConstraint] {
            rawData = constraints
        } else {
            rawData = []
        }
        let sorted = sortedRawData(from: rawData)
        let mutable = NSMutableArray(array: textControls)
        mutable.lookin_dequeue(withCount: sorted.count, add: { [weak self] _ in
            let control = LKDashboardAttributeConstraintsItemControl()
            control.addTarget(self, clickAction: #selector(LKDashboardAttributeConstraintsView.handleClickItem(_:)))
            self?.addSubview(control)
            return control
        }, notDequeued: { _, control in
            (control as? LKDashboardAttributeConstraintsItemControl)?.isHidden = true
        }, doNext: { idx, control in
            guard let control = control as? LKDashboardAttributeConstraintsItemControl else { return }
            control.isHidden = false
            control.constraint = sorted[Int(idx)]
            control.needsLayout = true
        })
        textControls = mutable as? [LKDashboardAttributeConstraintsItemControl] ?? []
        needsLayout = true
    }

    override func layout() {
        super.layout()
        var y: CGFloat = 0
        for obj in textControls where !obj.isHidden {
            lk(obj).fullFrame().heightToFit().y(y)
            y = obj.frame.maxY + verInterSpace
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var height: CGFloat = 0
        for (idx, obj) in textControls.enumerated() where !obj.isHidden {
            height += obj.sizeThatFits(limitedSize).height
            if idx > 0 { height += verInterSpace }
        }
        return NSSize(width: limitedSize.width, height: height)
    }

    @objc private func handleClickItem(_ control: LKDashboardAttributeConstraintsItemControl) {
        guard let constraint = control.constraint else { return }
        let vc = LKConstraintPopoverController(constraint: constraint)
        let popover = NSPopover()
        popover.animates = false
        popover.behavior = .transient
        popover.contentSize = vc.contentSize()
        popover.contentViewController = vc
        vc.requestJumpingToObject = { [weak popover, weak self] lookinObj in
            popover?.close()
            guard let self, let dataSource = self.dashboardViewController?.currentDataSource(),
                  let item = dataSource.displayItem(withOid: lookinObj.oid) else { return }
            if !item.displayingInHierarchy {
                dataSource.expandToShowItem(item)
            }
            dataSource.selectedItem = item
        }
        popover.show(relativeTo: NSRect(x: 0, y: 0, width: control.bounds.width, height: control.bounds.height), of: control, preferredEdge: .maxX)
    }

    private func sortedRawData(from rawData: [LookinAutoLayoutConstraint]) -> [LookinAutoLayoutConstraint] {
        rawData.sorted { obj1, obj2 in
            if obj1.effective != obj2.effective { return obj1.effective }
            if obj1.firstItemType != obj2.firstItemType { return obj1.firstItemType.rawValue < obj2.firstItemType.rawValue }
            return obj1.firstAttribute < obj2.firstAttribute
        }
    }
}
