import AppKit
import LookinShared
import RxSwift

final class LKDashboardAttributeNumberInputView: LKDashboardAttributeView, NSTextFieldDelegate {
    private(set) var inputView: LKNumberInputView!
    private var modifyDisposable: Disposable?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        inputView = LKNumberInputView()
        inputView.textFieldView.textField.delegate = self
        addSubview(inputView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        lk(inputView).fullFrame()
    }

    override func sizeThatFits(_ limitedSize: NSSize) -> NSSize {
        var size = limitedSize
        switch inputView.viewStyle {
        case .horizontal: size.height = LKNumberInputHorizontalHeight
        case .vertical: size.height = LKNumberInputVerticalHeight
        @unknown default: assertionFailure()
        }
        return size
    }

    override func renderWithAttribute() {
        guard let attribute else { return }
        inputView.textFieldView.textField.isEditable = canEdit()
        if attribute.isUserCustom() {
            inputView.inputTitle = nil
        } else {
            inputView.inputTitle = LookinDashboardBlueprint.briefTitle(withAttrID: attribute.identifier ?? "")
        }
        let doubleValue = attribute.value.dashboardDoubleValue
        if attribute.isUserCustom() {
            inputView.viewStyle = .horizontal
            inputView.textFieldView.textField.stringValue = NSString.lookin_string(from: doubleValue, decimal: 6)
        } else {
            let horizontalAttrs: Set<LookinAttrIdentifier> = [
                LookinAttr_ViewLayer_Visibility_Opacity, LookinAttr_ViewLayer_Corner_Radius, LookinAttr_ViewLayer_Tag_Tag,
                LookinAttr_UILabel_Font_Size, LookinAttr_UILabel_NumberOfLines_NumberOfLines, LookinAttr_UITextView_Font_Size,
                LookinAttr_UITextField_Font_Size, LookinAttr_UITextField_CanAdjustFont_MinSize, LookinAttr_ViewLayer_Border_Width,
                LookinAttr_UITableView_SectionsNumber_Number, LookinAttr_AutoLayout_Resistance_Ver, LookinAttr_AutoLayout_Resistance_Hor,
                LookinAttr_AutoLayout_Hugging_Ver, LookinAttr_AutoLayout_Hugging_Hor, LookinAttr_UIStackView_Spacing_Spacing,
            ]
            if horizontalAttrs.contains(attribute.identifier ?? "") {
                inputView.viewStyle = .horizontal
                inputView.textFieldView.textField.stringValue = NSString.lookin_string(from: doubleValue, decimal: 3)
            } else {
                inputView.viewStyle = .vertical
                inputView.textFieldView.textField.stringValue = NSString.lookin_string(from: doubleValue, decimal: 2)
            }
        }
    }

    override func numberOfColumnsOccupied() -> UInt {
        guard let attribute, !attribute.isUserCustom() else { return 1 }
        let dict: [LookinAttrIdentifier: UInt] = [
            LookinAttr_ViewLayer_Visibility_Opacity: 1, LookinAttr_ViewLayer_Corner_Radius: 1, LookinAttr_ViewLayer_Tag_Tag: 1,
            LookinAttr_UITextView_Font_Size: 1, LookinAttr_UITextField_Font_Size: 1, LookinAttr_UITextField_CanAdjustFont_MinSize: 1,
            LookinAttr_ViewLayer_Border_Width: 1, LookinAttr_UITableView_SectionsNumber_Number: 1, LookinAttr_UILabel_NumberOfLines_NumberOfLines: 1,
            LookinAttr_UILabel_Font_Size: 1, LookinAttr_UIStackView_Spacing_Spacing: 1,
            LookinAttr_AutoLayout_Resistance_Ver: 2, LookinAttr_AutoLayout_Resistance_Hor: 2, LookinAttr_AutoLayout_Hugging_Ver: 2, LookinAttr_AutoLayout_Hugging_Hor: 2,
            LookinAttr_UIScrollView_Zoom_Scale: 3, LookinAttr_UIScrollView_Zoom_MinScale: 3, LookinAttr_UIScrollView_Zoom_MaxScale: 3,
        ]
        return dict[attribute.identifier ?? ""] ?? 4
    }

    override var dashboardViewController: LKDashboardViewController? {
        didSet { inputView.textFieldView.backgroundColorName = "DashboardCardValueBGColor" }
    }

    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool { canEdit() }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let attribute else { return }
        if LKDashboardTextControlEditingFlag.sharedInstance.shouldIgnoreTextEditingChangeEvent { return }
        guard let parsed = LKNumberInputView.parsedValue(with: inputView.textFieldView.textField.stringValue, attrType: attribute.attrType) as? NSNumber else {
            renderWithAttribute()
            return
        }
        var doubleValue = parsed.doubleValue
        if attribute.identifier == LookinAttr_ViewLayer_Visibility_Opacity || attribute.identifier == LookinAttr_ViewLayer_Shadow_Opacity {
            doubleValue = max(min(doubleValue, 1), 0)
        }
        let expectedValue = AttributeValue.from(double: doubleValue, attrType: attribute.attrType)
        if expectedValue == attribute.value { renderWithAttribute(); return }
        modifyDisposable = subscribeAttributeModification(newValue: expectedValue, onSuccess: { [weak self] in self?.renderWithAttribute() })
    }
}
