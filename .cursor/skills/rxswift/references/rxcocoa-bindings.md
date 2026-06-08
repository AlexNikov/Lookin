# RxCocoa Bindings

`RxCocoa` is the iOS/macOS bridge: reactive extensions on UIKit/AppKit (`textField.rx.text`, `button.rx.tap`, …), the `Driver`/`Signal` Traits (see `traits.md`), Foundation reactive extensions (`NotificationCenter.rx`, `URLSession.rx`, KVO), and the `Binder`/`ControlProperty`/`ControlEvent` plumbing.

> Read this when: binding a stream to UIKit, choosing between `bind`/`drive`/`emit`, hooking up a table view, building a custom `Binder`, or reaching for `NotificationCenter`/`URLSession`/KVO via Rx.

## The four binding verbs

| Verb | Source type | Disposes returned? |
|---|---|---|
| `bind(to:)` | Any `ObservableType` | Yes (returns `Disposable`) |
| `bind(onNext:)` | `ObservableType` | Yes; closure form |
| `drive(_:)` / `drive(onNext:)` | `Driver<T>` | Yes |
| `emit(to:)` / `emit(onNext:)` | `Signal<T>` | Yes |

All four are sugar for `subscribe(_:)` with intent-revealing names. Use the one that matches the source Trait.

```swift
viewModel.title.bind(to: titleLabel.rx.text).disposed(by: bag)         // Observable
viewModel.title.drive(titleLabel.rx.text).disposed(by: bag)            // Driver
viewModel.didLogin.emit(to: loginRelay).disposed(by: bag)              // Signal
button.rx.tap.bind(onNext: { print("tap") }).disposed(by: bag)
```

`bind(onNext:)` traps in debug if the source emits an error and silently swallows in release — it's intended for sources that are known not to error. For fallible sources, use full `subscribe(_:)` with `onError`.

### Weak-self friendly variants (RxSwift 6+)

```swift
viewModel.greeting
    .drive(with: self) { owner, greeting in
        owner.label.text = greeting
    }
    .disposed(by: bag)

button.rx.tap
    .bind(with: self) { owner, _ in
        owner.handleTap()
    }
    .disposed(by: bag)
```

`bind(with:onNext:)`, `drive(with:onNext:)`, `emit(with:onNext:)`, `subscribe(with:onNext:)` — all weakly capture the first argument. Strongly preferred for VC/View bindings; see `disposal-and-memory.md`.

## `ControlProperty` vs `ControlEvent`

These are RxCocoa's two specialized Traits for UIKit controls.

### `ControlProperty<T>`

Two-way binding for a control's **value** (text, isOn, isSelected, …). Behaves like a `BehaviorRelay`:

- New subscribers immediately receive the **current value**.
- Sequence completes when the control deallocates.
- Never errors.
- Always on `MainScheduler`.
- **Does not emit on programmatic changes** (only user-initiated ones), depending on the control.

```swift
let textProperty: ControlProperty<String?> = textField.rx.text
textProperty.orEmpty                                    // ControlProperty<String>
    .bind(to: viewModel.queryRelay)
    .disposed(by: bag)

viewModel.queryRelay
    .bind(to: textField.rx.text)
    .disposed(by: bag)
```

Two-way: `textField.rx.text` works as both source and sink.

### `ControlEvent<T>`

For control **events** (taps, valueChanged, editingDidEnd). Behaves like a `PublishRelay`:

- New subscribers do **not** receive past events.
- Completes on dealloc, never errors, always main-thread.

```swift
button.rx.tap                            // ControlEvent<Void>
    .bind(with: self) { owner, _ in owner.submit() }
    .disposed(by: bag)

textField.rx.controlEvent(.editingDidEnd)
    .bind(…)
```

If you need an event with the latest value attached, combine with `withLatestFrom`:

```swift
button.rx.tap
    .withLatestFrom(textField.rx.text.orEmpty)
    .bind(to: viewModel.submitRelay)
    .disposed(by: bag)
```

## Common control extensions

```swift
// UILabel
label.rx.text                                         // <- write
label.rx.attributedText

// UITextField / UITextView
textField.rx.text          // ControlProperty<String?>  <- read+write
textField.rx.text.orEmpty  // ControlProperty<String>
textView.rx.text           // ControlProperty<String?>

// UIButton
button.rx.tap              // ControlEvent<Void>
button.rx.title()          // Binder<String?> for normal state
button.rx.isEnabled        // Binder<Bool>

// UISwitch / UIStepper
switchControl.rx.isOn      // ControlProperty<Bool>
stepper.rx.value           // ControlProperty<Double>

// UISegmentedControl
segmented.rx.selectedSegmentIndex       // ControlProperty<Int>

// UIControl (general)
control.rx.controlEvent(.valueChanged)
control.rx.controlProperty(editingEvents:getter:setter:)

// UIView
view.rx.isHidden           // Binder<Bool>
view.rx.alpha              // Binder<CGFloat>
```

Many more in `RxCocoa/iOS/`. When in doubt, search the file structure for `UIThing+Rx.swift`.

## Tables and collections

The base RxCocoa support is `rx.items(...)`. **Anything beyond a flat single-section list — sections, animated diffs, supplementary views — typically uses `RxDataSources`, which is out of scope for this skill.**

```swift
viewModel.items                             // Driver<[Item]>
    .drive(tableView.rx.items(cellIdentifier: "Cell",
                              cellType: ItemCell.self)) { _, item, cell in
        cell.configure(with: item)
    }
    .disposed(by: bag)

tableView.rx.modelSelected(Item.self)
    .bind(to: viewModel.selectedItemRelay)
    .disposed(by: bag)

tableView.rx.itemDeleted
    .bind(to: viewModel.deletedRelay)
    .disposed(by: bag)
```

## Custom `Binder`

When binding to a property that doesn't have a built-in extension, write a `Binder`:

```swift
extension Reactive where Base: UIView {
    var borderColor: Binder<UIColor?> {
        Binder(base) { view, color in
            view.layer.borderColor = color?.cgColor
        }
    }
}

// Usage
viewModel.errorColor
    .drive(view.rx.borderColor)
    .disposed(by: bag)
```

`Binder` enforces:

- Closure runs on the **specified scheduler** (defaults to `MainScheduler`).
- Source errors are trapped (binders accept `Observable`, `Driver`, `Signal`, all of which it treats as fire-on-next).

## Foundation reactive extensions

### `NotificationCenter.rx`

```swift
NotificationCenter.default.rx
    .notification(UIResponder.keyboardWillShowNotification)
    .map { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
    .compactMap { $0 }
    .bind(with: self) { owner, frame in owner.adjustForKeyboard(frame) }
    .disposed(by: bag)
```

### `URLSession.rx`

```swift
URLSession.shared.rx
    .data(request: URLRequest(url: url))
    .map { try JSONDecoder().decode(User.self, from: $0) }
    .observe(on: MainScheduler.instance)
    .bind(to: viewModel.userRelay)
    .disposed(by: bag)

// Other variants
URLSession.shared.rx.response(request:)             // (HTTPURLResponse, Data)
URLSession.shared.rx.json(request:)                 // Any (parsed JSON)
URLSession.shared.rx.string(request:)               // String
```

These are convenience wrappers; for production networking you usually wrap your own client into a `Single` per call (see `traits.md`).

### KVO

`NSObject.rx.observe(_:_:)` and `rx.observeWeakly(_:_:)` provide reactive Key-Value Observing. Useful for legacy ObjC frameworks; rare in pure-Swift code.

```swift
view.rx.observe(CGRect.self, "frame")
    .bind(to: viewModel.frameRelay)
    .disposed(by: bag)
```

### Lifecycle

```swift
viewController.rx.viewDidAppear
    .bind(with: self) { owner, _ in owner.refresh() }
    .disposed(by: bag)

NSObject.rx.deallocated                  // Observable<Void>, fires once
```

`rx.deallocated` is useful with `take(until:)` for "subscribe until this object dies" patterns — see `disposal-and-memory.md`.

## Worked example: simple UI binding (from `Documentation/Examples.md`)

Bind a search field to an async lookup, display the result in a label.

```swift
final class CityViewController: UIViewController {
    @IBOutlet private var cityField: UITextField!
    @IBOutlet private var temperatureLabel: UILabel!
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        cityField.rx.text.orEmpty
            .filter { $0.count >= 3 }
            .debounce(.milliseconds(300), scheduler: MainScheduler.instance)
            .flatMapLatest { city in
                weatherAPI.temperature(in: city)
                    .catchAndReturn("--")
            }
            .bind(to: temperatureLabel.rx.text)
            .disposed(by: disposeBag)
    }
}
```

`flatMapLatest` here cancels the previous lookup as the user keeps typing — see `operators.md`.

## Capstone: automatic input validation (from `Documentation/Examples.md`)

A real-world pattern combining synchronous validation, async server checks, loading state, and disposal. Cross-referenced from `error-handling.md` and `architecture.md` (MVVM I/O example).

```swift
// Inputs:  username text
// Outputs: validation result for the label, isLoading for the spinner,
//          isEnabled for the submit button.

let username = usernameField.rx.text.orEmpty.share(replay: 1, scope: .whileConnected)

let usernameValidation: Driver<ValidationResult> = username
    .flatMapLatest { name -> Observable<ValidationResult> in
        guard !name.isEmpty else { return .just(.empty) }
        guard name.count >= 3 else { return .just(.failed("Too short")) }
        return api.usernameAvailable(name)
            .map { $0 ? .ok("Username available") : .failed("Username taken") }
            .startWith(.validating)
            .catchAndReturn(.failed("Network error"))
    }
    .asDriver(onErrorJustReturn: .failed("Unexpected"))

usernameValidation
    .drive(usernameValidationLabel.rx.validationResult)   // a custom Binder
    .disposed(by: bag)

usernameValidation
    .map { $0.isValid }
    .drive(submitButton.rx.isEnabled)
    .disposed(by: bag)

usernameValidation
    .map { $0.isValidating }
    .drive(activityIndicator.rx.isAnimating)
    .disposed(by: bag)
```

Why this pattern works:

- `flatMapLatest` cancels stale username checks as the user keeps typing.
- `startWith(.validating)` immediately surfaces the loading state.
- `catchAndReturn` converts a thrown error into a UI-friendly `ValidationResult` — the stream stays alive.
- `asDriver` guarantees main-thread delivery and replay so a re-bind shows the latest state.
- `share(replay: 1, scope: .whileConnected)` prevents the `username` source from being subscribed twice (once per output).

This skeleton scales: add the same `flatMapLatest`-validation slice for password, email, phone — combine with `Observable.combineLatest` to derive an overall `isFormValid` Driver for the submit button.

## Anti-patterns (cross-reference)

- `subscribe(onNext:)` directly on a UIKit control instead of `bind`/`drive`/`emit` → `anti-patterns.md`
- Manual `DispatchQueue.main.async` inside a `subscribe` — use `observe(on: MainScheduler.instance)` or convert to `Driver` → `anti-patterns.md`
- Side effects inside `do(onNext:)` on a Driver — drivers are shared, side effects fire per subscriber → `anti-patterns.md`
- Capturing `self` strongly in a `bind` closure → `disposal-and-memory.md`

## Cross-references

- `Driver` / `Signal` semantics → `traits.md`
- Threading guarantees → `schedulers.md`
- Subjects/Relays as the writable backing store for ViewModel outputs → `subjects-and-relays.md`
- Full Input/Output ViewModel example → `architecture.md`
