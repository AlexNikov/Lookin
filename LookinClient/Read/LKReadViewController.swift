//
//  LKReadViewController.swift
//  Lookin
//
//  Created by Li Kai on 2019/5/12.
//  https://lookin.work
//

import AppKit
import LookinShared
import RxSwift

class LKReadViewController: LKBaseViewController, NSSplitViewDelegate {
    private(set) var hierarchyDataSource: LKReadHierarchyDataSource!

    private var splitView: LKSplitView!
    private var splitLeftView: NSView!
    private var splitRightView: NSView!

    private var dashboardController: LKDashboardViewController!
    private var hierarchyController: LKReadHierarchyController!
    private var previewController: LKPreviewController!
    private var measureController: LKMeasureController!
    private var focusTipView: LKYellowTipsView!

    private let disposeBag = DisposeBag()

    init(file: LookinHierarchyFile, preferenceManager: LKPreferenceManager) {
        super.init(containerView: nil)

        hierarchyDataSource = LKReadHierarchyDataSource(file: file, preferenceManager: preferenceManager)

        hierarchyController = LKReadHierarchyController(dataSource: hierarchyDataSource)
        addChild(hierarchyController)
        splitLeftView = hierarchyController.view
        splitView.addArrangedSubview(splitLeftView)

        splitRightView = LKBaseView()
        splitView.addArrangedSubview(splitRightView)

        previewController = LKPreviewController(dataSource: hierarchyDataSource)
        splitRightView.addSubview(previewController.view)
        addChild(previewController)

        dashboardController = LKDashboardViewController(readDataSource: hierarchyDataSource)
        splitRightView.addSubview(dashboardController.view)
        addChild(dashboardController)

        measureController = LKMeasureController(dataSource: hierarchyDataSource)
        measureController.view.isHidden = true
        splitRightView.addSubview(measureController.view)
        addChild(measureController)

        focusTipView = LKYellowTipsView()
        focusTipView.image = NSImageMake("icon_info")
        focusTipView.title = NSLocalizedString("Currently in focus mode", comment: "")
        focusTipView.isHidden = true
        focusTipView.buttonText = NSLocalizedString("Exit", comment: "")
        focusTipView.target = self
        focusTipView.clickAction = #selector(handleExitFocusTipView)
        view.addSubview(focusTipView)

        preferenceManager.measureStateObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, state in
                owner.applyMeasureStateChange(state)
            }
            .disposed(by: disposeBag)

        hierarchyDataSource.stateObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, state in
                let isFocus = state == .focus
                owner.focusTipView.isHidden = !isFocus
                if isFocus {
                    owner.focusTipView.startAnimation()
                } else {
                    owner.focusTipView.endAnimation()
                }
                owner.view.needsLayout = true
            }
            .disposed(by: disposeBag)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func makeContainerView() -> NSView {
        splitView = LKSplitView()
        splitView.didFinishFirstLayout = { view in
            view.setPosition(350, ofDividerAt: 0)
        }
        splitView.arrangesAllSubviews = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        return splitView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        lk(previewController.view).fullFrame()
        lk(dashboardController.view).width(DashboardViewWidth).right(0).fullHeight()
        lk(measureController.view).width(MeasureViewWidth).right(DashboardHorInset).fullHeight()

        let windowTitleHeight = LKNavigationManager.sharedInstance.windowTitleBarHeight
        var tipsY = windowTitleHeight + 10
        if !focusTipView.isHidden {
            let midX = hierarchyController.view.frame.size.width + (previewController.view.frame.size.width - DashboardViewWidth) / 2.0
            lk(focusTipView).sizeToFit().y(tipsY).midX(midX)
            tipsY = focusTipView.frame.maxY + 5
        }
    }

    func currentHierarchyView() -> LKHierarchyView {
        hierarchyController.hierarchyView
    }

    private func applyMeasureStateChange(_ state: LookinMeasureState) {
        let isMeasure = state != .no
        dashboardController.view.isHidden = isMeasure
        measureController.view.isHidden = !isMeasure
    }

    @objc
    private func handleExitFocusTipView() {
        hierarchyDataSource.endFocus()
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        false
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        200
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        700
    }
}
