//
//  LKInputSearchView.swift
//  Lookin
//
//  Created by Li Kai on 2019/6/2.
//  https://lookin.work
//

import AppKit
import RxSwift

protocol LKInputSearchViewDelegate: AnyObject {
    func inputSearchView(_ view: LKInputSearchView, suggestionsForString string: String) -> [LKInputSearchSuggestionItem]
    func inputSearchView(_ view: LKInputSearchView, submitText text: String)
}

class LKInputSearchView: LKBaseView, NSTextFieldDelegate {
    weak var delegate: LKInputSearchViewDelegate?

    var horizontalInset: CGFloat = 0

    var textField: NSTextField {
        textFieldView.textField
    }

    private var textFieldView: LKTextFieldView!
    private var suggestionWc: LKInputSearchSuggestionWindowController!
    private var previousInput: String?

    private let disposeBag = DisposeBag()

    init(throttleTime: CGFloat) {
        super.init(frame: .zero)

        textFieldView = LKTextFieldView()
        textFieldView.textField.delegate = self
        textFieldView.insets = .zero
        textFieldView.textField.isEditable = true
        textFieldView.textField.isBordered = false
        textFieldView.textField.isBezeled = false
        textFieldView.textField.usesSingleLineMode = true
        textFieldView.textField.backgroundColor = .clear
        textFieldView.textField.lineBreakMode = .byTruncatingTail
        textFieldView.textField.font = NSFontMake(13)
        addSubview(textFieldView)

        suggestionWc = LKInputSearchSuggestionWindowController()
        suggestionWc.suggestionsView.tableView.target = self
        suggestionWc.suggestionsView.tableView.action = #selector(handleClickTableView)

        textFieldView.textField.lk_textOrEmpty
            .debounce(.milliseconds(Int(throttleTime * 1000)), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] value in
                guard let self else { return }
                let items = self.delegate?.inputSearchView(self, suggestionsForString: value) ?? []
                self.suggestionWc.suggestionsView.items = items
                if !items.isEmpty, self.textField.stringValue == value {
                    self.window?.addChildWindow(self.suggestionWc.window!, ordered: .above)
                    self.needsLayout = true
                } else {
                    self.suggestionWc.close()
                }
            })
            .disposed(by: disposeBag)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        lk(textFieldView).x(horizontalInset).toRight(horizontalInset).fullHeight()

        guard let superview, let window else { return }
        let selfOrigin = window.contentView?.convert(frame.origin, from: superview) ?? .zero
        let mainWindowFrame = window.frame
        let panelSize = suggestionWc.suggestionsView.bestSize()
        let panelHeight = panelSize.height
        let panelWidth = min(panelSize.width, 500)

        var y = mainWindowFrame.origin.y + (window.contentView?.frame.height ?? 0) - selfOrigin.y - panelHeight - frame.height
        if y < 200 {
            y += panelHeight + frame.height
        }
        suggestionWc.window?.setFrame(
            NSRect(x: mainWindowFrame.origin.x + selfOrigin.x, y: y, width: panelWidth, height: panelHeight),
            display: true
        )
    }

    func clearContentAndSuggestions() {
        if !textField.stringValue.isEmpty {
            previousInput = textField.stringValue
        }
        textField.stringValue = ""
        suggestionWc.close()
    }

    func refreshSuggestionsIfNeeded() {
        let value = textField.stringValue
        guard !value.isEmpty else { return }
        let items = delegate?.inputSearchView(self, suggestionsForString: value) ?? []
        suggestionWc.suggestionsView.items = items
        if !items.isEmpty {
            window?.addChildWindow(suggestionWc.window!, ordered: .above)
            needsLayout = true
        } else {
            suggestionWc.close()
        }
    }

    @objc private func handleClickTableView() {
        if let text = suggestionWc.suggestionsView.currentSelectedItem()?.text {
            textField.stringValue = text
            suggestionWc.close()
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            if suggestionWc.window?.isVisible != true || suggestionWc.suggestionsView.currentSelectedItem() == nil {
                if let previousInput {
                    textField.stringValue = previousInput
                    return true
                }
            }
        }

        if commandSelector == #selector(NSResponder.moveDown(_:)) || commandSelector == #selector(NSResponder.moveUp(_:)) {
            if suggestionWc.window?.isVisible == true, let event = NSApp.currentEvent {
                suggestionWc.suggestionsView.tableView.keyDown(with: event)
                return true
            }
        }

        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if suggestionWc.window?.isVisible == true,
               let text = suggestionWc.suggestionsView.currentSelectedItem()?.text {
                textField.stringValue = text
                suggestionWc.close()
                return true
            }

            let input = textField.stringValue.trimmingCharacters(in: .whitespaces)
            if !input.isEmpty {
                delegate?.inputSearchView(self, submitText: input)
                return true
            }
            return true
        }
        return false
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        suggestionWc.close()
        return true
    }
}
