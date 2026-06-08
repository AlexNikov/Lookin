//
//  LKPreferenceManager.swift
//  Lookin
//
//  Created by Li Kai on 2019/1/8.
//  https://lookin.work
//

import AppCenter
import AppCenterAnalytics
import Foundation
import LookinShared
import RxRelay
import RxSwift

let NotificationName_DidChangeSectionShowing = "NotificationName_DidChangeSectionShowing"
let LKWindowSizeName_Dynamic = "LKWindowSizeName_Dynamic"
let LKWindowSizeName_Static = "LKWindowSizeName_Static"
enum LookinPreferredAppeanranceType: Int {
    case dark = 0
    case light = 1
    case system = 2
}

enum LookinDoubleClickBehavior: Int {
    case collapse = 0
    case focus = 1
}

enum LookinPreferredCallStackType: Int {
    case `default` = 0
    case formattedCompletely = 1
    case raw = 2
}

enum LookinMeasureState: Int {
    case no = 0
    case unlocked = 1
    case locked = 2
}

class LKPreferenceManager: NSObject {
    private static let _main: LKPreferenceManager = {
        let manager = LKPreferenceManager()
        manager.shouldStoreToLocal = true
        return manager
    }()

    class func mainManager() -> LKPreferenceManager {
        _main
    }

    var shouldStoreToLocal = false

    private let appearanceTypeRelay = BehaviorRelay<LookinPreferredAppeanranceType>(value: .system)
    var appearanceTypeObservable: Observable<LookinPreferredAppeanranceType> {
        appearanceTypeRelay.asObservable()
    }

    var appearanceType: LookinPreferredAppeanranceType {
        get { appearanceTypeRelay.value }
        set {
            let oldValue = appearanceTypeRelay.value
            guard newValue != oldValue else { return }
            appearanceTypeRelay.accept(newValue)
            guard shouldStoreToLocal else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: Key.appearanceType)
        }
    }

    var doubleClickBehavior: LookinDoubleClickBehavior = .collapse {
        didSet {
            guard shouldStoreToLocal else { return }
            UserDefaults.standard.set(doubleClickBehavior.rawValue, forKey: Key.doubleClickBehavior)
        }
    }

    var expansionIndex: Int = 3 {
        didSet {
            guard expansionIndex != oldValue, shouldStoreToLocal else { return }
            UserDefaults.standard.set(expansionIndex, forKey: Key.expansionIndex)
        }
    }

    private let showOutlineRelay = BehaviorRelay<Bool>(value: true)
    var showOutlineObservable: Observable<Bool> {
        showOutlineRelay.asObservable()
    }

    var showOutline: Bool {
        get { showOutlineRelay.value }
        set { setShowOutline(newValue) }
    }

    private let showHiddenItemsRelay = BehaviorRelay<Bool>(value: false)
    var showHiddenItemsObservable: Observable<Bool> {
        showHiddenItemsRelay.asObservable()
    }

    var showHiddenItems: Bool {
        get { showHiddenItemsRelay.value }
        set { setShowHiddenItems(newValue) }
    }

    private let zInterspaceRelay = BehaviorRelay<Double>(value: 0.22)
    var zInterspaceObservable: Observable<Double> {
        zInterspaceRelay.asObservable()
    }

    var zInterspace: Double {
        get { zInterspaceRelay.value }
        set { setZInterspace(newValue) }
    }

    var enableReport = true {
        didSet { applyEnableReport() }
    }

    private let rgbaFormatRelay = BehaviorRelay<Bool>(value: true)
    var rgbaFormatObservable: Observable<Bool> {
        rgbaFormatRelay.asObservable()
    }

    var rgbaFormat: Bool {
        get { rgbaFormatRelay.value }
        set {
            let oldValue = rgbaFormatRelay.value
            guard newValue != oldValue else { return }
            rgbaFormatRelay.accept(newValue)
            guard shouldStoreToLocal else { return }
            UserDefaults.standard.set(newValue, forKey: Key.rgbaFormat)
        }
    }

    var imageContrastLevel: Int = 0 {
        didSet {
            guard imageContrastLevel != oldValue, shouldStoreToLocal else { return }
            UserDefaults.standard.set(imageContrastLevel, forKey: Key.contrastLevel)
        }
    }

    private let syncConsoleTargetRelay = BehaviorRelay<Bool>(value: true)
    var syncConsoleTargetObservable: Observable<Bool> {
        syncConsoleTargetRelay.asObservable()
    }

    var syncConsoleTarget: Bool {
        get { syncConsoleTargetRelay.value }
        set {
            let oldValue = syncConsoleTargetRelay.value
            guard newValue != oldValue else { return }
            syncConsoleTargetRelay.accept(newValue)
            guard shouldStoreToLocal else { return }
            UserDefaults.standard.set(newValue, forKey: Key.syncConsoleTarget)
        }
    }

    var collapsedAttrGroups: [String] = [LookinAttrGroup_Class] {
        didSet {
            guard shouldStoreToLocal else { return }
            UserDefaults.standard.set(collapsedAttrGroups, forKey: Key.collapsedGroups)
        }
    }

    private let preferredExportCompressionRelay = BehaviorRelay<CGFloat>(value: 0.5)
    var preferredExportCompressionObservable: Observable<CGFloat> {
        preferredExportCompressionRelay.asObservable()
    }

    var preferredExportCompression: CGFloat {
        get { preferredExportCompressionRelay.value }
        set {
            let oldValue = preferredExportCompressionRelay.value
            guard newValue != oldValue else { return }
            preferredExportCompressionRelay.accept(newValue)
            guard shouldStoreToLocal else { return }
            UserDefaults.standard.set(newValue, forKey: Key.preferredExportCompression)
        }
    }

    private let freeRotationRelay = BehaviorRelay<Bool>(value: true)
    var freeRotationObservable: Observable<Bool> {
        freeRotationRelay.asObservable()
    }

    var freeRotation: Bool {
        get { freeRotationRelay.value }
        set { setFreeRotation(newValue) }
    }

    private let fastModeRelay = BehaviorRelay<Bool>(value: false)
    var fastModeObservable: Observable<Bool> {
        fastModeRelay.asObservable()
    }

    var fastMode: Bool {
        get { fastModeRelay.value }
        set { setFastMode(newValue) }
    }

    var receivingConfigTime_Color: TimeInterval = 0 {
        didSet { UserDefaults.standard.set(receivingConfigTime_Color, forKey: Key.receivingConfigTimeColor) }
    }

    var receivingConfigTime_Class: TimeInterval = 0 {
        didSet { UserDefaults.standard.set(receivingConfigTime_Class, forKey: Key.receivingConfigTimeClass) }
    }

    var callStackType: LookinPreferredCallStackType = .default {
        didSet {
            if callStackType.rawValue < 0 || callStackType.rawValue > 2 {
                assertionFailure()
                callStackType = .default
            }
        }
    }

    private let previewDimensionRelay = BehaviorRelay<Int>(value: Int(LookinPreviewDimension.dimension3D.rawValue))
    var previewDimensionObservable: Observable<Int> {
        previewDimensionRelay.asObservable()
    }

    var previewDimension: Int {
        get { previewDimensionRelay.value }
        set { setPreviewDimension(newValue) }
    }

    private let previewScaleRelay = BehaviorRelay<Double>(value: Double(LKInitialPreviewScale))
    var previewScaleObservable: Observable<Double> {
        previewScaleRelay.asObservable()
    }

    var previewScale: Double {
        get { previewScaleRelay.value }
        set { setPreviewScale(newValue) }
    }

    private let measureStateRelay = BehaviorRelay<Int>(value: LookinMeasureState.no.rawValue)
    var measureStateObservable: Observable<LookinMeasureState> {
        measureStateRelay.asObservable().map { LookinMeasureState(rawValue: $0) ?? .no }
    }

    var measureState: LookinMeasureState {
        get { LookinMeasureState(rawValue: measureStateRelay.value) ?? .no }
        set { setMeasureState(newValue) }
    }

    private let isQuickSelectingRelay = BehaviorRelay<Bool>(value: false)
    var isQuickSelectingObservable: Observable<Bool> {
        isQuickSelectingRelay.asObservable()
    }

    var isQuickSelecting: Bool {
        get { isQuickSelectingRelay.value }
        set {
            guard newValue != isQuickSelectingRelay.value else { return }
            isQuickSelectingRelay.accept(newValue)
        }
    }

    private var storedSectionShowConfig: [String: NSNumber] = [:]

    override init() {
        super.init()

        let userDefaults = UserDefaults.standard

        let prevClientVersion = userDefaults.integer(forKey: Key.previousClientVersion)
        if prevClientVersion != LOOKIN_CLIENT_VERSION {
            userDefaults.set(LOOKIN_CLIENT_VERSION, forKey: Key.previousClientVersion)
        }

        if let obj = userDefaults.object(forKey: Key.showOutline) as? NSNumber {
            showOutlineRelay.accept(obj.boolValue)
        } else {
            showOutlineRelay.accept(true)
            userDefaults.set(true, forKey: Key.showOutline)
        }

        if let obj = userDefaults.object(forKey: Key.showHiddenItems) as? NSNumber {
            showHiddenItemsRelay.accept(obj.boolValue)
        } else {
            showHiddenItemsRelay.accept(false)
            userDefaults.set(false, forKey: Key.showHiddenItems)
        }

        if let obj = userDefaults.object(forKey: Key.enableReport) as? NSNumber {
            enableReport = obj.boolValue
        } else {
            enableReport = true
            userDefaults.set(enableReport, forKey: Key.enableReport)
        }

        if let obj = userDefaults.object(forKey: Key.doubleClickBehavior) as? NSNumber {
            doubleClickBehavior = LookinDoubleClickBehavior(rawValue: obj.intValue) ?? .collapse
        } else {
            doubleClickBehavior = .collapse
            userDefaults.set(doubleClickBehavior.rawValue, forKey: Key.doubleClickBehavior)
        }

        if let obj = userDefaults.object(forKey: Key.rgbaFormat) as? NSNumber {
            rgbaFormatRelay.accept(obj.boolValue)
        } else {
            rgbaFormatRelay.accept(true)
            userDefaults.set(true, forKey: Key.rgbaFormat)
        }

        let zInterspaceValue: Double
        if let obj = userDefaults.object(forKey: Key.zInterspace) as? NSNumber {
            zInterspaceValue = obj.doubleValue
        } else {
            zInterspaceValue = 0.22
            userDefaults.set(zInterspaceValue, forKey: Key.zInterspace)
        }
        zInterspaceRelay.accept(min(max(zInterspaceValue, LookinPreviewMinZInterspace), LookinPreviewMaxZInterspace))

        if let obj = userDefaults.object(forKey: Key.appearanceType) as? NSNumber {
            appearanceType = LookinPreferredAppeanranceType(rawValue: obj.intValue) ?? .system
        } else {
            appearanceType = .system
            userDefaults.set(appearanceType.rawValue, forKey: Key.appearanceType)
        }

        if let obj = userDefaults.object(forKey: Key.expansionIndex) as? NSNumber {
            expansionIndex = obj.intValue
        } else {
            expansionIndex = 3
            userDefaults.set(expansionIndex, forKey: Key.expansionIndex)
        }

        if let obj = userDefaults.object(forKey: Key.contrastLevel) as? NSNumber {
            imageContrastLevel = obj.intValue
        } else {
            imageContrastLevel = 0
            userDefaults.set(imageContrastLevel, forKey: Key.contrastLevel)
        }

        if let obj = userDefaults.object(forKey: Key.syncConsoleTarget) as? NSNumber {
            syncConsoleTargetRelay.accept(obj.boolValue)
        } else {
            syncConsoleTargetRelay.accept(true)
            userDefaults.set(true, forKey: Key.syncConsoleTarget)
        }

        if let obj = userDefaults.object(forKey: Key.freeRotation) as? NSNumber {
            freeRotationRelay.accept(obj.boolValue)
        } else {
            freeRotationRelay.accept(true)
            userDefaults.set(true, forKey: Key.freeRotation)
        }

        if let obj = userDefaults.object(forKey: Key.fastMode) as? NSNumber {
            fastModeRelay.accept(obj.boolValue)
        } else {
            fastModeRelay.accept(false)
            userDefaults.set(false, forKey: Key.fastMode)
        }

        if let stored = userDefaults.object(forKey: Key.sectionsShow) as? [String: NSNumber] {
            storedSectionShowConfig = stored
        }

        if let groups = userDefaults.object(forKey: Key.collapsedGroups) as? [String] {
            collapsedAttrGroups = groups
        }

        if let obj = userDefaults.object(forKey: Key.preferredExportCompression) as? NSNumber {
            preferredExportCompressionRelay.accept(CGFloat(obj.doubleValue))
        } else {
            preferredExportCompressionRelay.accept(0.5)
            userDefaults.set(0.5, forKey: Key.preferredExportCompression)
        }

        receivingConfigTime_Color = userDefaults.double(forKey: Key.receivingConfigTimeColor)
        receivingConfigTime_Class = userDefaults.double(forKey: Key.receivingConfigTimeClass)
    }

    private enum Key {
        static let previousClientVersion = "preVer"
        static let showOutline = "showOutline"
        static let showHiddenItems = "showHiddenItems"
        static let enableReport = "enableReport"
        static let rgbaFormat = "egbaFormat"
        static let zInterspace = "zInterspace_v095"
        static let appearanceType = "appearanceType"
        static let doubleClickBehavior = "doubleClickBehavior"
        static let expansionIndex = "expansionIndex"
        static let contrastLevel = "contrastLevel"
        static let sectionsShow = "ss"
        static let collapsedGroups = "collapsedGroups_918"
        static let preferredExportCompression = "preferredExportCompression"
        static let syncConsoleTarget = "syncConsoleTarget"
        static let freeRotation = "FreeRotation"
        static let fastMode = "fastMode"
        static let receivingConfigTimeColor = "ConfigTime_Color"
        static let receivingConfigTimeClass = "ConfigTime_Class"
    }

    private func setShowOutline(_ value: Bool) {
        guard value != showOutlineRelay.value else { return }
        showOutlineRelay.accept(value)
        guard shouldStoreToLocal else { return }
        UserDefaults.standard.set(value, forKey: Key.showOutline)
    }

    private func setShowHiddenItems(_ value: Bool) {
        guard value != showHiddenItemsRelay.value else { return }
        showHiddenItemsRelay.accept(value)
        guard shouldStoreToLocal else { return }
        UserDefaults.standard.set(value, forKey: Key.showHiddenItems)
    }

    private func setZInterspace(_ value: Double) {
        let clamped = min(max(value, LookinPreviewMinZInterspace), LookinPreviewMaxZInterspace)
        guard clamped != zInterspaceRelay.value else { return }
        zInterspaceRelay.accept(clamped)
        guard shouldStoreToLocal else { return }
        UserDefaults.standard.set(clamped, forKey: Key.zInterspace)
    }

    private func setFreeRotation(_ value: Bool) {
        guard value != freeRotationRelay.value else { return }
        freeRotationRelay.accept(value)
        guard shouldStoreToLocal else { return }
        UserDefaults.standard.set(value, forKey: Key.freeRotation)
    }

    private func setFastMode(_ value: Bool) {
        guard value != fastModeRelay.value else { return }
        fastModeRelay.accept(value)
        guard shouldStoreToLocal else { return }
        UserDefaults.standard.set(value, forKey: Key.fastMode)
    }

    private func setPreviewDimension(_ value: Int) {
        guard value != previewDimensionRelay.value else { return }
        previewDimensionRelay.accept(value)
    }

    private func setPreviewScale(_ value: Double) {
        let clamped = min(max(value, LookinPreviewMinScale), LookinPreviewMaxScale)
        guard clamped != previewScaleRelay.value else { return }
        previewScaleRelay.accept(clamped)
    }

    private func setMeasureState(_ value: LookinMeasureState) {
        guard value.rawValue != measureStateRelay.value else { return }
        measureStateRelay.accept(value.rawValue)
    }

    private func applyEnableReport() {
        guard shouldStoreToLocal else { return }
        UserDefaults.standard.set(enableReport, forKey: Key.enableReport)
        AppCenter.enabled = enableReport
    }

    func isSectionShowing(_ secID: String) -> Bool {
        if let value = storedSectionShowConfig[secID] {
            return value.boolValue
        }
        return showingSecIDsInDefault().contains(secID)
    }

    func showSection(_ secID: String) {
        guard !isSectionShowing(secID) else {
            assertionFailure()
            return
        }
        storedSectionShowConfig[secID] = NSNumber(value: true)
        NotificationCenter.default.post(name: NSNotification.Name(NotificationName_DidChangeSectionShowing), object: nil)
        UserDefaults.standard.set(storedSectionShowConfig, forKey: Key.sectionsShow)
    }

    func hideSection(_ secID: String) {
        guard isSectionShowing(secID) else {
            assertionFailure()
            return
        }
        storedSectionShowConfig[secID] = NSNumber(value: false)
        NotificationCenter.default.post(name: NSNotification.Name(NotificationName_DidChangeSectionShowing), object: nil)
        UserDefaults.standard.set(storedSectionShowConfig, forKey: Key.sectionsShow)
    }

    private func showingSecIDsInDefault() -> Set<String> {
        struct Cache {
            static let set: Set<String> = {
                let array: [String] = [
                    LookinAttrSec_Class_Class,
                    LookinAttrSec_Relation_Relation,
                    LookinAttrSec_Layout_Frame,
                    LookinAttrSec_Layout_Bounds,
                    LookinAttrSec_AutoLayout_Hugging,
                    LookinAttrSec_AutoLayout_Resistance,
                    LookinAttrSec_AutoLayout_Constraints,
                    LookinAttrSec_AutoLayout_IntrinsicSize,
                    LookinAttrSec_ViewLayer_Visibility,
                    LookinAttrSec_ViewLayer_InterationAndMasks,
                    LookinAttrSec_ViewLayer_Corner,
                    LookinAttrSec_ViewLayer_BgColor,
                    LookinAttrSec_ViewLayer_Border,
                    LookinAttrSec_ViewLayer_Shadow,
                    LookinAttrSec_UIStackView_Axis,
                    LookinAttrSec_UIStackView_Alignment,
                    LookinAttrSec_UIStackView_Distribution,
                    LookinAttrSec_UIStackView_Spacing,
                    LookinAttrSec_UIVisualEffectView_Style,
                    LookinAttrSec_UIVisualEffectView_QMUIForegroundColor,
                    LookinAttrSec_UIImageView_Name,
                    LookinAttrSec_UIImageView_Open,
                    LookinAttrSec_UILabel_Text,
                    LookinAttrSec_UILabel_Font,
                    LookinAttrSec_UILabel_NumberOfLines,
                    LookinAttrSec_UILabel_TextColor,
                    LookinAttrSec_UILabel_BreakMode,
                    LookinAttrSec_UILabel_Alignment,
                    LookinAttrSec_UIControl_EnabledSelected,
                    LookinAttrSec_UIControl_QMUIOutsideEdge,
                    LookinAttrSec_UIButton_ContentInsets,
                    LookinAttrSec_UIScrollView_ContentInset,
                    LookinAttrSec_UIScrollView_AdjustedInset,
                    LookinAttrSec_UIScrollView_IndicatorInset,
                    LookinAttrSec_UIScrollView_Offset,
                    LookinAttrSec_UIScrollView_ContentSize,
                    LookinAttrSec_UIScrollView_Behavior,
                    LookinAttrSec_UITableView_Style,
                    LookinAttrSec_UITableView_SectionsNumber,
                    LookinAttrSec_UITableView_RowsNumber,
                    LookinAttrSec_UITextView_Text,
                    LookinAttrSec_UITextView_Font,
                    LookinAttrSec_UITextView_TextColor,
                    LookinAttrSec_UITextView_Alignment,
                    LookinAttrSec_UITextView_ContainerInset,
                    LookinAttrSec_UITextField_Text,
                    LookinAttrSec_UITextField_Font,
                    LookinAttrSec_UITextField_TextColor,
                    LookinAttrSec_UITextField_Alignment,
                ]
                return Set(array)
            }()
        }
        return Cache.set
    }

    class func popupToAskDoubleClickBehaviorIfNeeded(with window: NSWindow?) -> Bool {
        guard let window else { return false }
        if LKTutorialManager.sharedInstance().hasAskedDoubleClickBehavior { return false }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("What do you want to happen when you double click the layer?", comment: "")
        alert.informativeText = NSLocalizedString("You can change it at any time in your Preferences.", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("Expand or collapse layer", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Focus on layer", comment: ""))
        alert.beginSheetModal(for: window) { returnCode in
            if returnCode == .alertFirstButtonReturn {
                mainManager().doubleClickBehavior = .collapse
            } else {
                mainManager().doubleClickBehavior = .focus
            }
        }
        LKTutorialManager.sharedInstance().hasAskedDoubleClickBehavior = true
        return true
    }

    func reset() {
        LKTutorialManager.sharedInstance().hasAskedDoubleClickBehavior = false
    }

    func reportStatistics() {
        Analytics.trackEvent(
            "Preference",
            withProperties: [
                "DoubleClick": "\(doubleClickBehavior.rawValue)",
                "ShowHidden": "\(showHiddenItems)",
                "RGBA": "\(rgbaFormat)",
                "FreeRotation": "\(freeRotation)",
                "FastMode": "\(fastMode)",
            ]
        )
    }
}
