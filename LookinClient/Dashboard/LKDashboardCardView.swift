import AppKit
import LookinShared

final class LKDashboardCardView: LKBaseView {
    weak var dashboardViewController: LKDashboardViewController?
    weak var delegate: LKDashboardCardViewDelegate?
    var attrGroup: LookinAttributesGroup?
    var isCollapsed = false {
        didSet {
            titleControl.disclosureImageView.image = NSImageMake(isCollapsed ? "icon_arrow_right" : "icon_arrow_down")
        }
    }

    private var backgroundEffectView: LKVisualEffectView!
    private var titleControl: LKDashboardCardTitleControl!
    private var detailButton: NSButton!
    private var relationHelpButton: NSButton?
    private var fadeView: LKBaseView?
    private let sectionViewPool = LKDashboardSectionViewPool()
    private var sectionViews: [LKDashboardSectionView] = []
    private var accessoryWC: LKDashboardAccessoryWindowController?

    private let titleHeight: CGFloat = 30
    private var contentsY: CGFloat = 35
    private let insetBottom: CGFloat = 12

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = DashboardCardCornerRadius
        backgroundEffectView = LKVisualEffectView()
        backgroundEffectView.blendingMode = .withinWindow
        backgroundEffectView.state = .active
        addSubview(backgroundEffectView)
        titleControl = LKDashboardCardTitleControl()
        titleControl.addTarget(self, clickAction: #selector(handleClickTitle))
        addSubview(titleControl)
        detailButton = NSButton(image: .lookinNamed("icon_more"), target: self, action: #selector(handleClickDetailButton))
        detailButton.bezelStyle = .rounded
        detailButton.isBordered = false
        addSubview(detailButton)
        updateColors()
        LKUserActionManager.sharedInstance.addDelegate(self)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        lk(backgroundEffectView).fullFrame()
        lk(titleControl).fullWidth().height(titleHeight).y(0)
        if detailButton.isVisible { lk(detailButton).width(50).height(28).right(-3).y(0) }
        if relationHelpButton?.isVisible == true, let relationHelpButton {
            lk(relationHelpButton).width(30).height(28).right(5).y(0)
        }
        guard attrGroup != nil, !sectionViews.isEmpty else { return }
        var y = contentsY
        for view in sectionViews {
            lk(view).x(DashboardHorInset).toRight(DashboardHorInset).heightToFit().y(y)
            y = view.frame.maxY + DashboardSectionMarginTop
        }
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        if isCollapsed {
            size.height = titleHeight
            return size
        }
        size.width -= DashboardHorInset * 2
        var height = contentsY
        for obj in sectionViews {
            height += obj.sizeThatFits(size).height + DashboardSectionMarginTop
        }
        height -= DashboardSectionMarginTop
        height += insetBottom
        size.height = height
        return size
    }

    func render() {
        guard let attrGroup else { assertionFailure(); return }
        switch attrGroup.identifier {
        case LookinAttrGroup_Class: contentsY = 28
        case LookinAttrGroup_Relation: contentsY = 30
        default: contentsY = 35
        }
        titleControl.label.stringValue = attrGroup.queryDisplayTitle()
        titleControl.iconImageView.image = Self.image(with: attrGroup)
        titleControl.needsLayout = true
        detailButton.isHidden = !shouldShowDetailButton(groupID: attrGroup.identifier ?? "")
        sectionViews.forEach { $0.removeFromSuperview() }
        sectionViews.removeAll()
        sectionViewPool.recycleAll()
        var visibleSectionIndex = 0
        for sec in attrGroup.attrSections ?? [] {
            if !sec.isUserCustom(), !LKPreferenceMain().isSectionShowing(sec.identifier ?? "") { continue }
            let secView = sectionViewPool.dequeView(for: sec)
            sectionViews.append(secView)
            addSubview(secView)
            secView.dashboardViewController = dashboardViewController
            secView.attrSection = sec
            secView.showTopSeparator = visibleSectionIndex > 0
            secView.manageState = accessoryWC == nil ? .none : .canRemove
            visibleSectionIndex += 1
        }
        if accessoryWC != nil { renderAccessoryWindowController() }
        if attrGroup.identifier == LookinAttrGroup_Relation { showRelationHelpButton() } else { hideRelationHelpButton() }
        needsLayout = true
    }

    func querySectionView(with sec: LookinAttributesSection) -> LKDashboardSectionView? {
        sectionViews.first { $0.attrSection?.identifier == sec.identifier }
    }

    func playFadeAnimation(withHighlightRect rect: NSRect) {
        guard fadeView == nil else { return }
        let overlay = LKBaseView()
        overlay.backgroundColor = LookinClientIsDarkMode() ? LookinColorRGBAMake(0, 0, 0, 0.7) : LookinColorRGBAMake(0, 0, 0, 0.6)
        overlay.alphaValue = 0
        overlay.frame = bounds
        addSubview(overlay)
        fadeView = overlay
        if rect != .zero {
            var totalHeight = overlay.frame.size.height
            if totalHeight <= 0 { totalHeight = 1; assertionFailure() }
            let maskLayer = CAGradientLayer()
            maskLayer.colors = [NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor, NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor]
            maskLayer.startPoint = CGPoint(x: 0, y: 0)
            maskLayer.endPoint = CGPoint(x: 0, y: 1)
            maskLayer.locations = [0, NSNumber(value: (rect.minY - 4) / totalHeight), NSNumber(value: (rect.minY + 10) / totalHeight), NSNumber(value: (rect.maxY + 2) / totalHeight), NSNumber(value: (rect.maxY + 16) / totalHeight), 1]
            maskLayer.frame = overlay.bounds
            overlay.layer?.mask = maskLayer
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            overlay.animator().alphaValue = 1
        } completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + LKUITiming.cardFadeOut) { self.removeFadeAnimation() }
        }
    }

    private func removeFadeAnimation() {
        guard let fadeView else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            fadeView.animator().alphaValue = 0
        } completionHandler: {
            fadeView.removeFromSuperview()
            self.fadeView = nil
        }
    }

    @objc private func handleClickTitle() {
        delegate?.dashboardCardViewNeedToggleCollapse(self)
    }

    private static func image(with group: LookinAttributesGroup) -> NSImage {
        let dict: [LookinAttrGroupIdentifier: String] = [
            LookinAttrGroup_Class: "dashboard_class",
            LookinAttrGroup_Accessibility: "dashboard_label",
            LookinAttrGroup_Relation: "dashboard_relation",
            LookinAttrGroup_Layout: "dashboard_layout",
            LookinAttrGroup_AutoLayout: "dashboard_autolayout",
            LookinAttrGroup_ViewLayer: "dashboard_layer",
            LookinAttrGroup_UIImageView: "dashboard_imageview",
            LookinAttrGroup_UILabel: "dashboard_label",
            LookinAttrGroup_UIButton: "dashboard_button",
            LookinAttrGroup_UIControl: "dashboard_control",
            LookinAttrGroup_UIScrollView: "dashboard_scrollview",
            LookinAttrGroup_UITableView: "dashboard_tableview",
            LookinAttrGroup_UITextView: "dashboard_textview",
            LookinAttrGroup_UITextField: "dashboard_textfield",
            LookinAttrGroup_UIVisualEffectView: "dashboard_effectview",
            LookinAttrGroup_UIStackView: "dashboard_stackview",
            LookinAttrGroup_UserCustom: "dashboard_custom",
        ]
        guard let name = dict[group.identifier ?? ""], let image = NSImageMake(name) else { assertionFailure(); return NSImage() }
        return image
    }

    private func showRelationHelpButton() {
        if relationHelpButton == nil {
            relationHelpButton = NSButton(image: .lookinNamed("ic_question"), target: self, action: #selector(handleRelationHelpButton))
            relationHelpButton?.bezelStyle = .rounded
            relationHelpButton?.isBordered = false
        }
        // Match ObjC showRelationHelpButton: bring detail then relation above sections.
        addSubview(detailButton)
        if let relationHelpButton { addSubview(relationHelpButton) }
    }

    private func hideRelationHelpButton() {
        relationHelpButton?.removeFromSuperview()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        LKUserActionManager.sharedInstance.send(.dashboardClick)
    }

    @objc private func handleClickDetailButton() {
        if let accessoryWC {
            accessoryWC.close()
            return
        }
        LKUserActionManager.sharedInstance.send(.dashboardClick)
        if isCollapsed { delegate?.dashboardCardViewNeedToggleCollapse(self) }
        guard let dashboardViewController, let identifier = attrGroup?.identifier else { return }
        let wc = LKDashboardAccessoryWindowController(dashboardController: dashboardViewController, attrGroupID: identifier)
        wc.delegate = self
        accessoryWC = wc
        renderAccessoryWindowController()
        if let window, let childWindow = wc.window {
            window.addChildWindow(childWindow, ordered: .above)
        }
    }

    private func renderAccessoryWindowController() {
        guard let accessoryWC, let attrGroup else { assertionFailure(); return }
        sectionViews.forEach { $0.manageState = .canRemove }
        let allSecIDs = LookinDashboardBlueprint.sectionIDs(forGroupID: attrGroup.identifier ?? "")
        let hiddenSecIDs = allSecIDs.filter { !LKPreferenceMain().isSectionShowing($0) }
        if hiddenSecIDs.isEmpty {
            accessoryWC.window?.contentView?.isHidden = true
            return
        }
        accessoryWC.window?.contentView?.isHidden = false
        let sections = hiddenSecIDs.compactMap { secID in
            (attrGroup.attrSections ?? []).first { $0.identifier == secID }
        }
        let contentSize = accessoryWC.render(withAttrSections: sections)
        guard let window, let superview else { return }
        let selfFrameInWindow = window.contentView!.convert(frame, from: superview)
        let selfWindowFrame = window.frame
        let panelY = max(selfWindowFrame.origin.y + (selfWindowFrame.height - selfFrameInWindow.origin.y) - contentSize.height, 0)
        var panelX = selfWindowFrame.maxX + 5
        if panelX + contentSize.width > (window.screen?.frame.width ?? panelX + contentSize.width) {
            panelX = selfWindowFrame.origin.x + selfFrameInWindow.minX - contentSize.width - 5
        }
        accessoryWC.window?.setFrame(NSRect(x: panelX, y: panelY, width: contentSize.width, height: contentSize.height), display: true)
    }

    private func shouldShowDetailButton(groupID: LookinAttrGroupIdentifier) -> Bool {
        if groupID == LookinAttrGroup_UserCustom { return false }
        return LookinDashboardBlueprint.sectionIDs(forGroupID: groupID).count > 1
    }

    @objc private func handleRelationHelpButton() {
        let menu = NSMenu()
        let item = NSMenuItem()
        item.image = NSImageMake("Icon_Inspiration_small")
        item.title = NSLocalizedString("How to display more member variables…", comment: "")
        item.target = self
        item.action = #selector(handleRelationDocument)
        menu.addItem(item)
        if let relationHelpButton {
            NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: relationHelpButton)
        }
    }

    @objc private func handleRelationDocument() {
        NSWorkspace.shared.open(URL(string: "https://bytedance.larkoffice.com/docx/CKRndHqdeoub11xSqUZcMlFhnWe")!)
    }
}

extension LKDashboardCardView: LKUserActionManagerDelegate {
    func lkUserActionManager(_ manager: LKUserActionManager, didAct type: LKUserActionType) {
        guard accessoryWC != nil else { return }
        let valid: [LKUserActionType] = [.previewOperation, .dashboardClick, .selectedItemChange]
        if valid.contains(type) { accessoryWC?.close() }
    }
}

extension LKDashboardCardView: LKDashboardAccessoryWindowControllerDelegate {
    func dashboardAccessoryWindowControllerWillClose(_ controller: LKDashboardAccessoryWindowController) {
        sectionViews.forEach { $0.manageState = .none }
        accessoryWC = nil
    }
}
