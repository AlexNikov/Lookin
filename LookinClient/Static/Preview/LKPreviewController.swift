//
//  LKPreviewController.swift
//  Lookin
//
//  Created by Li Kai on 2018/8/6.
//  https://lookin.work
//

import AppKit
import LookinShared
import QuartzCore
import RxSwift

final class LKPreviewController: LKBaseViewController, NSGestureRecognizerDelegate, LKPreviewStageViewDelegate {
    weak var staticViewController: LKStaticViewController?

    private var clickRecognizer: NSClickGestureRecognizer!
    private var panRecognizer: LKPreviewPanGestureRecognizer!
    let dataSource: LKHierarchyDataSource
    private var stageView: LKPreviewStageView!
    var previewView: LKPreviewView!

    var isKeyingDownSpace = false {
        didSet {
            view.window?.invalidateCursorRects(for: view)
            doubleClickRecognizer?.isEnabled = !isKeyingDownSpace
            rightClickRecognizer?.isEnabled = !isKeyingDownSpace
        }
    }
    var isKeyingDownCommand = false {
        didSet { updateQuickSelectingPreference() }
    }
    private var isKeyingDownOption = false {
        didSet { updateMeasureStateFromOptionKey() }
    }

    private var keyUpEventMonitor: Any?
    private var keyMaskFlagsChangedEventMonitor: Any?
    var rightClickMenu: NSMenu!
    var rightClickingDisplayItem: LookinDisplayItem?
    private var doubleClickRecognizer: NSClickGestureRecognizer!
    private var rightClickRecognizer: NSClickGestureRecognizer!

    private let disposeBag = DisposeBag()
    /// Blocks incremental preview render in the same runloop turn as a full hierarchy reload.
    private var skipIncrementalPreviewRender = false

    init(dataSource: LKHierarchyDataSource) {
        self.dataSource = dataSource
        super.init(containerView: nil)

        previewView = LKPreviewView(dataSource: dataSource)
        previewView.preferenceManager = dataSource.preferenceManager()
        previewView.alphaValue = 0
        previewView.appScreenSize = Self.previewAppScreenSize(from: dataSource)
        let pm = dataSource.preferenceManager()
        previewView.showHiddenItems = pm.showHiddenItems
        pm.showHiddenItemsObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, showHidden in
                owner.previewView.showHiddenItems = showHidden
                owner.previewView.updateZPosition()
                LookinUITestSupport.publishPreviewStructureIfNeeded()
            }
            .disposed(by: disposeBag)

        stageView.didChangeAppearanceBlock = { [weak self] _, isDarkMode in
            self?.previewView.isDarkMode = isDarkMode
        }
        view.addSubview(previewView)

        Observable.merge(
            dataSource.didReloadHierarchyInfo,
            dataSource.itemDidChangeNoPreview
        )
        .observe(on: MainScheduler.instance)
        .subscribe(with: self, onNext: { owner, _ in
            owner.skipIncrementalPreviewRender = true
            owner.renderPreview(discardCache: true)
            if !owner.dataSource.lastReloadKeptState {
                owner.fitScaleToContentIfNeeded()
            }
            DispatchQueue.main.async {
                owner.skipIncrementalPreviewRender = false
            }
        })
        .disposed(by: disposeBag)

        dataSource.didReloadFlatItemsWithSearchOrFocus
            .observe(on: MainScheduler.instance)
            .subscribe(with: self, onNext: { owner, _ in
                guard !owner.skipIncrementalPreviewRender else { return }
                // Incremental render (discardCache:NO) left orphan SCN nodes when validItems count
                // changed after search/focus — looked like duplicated layer stacks on reload.
                owner.renderPreview(discardCache: true)
            })
            .disposed(by: disposeBag)

        // Hierarchy often reloads before the static inspector creates this controller (launch → reload → showStaticWorkspace).
        DispatchQueue.main.async { [weak self] in
            self?.renderIfHierarchyAlreadyLoaded()
        }

        var signalsToUpdateZIndex: [Observable<Void>] = [
            dataSource.displayingFlatItemsObservable.map { _ in () },
        ]
        if let staticSource = dataSource as? LKStaticHierarchyDataSource {
            signalsToUpdateZIndex.append(staticSource.itemDidChangeHiddenAlphaValue.map { _ in () })
            signalsToUpdateZIndex.append(staticSource.itemsDidChangeFrame.map { _ in () })
        }
        Observable.merge(signalsToUpdateZIndex)
            .skip(1)
            .observe(on: MainScheduler.instance)
            .subscribe(with: self, onNext: { owner, _ in
                owner.previewView.updateZPosition()
            })
            .disposed(by: disposeBag)

        panRecognizer = LKPreviewPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panRecognizer.delegate = self
        previewView.addGestureRecognizer(panRecognizer)

        clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleClickGesture(_:)))
        clickRecognizer.numberOfClicksRequired = 1
        clickRecognizer.delegate = self
        previewView.addGestureRecognizer(clickRecognizer)

        doubleClickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickRecognizer.numberOfClicksRequired = 2
        previewView.addGestureRecognizer(doubleClickRecognizer)

        rightClickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleRightClick(_:)))
        rightClickRecognizer.buttonMask = 0x2
        rightClickRecognizer.numberOfClicksRequired = 1
        previewView.addGestureRecognizer(rightClickRecognizer)

        rightClickMenu = NSMenu()
        rightClickMenu.autoenablesItems = false
        rightClickMenu.delegate = self

        keyUpEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            if event.type == .keyUp, event.charactersIgnoringModifiers == " " {
                self?.isKeyingDownSpace = false
                self?.view.window?.invalidateCursorRects(for: self?.view ?? NSView())
            }
            return event
        }
        keyMaskFlagsChangedEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.isKeyingDownCommand = event.modifierFlags.contains(.command)
            self?.isKeyingDownOption = event.modifierFlags.contains(.option)
            return event
        }

        pm.previewScaleObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, scale in
                owner.previewView.scale = CGFloat(scale)
            }
            .disposed(by: disposeBag)

        pm.previewDimensionObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, rawValue in
                owner.applyPreviewDimensionChange(rawValue)
            }
            .disposed(by: disposeBag)

        pm.freeRotationObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, enabled in
                owner.applyFreeRotationChange(enabled)
            }
            .disposed(by: disposeBag)

        pm.zInterspaceObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, z in
                owner.previewView.zInterspace = CGFloat(z)
            }
            .disposed(by: disposeBag)

        dataSource.rawHierarchyInfoObservable
            .skip(1)
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, _ in
                owner.hierarchyInfoDidChange()
            }
            .disposed(by: disposeBag)

        dataSource.selectedItemObservable
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, item in
                owner.previewView.didSelectItem(item)
            }
            .disposed(by: disposeBag)

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, note.object as? NSWindow === self.view.window else { return }
            self.isKeyingDownSpace = false
            self.isKeyingDownOption = false
            self.isKeyingDownCommand = false
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let keyUpEventMonitor {
            NSEvent.removeMonitor(keyUpEventMonitor)
        }
        if let keyMaskFlagsChangedEventMonitor {
            NSEvent.removeMonitor(keyMaskFlagsChangedEventMonitor)
        }
    }

    override func makeContainerView() -> NSView {
        let stage = LKPreviewStageView()
        stage.didChangeAppearanceBlock = { view, isDarkMode in
            view.backgroundColor = LookinClientIsDarkMode() ? LookinColorMake(0, 0, 0) : LookinColorMake(255, 255, 255)
        }
        stage.delegate = self
        stageView = stage
        return stage
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        let titleBarHeight = LKNavigationManager.sharedInstance.windowTitleBarHeight
        let contentWidth = max(0, view.bounds.width - DashboardViewWidth)
        // Extend left of the preview area (not under the dashboard) for 3D centering when rotated.
        let previewWidth = contentWidth + DashboardViewWidth - DashboardHorInset - 20
        let previewHeight = view.bounds.height + titleBarHeight
        previewView.frame = NSRect(
            x: contentWidth - previewWidth,
            y: 0,
            width: previewWidth,
            height: previewHeight
        )
        previewView.layoutTopExtraHeight = CGFloat(titleBarHeight)
        previewView.layoutLeadingExtraWidth = max(0, previewWidth - contentWidth)

        let hasLayouted = lookin_getBindBOOL(forKey: "hasLayouted")
        if !hasLayouted {
            lookin_bindBOOL(true, forKey: "hasLayouted")
            previewView.setRotation(CGPoint(x: 0.8, y: 0), animated: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + LKUITiming.previewLayoutSettle) { [weak self] in
                guard let self else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 1
                    self.previewView.animator().alphaValue = 1
                }
                let timing = CAMediaTimingFunction(controlPoints: 0.3, 0.93, 0.26, 0.88)
                self.previewView.setRotation(
                    CGPoint(x: 0.6, y: 0),
                    animated: true,
                    timingFunction: timing,
                    duration: 1.5
                )
            }
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        renderIfHierarchyAlreadyLoaded()
        view.window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            isKeyingDownSpace = true
            return
        }
        if dataSource.keyDown(event) { return }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            isKeyingDownSpace = false
            return
        }
        super.keyUp(with: event)
    }

    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        if event.phase == .changed {
            let manager = dataSource.preferenceManager()
            var targetScale = manager.previewScale + event.magnification * 0.3
            targetScale = max(min(targetScale, 1), 0)
            manager.previewScale = targetScale
        }
    }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        if isKeyingDownCommand {
            let manager = dataSource.preferenceManager()
            var targetScale = manager.previewScale - event.deltaY * 0.005
            targetScale = max(min(targetScale, LookinPreviewMaxScale), LookinPreviewMinScale)
            manager.previewScale = targetScale
        } else {
            let currentScale = previewView.scale
            let factor = (1 - currentScale) * 0.7 + 0.3
            var translation = previewView.translation
            translation.x += event.deltaX * 0.04 * factor
            translation.y -= event.deltaY * 0.04 * factor
            previewView.translation = translation

            if let staticViewController,
               !TutorialMng.hasAlreadyShowedTipsThisLaunch,
               !TutorialMng.moveWithSpace {
                TutorialMng.moveWithSpace = true
                staticViewController.showMoveWithSpaceTutorialTips()
            }
        }
    }

    // MARK: - NSGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldAttemptToRecognizeWith event: NSEvent
    ) -> Bool {
        #if DEBUG
        if gestureRecognizer === clickRecognizer, event.locationInWindow.y <= 25 {
            return false
        }
        #endif
        if gestureRecognizer === panRecognizer {
            if previewView.dimension != .dimension3D, !isKeyingDownSpace {
                return false
            }
        }
        return true
    }

    // MARK: - LKPreviewStageViewDelegate

    func previewStageView(_ view: LKPreviewStageView, mouseMoved event: NSEvent) {
        if isKeyingDownSpace {
            if dataSource.hoveredItem != nil {
                dataSource.hoveredItem = nil
            }
            return
        }
        var rawPoint = event.locationInWindow
        rawPoint.y = (view.window?.frame.size.height ?? 0) - rawPoint.y
        guard let contentView = view.window?.contentView,
              contentView.hitTest(rawPoint) === previewView else {
            if dataSource.hoveredItem != nil {
                dataSource.hoveredItem = nil
            }
            return
        }
        let point = previewView.convert(rawPoint, from: contentView)
        let item = previewView.displayItem(at: point)
        if dataSource.hoveredItem !== item {
            dataSource.hoveredItem = item
        }
    }

    func previewStageView(_ view: LKPreviewStageView, mouseExited event: NSEvent) {
        if dataSource.hoveredItem != nil {
            dataSource.hoveredItem = nil
        }
    }

    func didResetCursorRects(in previewStageView: LKPreviewStageView) {
        if isKeyingDownSpace {
            previewStageView.addCursorRect(view.bounds, cursor: .openHand)
        }
    }

    // MARK: - Preference handlers

    private func applyFreeRotationChange(_ enabled: Bool) {
        if enabled {
            if previewView.dimension == .dimension3D {
                var rotation = previewView.rotation
                rotation.y = -0.05
                previewView.setRotation(rotation, animated: true)
            }
        } else {
            var rotation = previewView.rotation
            if rotation.y == 0 { return }
            rotation.y = 0
            previewView.setRotation(rotation, animated: true)
        }
    }

    private func applyPreviewDimensionChange(_ rawValue: Int) {
        let newDimension = LookinPreviewDimension(rawValue: UInt(rawValue)) ?? .dimension3D
        if previewView.dimension == newDimension { return }

        if newDimension == .dimension2D {
            lookin_bindPoint(previewView.rotation, forKey: "prevRotation")
            previewView.setDimension(.dimension2D, animated: true)
        } else {
            var rotation = lookin_getBindPoint(forKey: "prevRotation")
            previewView.setDimension(.dimension3D, animated: true)
            if rotation.x >= 0 {
                rotation.x = max(0.18, rotation.x)
            } else if rotation.x < 0 {
                rotation.x = min(-0.18, rotation.x)
            }
            if !dataSource.preferenceManager().freeRotation {
                rotation.y = 0
            }
            previewView.setRotation(rotation, animated: true)
        }
    }

    private func renderIfHierarchyAlreadyLoaded() {
        guard !(dataSource.flatItems?.isEmpty ?? true) else { return }
        renderPreview(discardCache: true)
    }

    private func renderPreview(discardCache: Bool) {
        let validItems = (dataSource.flatItems ?? []).filter { obj in
            if obj.inNoPreviewHierarchy { return false }
            if let custom = obj.customInfo {
                return custom.hasValidFrame()
            }
            return true
        }
        previewView.render(with: validItems, discardCache: discardCache)
    }

    private static func previewAppScreenSize(from dataSource: LKHierarchyDataSource) -> CGSize {
        let appInfo = dataSource.rawHierarchyInfo?.appInfo
            ?? (dataSource as? LKStaticHierarchyDataSource)?.appInfo
            ?? LKAppsManager.sharedInstance.inspectingApp?.appInfo
        return CGSize(
            width: CGFloat(appInfo?.screenWidth ?? 0),
            height: CGFloat(appInfo?.screenHeight ?? 0)
        )
    }

    /// Zooms out the preview if off-screen content (e.g. cells outside a UIScrollView's viewport)
    /// extends beyond what the current scale can show. Never zooms in.
    private func fitScaleToContentIfNeeded() {
        guard let items = dataSource.flatItems else { return }
        let screenSize = previewView.appScreenSize
        guard screenSize.width > 0, screenSize.height > 0 else { return }

        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        var hasItem = false

        for item in items {
            guard item.hasValidFrameToRoot() else { continue }
            let f = item.calculateFrameToRoot()
            guard f.width > 0, f.height > 0 else { continue }
            minX = min(minX, f.minX)
            maxX = max(maxX, f.maxX)
            minY = min(minY, f.minY)
            maxY = max(maxY, f.maxY)
            hasItem = true
        }

        guard hasItem else { return }

        // Max extent from screen centre in iOS points — same coordinate space as node placement.
        let cx = screenSize.width / 2
        let cy = screenSize.height / 2
        let halfExtent = max(
            max(abs(minX - cx), abs(maxX - cx)),
            max(abs(minY - cy), abs(maxY - cy))
        )

        // Camera Z=34, sensorHeight=24: visibleHalfPts = 40800 / focalLength
        // focalLength = 20 + scale² × 730  →  scale = √((focalLength − 20) / 730)
        let focalLength = 40800.0 / (halfExtent * 1.12)
        let scaleSquared = (focalLength - 20.0) / 730.0
        let fitScale: CGFloat = scaleSquared > 0
            ? min(CGFloat(sqrt(scaleSquared)), LookinPreviewMaxScale)
            : LookinPreviewMinScale

        let current = dataSource.preferenceManager().previewScale
        if fitScale < CGFloat(current) {
            dataSource.preferenceManager().previewScale = Double(fitScale)
        }
    }

    private func hierarchyInfoDidChange() {
        guard let currentInfo = dataSource.rawHierarchyInfo else {
            // Session teardown (window close / MCP reconnect) clears hierarchy before the window is gone.
            lookin_bindObject(nil, forKey: "prevRawHierarchyInfo")
            return
        }
        previewView.appScreenSize = Self.previewAppScreenSize(from: dataSource)

        let prevInfo = lookin_getBindObject(forKey: "prevRawHierarchyInfo") as? LookinHierarchyInfo
        lookin_bindObject(currentInfo, forKey: "prevRawHierarchyInfo")
        guard let prevInfo else { return }

        if (prevInfo.appInfo?.screenWidth ?? 0) == (currentInfo.appInfo?.screenWidth ?? 0),
           (prevInfo.appInfo?.screenHeight ?? 0) == (currentInfo.appInfo?.screenHeight ?? 0) {
            return
        }
        dataSource.preferenceManager().previewScale = LKInitialPreviewScale
    }

    private func updateQuickSelectingPreference() {
        let pm = dataSource.preferenceManager()
        if isKeyingDownCommand, view.window?.isKeyWindow == true {
            pm.isQuickSelecting = true
        } else {
            pm.isQuickSelecting = false
        }
    }

    private func updateMeasureStateFromOptionKey() {
        let pm = dataSource.preferenceManager()
        if pm.measureState == .locked {
            return
        }
        let state: LookinMeasureState
        if isKeyingDownOption, dataSource.selectedItem != nil, view.window?.isKeyWindow == true {
            state = .unlocked
        } else {
            state = .no
        }
        pm.measureState = state
    }
}
