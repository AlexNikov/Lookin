import AppKit
import LookinShared
import RxSwift
import AppCenter
import AppCenterAnalytics

protocol LKDashboardCardViewDelegate: AnyObject {
    func dashboardCardViewNeedToggleCollapse(_ view: LKDashboardCardView)
}

protocol LKDashboardHeaderViewDelegate: AnyObject {
    func dashboardHeaderView(_ view: LKDashboardHeaderView, didToggleActive isActive: Bool)
    func dashboardHeaderView(_ view: LKDashboardHeaderView, didInputString string: String)
}

protocol LKDashboardSearchPropViewDelegate: AnyObject {
    func dashboardSearchPropView(_ view: LKDashboardSearchPropView, didClickRevealAttribute attr: LookinAttribute)
}

protocol LKDashboardSearchMethodsViewDelegate: AnyObject {
    func dashboardSearchMethodsView(_ view: LKDashboardSearchMethodsView, requestToInvokeMethod method: String, oid: UInt)
}

final class LKDashboardViewController: LKBaseViewController {
    private var scrollView: NSScrollView!
    private var documentView: LKBaseView!
    private var cardContainerView: LKBaseView!
    private var groupList: [LookinAttributesGroup] = []
    private var cardViews: [String: LKDashboardCardView] = [:]
    private var searchContainerView: LKBaseView!
    private var headerView: LKDashboardHeaderView!
    private var searchPropViews: [LKDashboardSearchPropView] = []
    private var searchMethodsView: LKDashboardSearchMethodsView?
    private var methodsDataSource: LKDashboardSearchMethodsDataSource?
    private var staticDataSource: LKStaticHierarchyDataSource?
    private var readDataSource: LKReadHierarchyDataSource?
    private let disposeBag = DisposeBag()

    private(set) var isStaticMode = false

    init(staticDataSource: LKStaticHierarchyDataSource) {
        self.staticDataSource = staticDataSource
        isStaticMode = true
        super.init(containerView: nil)
        didInitialized()
    }

    init(readDataSource: LKReadHierarchyDataSource) {
        self.readDataSource = readDataSource
        isStaticMode = false
        super.init(containerView: nil)
        didInitialized()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func makeContainerView() -> NSView {
        let containerView = LKBaseView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        documentView = LKBaseView()
        scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.contentView.documentView = documentView
        containerView.addSubview(scrollView)

        headerView = LKDashboardHeaderView()
        headerView.delegate = self
        documentView.addSubview(headerView)

        cardContainerView = LKBaseView()
        documentView.addSubview(cardContainerView)

        searchContainerView = LKBaseView()
        searchContainerView.isHidden = true
        documentView.addSubview(searchContainerView)
        return containerView
    }

    private func didInitialized() {
        cardViews = [:]
        searchPropViews = []

        if let staticDataSource {
            staticDataSource.selectedItemObservable
                .observe(on: MainScheduler.instance)
                .subscribe(with: self) { owner, _ in
                    let item = staticDataSource.selectedItem
                    let groups = item?.queryAllAttrGroupList() ?? []
                    owner.reload(withGroupList: groups)
                    if groups.isEmpty {
                        LKStaticAsyncUpdateManager.sharedInstance.scheduleSelectedItemAttributesFetch(item)
                    }
                }
                .disposed(by: disposeBag)

            staticDataSource.itemDidChangeAttrGroup
                .observe(on: MainScheduler.instance)
                .subscribe(with: self, onNext: { owner, item in
                    let selectedOid = staticDataSource.selectedItem?.layerObject?.oid
                    guard selectedOid != nil, selectedOid == item.layerObject?.oid else { return }
                    owner.reload(withGroupList: item.queryAllAttrGroupList())
                })
                .disposed(by: disposeBag)

            methodsDataSource = LKDashboardSearchMethodsDataSource()
            staticDataSource.didReloadHierarchyInfo
                .observe(on: MainScheduler.instance)
                .subscribe(with: self, onNext: { owner, _ in
                    owner.methodsDataSource?.clearAllCache()
                    owner.reload(withGroupList: staticDataSource.selectedItem?.queryAllAttrGroupList() ?? [])
                })
                .disposed(by: disposeBag)

            reload(withGroupList: staticDataSource.selectedItem?.queryAllAttrGroupList() ?? [])
        } else if let readDataSource {
            readDataSource.selectedItemObservable
                .observe(on: MainScheduler.instance)
                .subscribe(with: self) { owner, _ in
                    owner.reload(withGroupList: readDataSource.selectedItem?.queryAllAttrGroupList() ?? [])
                }
                .disposed(by: disposeBag)
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(NotificationName_DidChangeSectionShowing),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.reload(withGroupList: self.currentDataSource()?.selectedItem?.queryAllAttrGroupList() ?? [])
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        lk(scrollView).fullFrame()
        let verMargin: CGFloat = 10
        let contentWidth = DashboardViewWidth - DashboardHorInset * 2
        lk(headerView).width(contentWidth).x(DashboardHorInset).height(23).y(10)

        if !cardContainerView.isHidden {
            lk(cardContainerView).width(contentWidth).x(DashboardHorInset).y(headerView.frame.maxY + verMargin)
            var y: CGFloat = 0
            for group in groupList {
                guard let cardView = cardViews[group.uniqueKey() ?? ""], !cardView.isHidden else { continue }
                lk(cardView).width(contentWidth).y(y).heightToFit()
                y = cardView.frame.maxY + verMargin
            }
            lk(cardContainerView).height(y)
        }

        if !searchContainerView.isHidden {
            lk(searchContainerView).width(contentWidth).x(DashboardHorInset).y(headerView.frame.maxY + verMargin)
            var y: CGFloat = 0
            for propView in searchPropViews where !propView.isHidden {
                lk(propView).width(contentWidth).x(0).heightToFit().y(y)
                y = propView.frame.maxY + verMargin
            }
            if searchMethodsView?.lk_clientIsVisible == true, let searchMethodsView {
                lk(searchMethodsView).width(contentWidth).y(y).heightToFit()
                y = searchMethodsView.frame.maxY
            }
            lk(searchContainerView).height(y)
        }

        var documentMaxY = headerView.frame.maxY + verMargin
        if !cardContainerView.isHidden {
            documentMaxY = max(documentMaxY, cardContainerView.frame.maxY)
        }
        if !searchContainerView.isHidden {
            documentMaxY = max(documentMaxY, searchContainerView.frame.maxY)
        }
        lk(documentView).fullWidth().y(0).toMaxY(documentMaxY)
    }

    func reload(withGroupList list: [LookinAttributesGroup]) {
        groupList = list
        guard !list.isEmpty else {
            scrollView.isHidden = false
            cardContainerView.isHidden = true
            view.needsLayout = true
            return
        }
        scrollView.isHidden = false
        cardContainerView.isHidden = false
        var needlessViews = Array(cardViews.values)
        for group in list {
            var cardView = cardViews[group.uniqueKey() ?? ""]
            if cardView == nil {
                cardView = LKDashboardCardView()
                cardView?.dashboardViewController = self
                cardView?.delegate = self
                cardViews[group.uniqueKey() ?? ""] = cardView
                cardContainerView.addSubview(cardView!)
            } else {
                needlessViews.removeAll { $0 === cardView }
            }
            cardView?.isHidden = false
            cardView?.attrGroup = group
            cardView?.isCollapsed = LKPreferenceMain().collapsedAttrGroups.contains(group.identifier ?? "")
            cardView?.render()
        }
        needlessViews.forEach { $0.isHidden = true }
        view.needsLayout = true
    }

    func modifyAttribute(_ attribute: LookinAttribute, newValue: AttributeValue?) -> Single<Void> {
        if attribute.isUserCustom() {
            return modifyCustomAttribute(attribute, newValue: newValue)
        }
        return modifyInbuiltAttribute(attribute, newValue: newValue)
    }

    func currentDataSource() -> LKHierarchyDataSource? {
        staticDataSource ?? readDataSource
    }

    private func modifyCustomAttribute(_ attribute: LookinAttribute, newValue: AttributeValue?) -> Single<Void> {
        LKReactiveBridge.singleSignal { sendSuccess, sendError in
            var modification = LookinCustomAttrModification()
            modification.customSetterID = attribute.customSetterID
            modification.attrType = attribute.attrType
            modification.value = newValue
            guard let setterID = modification.customSetterID, !setterID.isEmpty else {
                assertionFailure()
                AlertError(LKLookinClientErrors.inner, self.view.window)
                sendError(LKLookinClientErrors.inner)
                return nil
            }
            guard let app = LKAppsManager.sharedInstance.inspectingApp else {
                AlertError(LKLookinClientErrors.noConnect, self.view.window)
                sendError(LKLookinClientErrors.noConnect)
                return nil
            }
            LookinDiagLog.log(
                "client custom send setterID=\(setterID) attrType=\(attribute.attrType.rawValue) value=\(String(describing: newValue))"
            )
            let d = app.submitCustomModification(modification).subscribe(
                onCompleted: {
                    LookinDiagLog.log("client custom OK setterID=\(setterID)")
                    attribute.value = newValue
                    sendSuccess(())
                },
                onError: { error in
                    let nsError = error as NSError? ?? LKLookinClientErrors.inner
                    LookinDiagLog.log("client custom FAIL code=\(nsError.code) \(nsError.localizedDescription)")
                    AlertError(nsError, self.view.window)
                    sendError(error)
                }
            )
            return { d.dispose() }
        }
    }

    /// Hidden/Opacity only update visibility — screenshot patch blocks main and times out on UIView.
    private static func shouldFetchScreenshotPatch(afterModifying attribute: LookinAttribute) -> Bool {
        let id = attribute.identifier ?? ""
        if id == LookinAttr_ViewLayer_Visibility_Hidden || id == LookinAttr_ViewLayer_Visibility_Opacity {
            return false
        }
        return LookinDashboardBlueprint.needPatchAfterModification(withAttrID: id)
    }

    private static func inbuiltModificationTargetOid(
        for attribute: LookinAttribute,
        item: LookinDisplayItem
    ) -> UInt {
        let attrID = attribute.identifier ?? ""
        if attrID == LookinAttr_ViewLayer_Visibility_Hidden || attrID == LookinAttr_ViewLayer_Visibility_Opacity {
            // CALayer-only items (e.g. DogLayer oid 17) have no viewObject — use layer oid.
            if item.viewObject == nil, let layerOid = item.layerObject?.oid, layerOid != 0 {
                return layerOid
            }
            if let viewOid = item.viewObject?.oid, viewOid != 0 {
                return viewOid
            }
            return item.layerObject?.oid ?? 0
        }
        if LookinDashboardBlueprint.isUIViewProperty(withAttrID: attrID) {
            if let viewOid = item.viewObject?.oid, viewOid != 0 {
                return viewOid
            }
            return item.layerObject?.oid ?? 0
        }
        return item.layerObject?.oid ?? 0
    }

    private func modifyInbuiltAttribute(_ attribute: LookinAttribute, newValue: AttributeValue?) -> Single<Void> {
        LKReactiveBridge.singleSignal { sendSuccess, sendError in
            guard let modifyingItem = attribute.targetDisplayItem ?? self.staticDataSource?.selectedItem else {
                sendError(LKLookinClientErrors.inner)
                return nil
            }
            attribute.targetDisplayItem = modifyingItem
            var modification = LookinAttributeModification()
            modification.clientReadableVersion = LKHelper.lookinReadableVersion()
            modification.targetOid = Self.inbuiltModificationTargetOid(for: attribute, item: modifyingItem)
            guard modification.targetOid != 0 else {
                sendError(LKLookinClientErrors.inner)
                return nil
            }
            guard let setter = LookinDashboardBlueprint.setter(withAttrID: attribute.identifier ?? "") else {
                assertionFailure()
                AlertError(LKLookinClientErrors.inner, self.view.window)
                sendError(LKLookinClientErrors.inner)
                return nil
            }
            modification.setterSelector = setter
            modification.attrIdentifier = attribute.identifier
            modification.attrType = attribute.attrType
            modification.value = newValue
            LookinDiagLog.log(
                "client inbuilt send oid=\(modification.targetOid) attr=\(attribute.identifier ?? "?") item=\(modifyingItem.title() ?? "?") value=\(String(describing: newValue))"
            )
            guard let app = LKAppsManager.sharedInstance.inspectingApp else {
                AlertError(LKLookinClientErrors.noConnect, self.view.window)
                sendError(LKLookinClientErrors.noConnect)
                return nil
            }
            app.cancelInbuiltModification()
            let d = app.submitInbuiltModification(modification).subscribe(
                onSuccess: { detail in
                    LookinDiagLog.log(
                        "client inbuilt OK detailOid=\(detail.displayItemOid) hidden=\(detail.hiddenValue?.boolValue ?? false)"
                    )
                    if let staticDataSource = self.staticDataSource {
                        LKDashboardTextControlEditingFlag.sharedInstance.shouldIgnoreTextEditingChangeEvent = true
                        staticDataSource.modify(with: detail)
                        LKDashboardTextControlEditingFlag.sharedInstance.shouldIgnoreTextEditingChangeEvent = false
                        if Self.shouldFetchScreenshotPatch(afterModifying: attribute) {
                            LKStaticAsyncUpdateManager.sharedInstance.updateAfterModifyingDisplayItem(modifyingItem)
                        }
                    } else {
                        assertionFailure()
                    }
                    sendSuccess(())
                },
                onFailure: { error in
                    let nsError = error as NSError? ?? LKLookinClientErrors.inner
                    LookinDiagLog.log(
                        "client inbuilt FAIL code=\(nsError.code) \(nsError.localizedDescription)"
                    )
                    if nsError.code != Int(LookinErrCode_Discard) {
                        AlertError(nsError, self.view.window)
                    }
                    sendError(nsError)
                }
            )
            return { d.dispose() }
        }
    }
}

extension LKDashboardViewController: LKDashboardCardViewDelegate {
    func dashboardCardViewNeedToggleCollapse(_ view: LKDashboardCardView) {
        guard let dataSource = currentDataSource(),
              let identifier = view.attrGroup?.identifier else { return }
        let prefManager = dataSource.preferenceManager()
        if prefManager.collapsedAttrGroups.contains(identifier) {
            view.isCollapsed = false
            prefManager.collapsedAttrGroups = prefManager.collapsedAttrGroups.lookin_arrayByRemovingObject(identifier)
        } else {
            view.isCollapsed = true
            prefManager.collapsedAttrGroups = prefManager.collapsedAttrGroups + [identifier]
        }
        self.view.needsLayout = true
    }
}

extension LKDashboardViewController: LKDashboardHeaderViewDelegate {
    func dashboardHeaderView(_ view: LKDashboardHeaderView, didInputString searchString: String) {
        guard searchString.count >= 3 else {
            searchContainerView.isHidden = true
            return
        }
        Analytics.trackEvent("SearchAttr")
        let lowered = searchString.lowercased()
        var resultAttrs: [LookinAttribute] = []
        for group in currentDataSource()?.selectedItem?.queryAllAttrGroupList() ?? [] {
            for section in group.attrSections ?? [] {
                for attr in section.attributes ?? [] {
                    let title = attr.isUserCustom() ? attr.displayTitle : LookinDashboardBlueprint.fullTitle(withAttrID: attr.identifier ?? "")
                    if title?.lowercased().contains(lowered) == true {
                        resultAttrs.append(attr)
                    }
                }
            }
        }
        searchPropViews = resultAttrs.count.lookin_dequeue(
            existing: searchPropViews,
            add: { [weak self] _ in
                let v = LKDashboardSearchPropView()
                v.delegate = self
                self?.searchContainerView.addSubview(v)
                return v
            },
            hideExtra: { $0.isHidden = true },
            configure: { idx, v in
                v.render(with: resultAttrs[Int(idx)])
                v.isHidden = false
            }
        )
        guard currentDataSource() === staticDataSource else {
            searchContainerView.isHidden = false
            searchMethodsView?.isHidden = true
            self.view.needsLayout = true
            return
        }
        if searchMethodsView == nil {
            let methodsView = LKDashboardSearchMethodsView()
            methodsView.delegate = self
            searchContainerView.addSubview(methodsView)
            searchMethodsView = methodsView
        }
        guard let selectedObj = currentDataSource()?.selectedItem?.viewObject ?? currentDataSource()?.selectedItem?.layerObject,
              let className = selectedObj.rawClassName() else { return }
        LookinRACSignalRx.observeMainThread(
            methodsDataSource!.fetchNonArgMethodsList(withClass: className)
        )
        .subscribe(with: self, onSuccess: { owner, methods in
            if searchString != owner.headerView.currentInputString() { return }
            let searched = LKHelper.bestMatchesInCandidates(methods, input: searchString, maxResultsCount: 5)
            owner.searchMethodsView?.render(withMethods: searched, oid: selectedObj.oid)
            owner.searchContainerView.isHidden = false
            owner.view.needsLayout = true
        }, onFailure: { owner, error in
            if searchString != owner.headerView.currentInputString() { return }
            owner.searchMethodsView?.render(with: error as NSError)
            owner.searchContainerView.isHidden = false
            owner.view.needsLayout = true
        })
        .disposed(by: disposeBag)
    }

    func dashboardHeaderView(_ view: LKDashboardHeaderView, didToggleActive isActive: Bool) {
        if isActive {
            cardContainerView.animator().isHidden = true
            currentDataSource()?.shouldAvoidChangingPreviewSelectionDueToDashboardSearch = true
        } else {
            cardContainerView.animator().isHidden = false
            searchContainerView.animator().isHidden = true
            self.view.needsLayout = true
            DispatchQueue.main.asyncAfter(deadline: .now() + LKUITiming.dashboardSearchPreviewGuard) {
                if !view.isActive {
                    self.currentDataSource()?.shouldAvoidChangingPreviewSelectionDueToDashboardSearch = false
                }
            }
        }
    }
}

extension LKDashboardViewController: LKDashboardSearchMethodsViewDelegate {
    func dashboardSearchMethodsView(_ view: LKDashboardSearchMethodsView, requestToInvokeMethod method: String, oid: UInt) {
        Analytics.trackEvent("ClickServerAttr")
        guard let app = LKAppsManager.sharedInstance.inspectingApp,
              oid != 0,
              !method.isEmpty else {
            let error = oid == 0 || method.isEmpty
                ? LKLookinClientErrors.inner
                : LKLookinClientErrors.noConnect
            AlertError(error, view.window)
            return
        }
        LookinRACSignalRx.observeMainThread(app.invokeMethod(withOid: oid, text: method))
            .subscribe(with: self, onSuccess: { owner, dict in
                let alert = NSAlert()
                alert.messageText = method
                alert.informativeText = dict["description"] as? String ?? ""
                alert.alertStyle = .informational
                if let window = owner.view.window {
                    alert.beginSheetModal(for: window)
                }
            }, onFailure: { owner, error in
                AlertError(error as NSError, owner.view.window)
            })
            .disposed(by: disposeBag)
    }
}

extension LKDashboardViewController: LKDashboardSearchPropViewDelegate {
    func dashboardSearchPropView(_ view: LKDashboardSearchPropView, didClickRevealAttribute clickedAttr: LookinAttribute) {
        headerView.isActive = false
        var targetGroup: LookinAttributesGroup?
        var targetSection: LookinAttributesSection?
        outer: for group in currentDataSource()?.selectedItem?.queryAllAttrGroupList() ?? [] {
            for section in group.attrSections ?? [] {
                for attr in section.attributes ?? [] where attr === clickedAttr {
                    if let secID = section.identifier,
                       !LKPreferenceMain().isSectionShowing(secID) {
                        LKPreferenceMain().showSection(secID)
                    }
                    targetGroup = group
                    targetSection = section
                    break outer
                }
            }
        }
        guard let targetGroup, let targetSection,
              let targetCardView = cardViews[targetGroup.uniqueKey() ?? ""] else {
            assertionFailure()
            return
        }
        if targetCardView.isCollapsed {
            dashboardCardViewNeedToggleCollapse(targetCardView)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + LKUITiming.dashboardLayoutSettle) {
            guard let targetSecView = targetCardView.querySectionView(with: targetSection) else { return }
            let rect = self.scrollView.contentView.convert(targetSecView.frame, from: targetSecView.superview)
            self.scrollView.contentView.animator().scroll(to: rect.origin)
            for cardView in self.cardViews.values where !cardView.isHidden {
                if cardView === targetCardView {
                    cardView.playFadeAnimation(withHighlightRect: cardView.convert(targetSecView.frame, from: targetSecView.superview))
                } else {
                    cardView.playFadeAnimation(withHighlightRect: .zero)
                }
            }
        }
    }
}

private extension Int {
    func lookin_dequeue<T: NSView>(
        existing: [T],
        add: (Int) -> T,
        hideExtra: (T) -> Void,
        configure: (Int, T) -> Void
    ) -> [T] {
        var views = existing
        while views.count < self {
            views.append(add(views.count))
        }
        while views.count > self {
            views.removeLast()
        }
        for idx in 0..<self {
            configure(idx, views[idx])
        }
        if views.count > self {
            views.suffix(from: self).forEach(hideExtra)
        }
        return views
    }
}
