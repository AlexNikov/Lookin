//
//  LookinClientSwiftCompat.swift
//  Lookin
//

import AppKit
import LookinShared
import RxSwift

// MARK: - Types migrated from stub headers

enum LKViewBorderPosition: Int {
    case none
    case top
    case left
    case bottom
    case right
}

enum LKUserActionType: Int {
    case none
    case previewOperation
    case dashboardClick
    case selectedItemChange
}

protocol LKUserActionManagerDelegate: AnyObject {
    func lkUserActionManager(_ manager: LKUserActionManager, didAct type: LKUserActionType)
}

enum LKNumberInputViewStyle: UInt {
    case horizontal
    case vertical
}

func LookinCastDisplayItemDetails(_ value: Any) -> [LookinDisplayItemDetail] {
    if let detail = value as? LookinDisplayItemDetail {
        return [detail]
    }
    if let details = value as? [LookinDisplayItemDetail] {
        return details
    }
    if let array = value as? [Any] {
        return array.compactMap { $0 as? LookinDisplayItemDetail }
    }
    if let nsArray = value as? NSArray {
        return nsArray.compactMap { $0 as? LookinDisplayItemDetail }
    }
    return []
}

func LookinCastConnectionResponseAttachment(_ value: Any?) -> LookinConnectionResponseAttachment? {
    value as? LookinConnectionResponseAttachment
}

func NSImageMake(_ imageName: String) -> NSImage? {
    NSImage(named: imageName)
}

func NSFontMake(_ fontSize: CGFloat) -> NSFont {
    NSFont.systemFont(ofSize: fontSize)
}

func LookinColorMake(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(calibratedRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: 1)
}

func LookinColorRGBAMake(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> NSColor {
    NSColor(calibratedRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
}

var CurrentKeyWindow: NSWindow? { NSApp.keyWindow }

var CurrentTime: TimeInterval { Date().timeIntervalSince1970 }

let NSSizeMax = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

var IsEnglish: Bool { LKHelper.isEnglish() }

var TutorialMng: LKTutorialManager { LKTutorialManager.sharedInstance() }

func LookinErrorMake(_ errorTitle: String, _ errorDetail: String) -> NSError {
    NSError(
        domain: LookinErrorDomain,
        code: Int(LookinErrCode_Default),
        userInfo: [
            NSLocalizedDescriptionKey: errorTitle,
            NSLocalizedRecoverySuggestionErrorKey: errorDetail,
        ]
    )
}

func LKColorsCombine(_ colorA: NSColor, _ b: NSColor) -> LKTwoColors {
    let colors = LKTwoColors()
    colors.colorInLightMode = colorA
    colors.colorInDarkMode = b
    return colors
}

var InspectingApp: LKInspectableApp? { LKAppsManager.sharedInstance.inspectingApp }


extension Array {
    func lookin_hasIndex(_ index: Int) -> Bool {
        guard index != NSNotFound, index >= 0 else { return false }
        return count > index
    }

    func lookin_firstFiltered(_ block: (Element) -> Bool) -> Element? {
        first(where: block)
    }
}


let NSColorGray1 = LookinColorMake(53, 60, 70)
let NSColorGray9 = LookinColorMake(216, 220, 228)

let SeparatorLightModeColor = LookinColorMake(215, 215, 215)
let SeparatorDarkModeColor = LookinColorMake(67, 67, 69)

// MARK: - Layout constants (formerly LKHelper.h)

let HierarchyMinWidth: CGFloat = 200
let MeasureViewWidth: CGFloat = 240
let DashboardViewWidth: CGFloat = 260
let DashboardAttrItemHorInterspace: CGFloat = 10
let DashboardAttrItemVerInterspace: CGFloat = 9
let DashboardHorInset: CGFloat = 10
let DashboardCardControlCornerRadius: CGFloat = 4
let DashboardSectionMarginTop: CGFloat = 10
let DashboardCardCornerRadius: CGFloat = 6
let DashboardSearchCardInset: CGFloat = 6
let ConsoleInsetLeft: CGFloat = 10
let ConsoleInsetRight: CGFloat = 26
let ZoomSliderMaxValue: CGFloat = 2.8

struct HorizontalMargins {
    var left: CGFloat
    var right: CGFloat
}

func HorizontalMarginsMake(_ left: CGFloat, _ right: CGFloat) -> HorizontalMargins {
    HorizontalMargins(left: left, right: right)
}

// MARK: - Alerts (ObjC macros)

func AlertError(_ error: NSError, _ window: NSWindow?) {
    guard error.code != Int(LookinErrCode_Discard) else { return }
    LKLogsManager.shared.logError(error)
    NotificationCenter.default.post(
        name: .LKShowErrorNotification,
        object: nil,
        userInfo: [LKShowErrorNotificationTitleKey: error.localizedDescription]
    )
}

func AlertErrorText(_ title: String, _ detail: String, _ window: NSWindow?) {
    AlertError(LookinErrorMake(title, detail), window)
}

func LookinAnyDoubleValue(_ value: Any) -> Double {
    if let params = value as? LookinMsgActionParams { return params.doubleValue }
    if let n = value as? NSNumber { return n.doubleValue }
    if let n = value as? Double { return n }
    if let s = value as? String { return Double(s) ?? 0 }
    return 0
}

// MARK: - Array resize (Swift ports of NSArray+Lookin)

private func lookinResizeElements<T>(
    _ elements: [T],
    count: Int,
    add: (UInt) -> T,
    remove: ((UInt, T) -> Void)? = nil,
    doNext: ((UInt, T) -> Void)? = nil
) -> [T] {
    var result = elements
    while result.count < count {
        let idx = UInt(result.count)
        result.append(add(idx))
    }
    while result.count > count {
        let idx = UInt(result.count - 1)
        let obj = result.removeLast()
        remove?(idx, obj)
    }
    for (idx, obj) in result.enumerated() {
        doNext?(UInt(idx), obj)
    }
    return result
}


extension Array {
    func lookin_resize(
        withCount count: Int,
        add: @escaping (UInt) -> Element,
        remove: ((UInt, Element) -> Void)? = nil,
        doNext: ((UInt, Element) -> Void)? = nil
    ) -> [Element] {
        lookinResizeElements(self, count: count, add: add, remove: remove, doNext: doNext)
    }

    func lookin_resize(
        count: Int,
        add: @escaping (UInt) -> Element,
        remove: ((UInt, Element) -> Void)? = nil,
        doNext: ((UInt, Element) -> Void)? = nil
    ) -> [Element] {
        lookinResizeElements(self, count: count, add: add, remove: remove, doNext: doNext)
    }
}


extension NSMutableArray {
    func lookin_resize<T>(
        withCount count: Int,
        add: @escaping (UInt) -> T,
        remove: ((UInt, T) -> Void)? = nil,
        doNext: ((UInt, T) -> Void)? = nil
    ) {
        let typed = compactMap { $0 as? T }
        let result = lookinResizeElements(typed, count: count, add: add, remove: remove, doNext: doNext)
        removeAllObjects()
        addObjects(from: result)
    }
}

extension Int {
    func lookin_resize<T>(
        count: Int,
        add: @escaping (UInt) -> T,
        remove: ((UInt, T) -> Void)? = nil,
        doNext: ((UInt, T) -> Void)? = nil
    ) -> [T] {
        lookinResizeElements([T](), count: count, add: add, remove: remove, doNext: doNext)
    }
}

// MARK: - RAC bridging

extension Array where Element: Equatable {
    func lookin_arrayByRemovingObject(_ obj: Element) -> [Element] {
        filter { $0 != obj }
    }
}

// MARK: - NSEdgeInsets

extension NSEdgeInsets {
    static var zero: NSEdgeInsets { NSEdgeInsetsZero }
}

// MARK: - NSMutableArray dequeue (ObjC API)

extension NSMutableArray {
    func lookin_dequeue(
        withCount count: UInt,
        add: @escaping (UInt) -> Any,
        notDequeued: ((UInt, Any) -> Void)? = nil,
        doNext: ((UInt, Any) -> Void)? = nil
    ) {
        while UInt(self.count) < count {
            let idx = UInt(self.count)
            self.add(add(idx))
        }
        if UInt(self.count) > count {
            let extraRange = Int(count) ..< self.count
            for idx in extraRange {
                notDequeued?(UInt(idx), self[idx])
            }
            self.removeObjects(at: IndexSet(extraRange))
        }
        for idx in 0 ..< Int(count) {
            doNext?(UInt(idx), self[idx])
        }
    }

    func lookin_dequeue(
        withCount count: Int,
        add: @escaping (UInt) -> Any,
        notDequeued: ((UInt, Any) -> Void)? = nil,
        doNext: ((UInt, Any) -> Void)? = nil
    ) {
        lookin_dequeue(
            withCount: UInt(count),
            add: add,
            notDequeued: notDequeued,
            doNext: doNext
        )
    }
}

extension Int {
    func lookin_dequeue<T>(
        count: Int,
        add: @escaping (UInt) -> T,
        remove: ((UInt, T) -> Void)? = nil,
        doNext: ((UInt, T) -> Void)? = nil
    ) -> [T] {
        lookin_resize(count: count, add: add, remove: remove, doNext: doNext)
    }
}


extension NSView {
    var lookin_isEffectivelyVisible: Bool {
        !isHidden && alphaValue >= 0.01
    }
}

extension LKBaseView {
    var lk_clientIsVisible: Bool {
        superview != nil && !isHidden && alphaValue >= 0.01
    }
}

extension NSImage {
    static func lookinNamed(_ name: String) -> NSImage {
        NSImage(named: name) ?? NSImage(size: NSSize(width: 1, height: 1))
    }
}

// Re-export for client targets that don't see LookinServerShared module constants in all files.
func LKPreferenceMain() -> LKPreferenceManager {
    LKPreferenceManager.mainManager()
}

func LookinClientIsDarkMode() -> Bool {
    NSApp.effectiveAppearance.lk_isDarkMode
}

let lookinNodeImageMaxLengthInPx: Double = 16384


