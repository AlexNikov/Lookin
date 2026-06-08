# Disposal and Memory

`subscribe(_:)` returns a `Disposable`. If nothing holds it, **the subscription dies immediately** (or worse, lingers via the strong reference graph). Every Rx memory bug eventually reduces to one of: missing `disposed(by:)`, retain cycle through a closure capture, or a `DisposeBag` whose lifetime is wrong (often a cell).

> Read this when: leak suspected, `Main Thread Checker` fires from a long-dead VC, cells crash after scrolling, the subscription "never fires", or you see nested `subscribe`.

## The mental model

```
View Controller ──owns──► DisposeBag
                              │
                              └─owns──► Disposable₁
                                        Disposable₂
                                        …
```

When the VC deinits, the `DisposeBag` deinits, which calls `dispose()` on every contained `Disposable`. That cleanup, in turn, runs the `Disposables.create { … }` closure inside each `Observable.create` (cancelling the network task, removing the observer, etc.). **Disposal is not garbage collection — it's deterministic teardown.**

## The DisposeBag

```swift
final class MyViewController: UIViewController {
    private let disposeBag = DisposeBag()        // ← top-level let

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.title
            .bind(to: titleLabel.rx.text)
            .disposed(by: disposeBag)            // ← attach
    }
}
```

**Rules:**

1. **One bag per owner**, declared as `let` at top level (VC, View, Cell). Never `var disposeBag = DisposeBag()` reassigned later — assigning a new bag releases the old, which silently disposes its contents.
2. **`disposed(by:)` on every `subscribe`/`bind`/`drive`/`emit`** that should outlive the call. The only exception is when you intentionally keep a `Disposable` to dispose later (rare).
3. **Don't share bags across owners.** A child cell putting its bag into its parent VC's bag couples lifetimes incorrectly.

## Cell reuse (`UITableViewCell` / `UICollectionViewCell`)

A cell can be configured many times across its lifetime. If you keep adding subscriptions to a single bag, you accumulate dead bindings.

```swift
final class ChatCell: UITableViewCell {
    var disposeBag = DisposeBag()                // ← var, replaced on reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()                // ← old bag disposes its contents
    }

    func configure(with message: Message) {
        message.text
            .bind(to: bodyLabel.rx.text)
            .disposed(by: disposeBag)
    }
}
```

This is the **only** common case where `disposeBag` is `var`. The replacement-in-`prepareForReuse` pattern is load-bearing — without it, scrolling builds up duplicate bindings until the cell receives multiple text updates per source event.

## Capturing `self` correctly

A `subscribe` closure that captures `self` strongly creates a **retain cycle**:

```
self → disposeBag → Disposable → closure → self
```

The bag's deinit never runs because `self` is retained, so the bag never disposes. Two ways to break the cycle:

### `[weak self]`

```swift
// ✅ Idiomatic, safe
viewModel.greeting
    .subscribe(onNext: { [weak self] greeting in
        guard let self else { return }
        self.label.text = greeting
    })
    .disposed(by: disposeBag)
```

`[weak self]` is the default. Use it unless you have a hard correctness reason for `unowned`.

### `subscribe(with:)` / `bind(with:)` (RxSwift 6+)

```swift
// ✅ Cleaner — `owner` is the weakly-captured self
viewModel.greeting
    .subscribe(with: self) { owner, greeting in
        owner.label.text = greeting
    }
    .disposed(by: disposeBag)
```

`subscribe(with:)`, `bind(with:onNext:)`, `drive(with:onNext:)` all weakly capture the first argument and pass it back as `owner`. Prefer these in new code — fewer characters, no `guard let self` boilerplate, impossible to forget the `weak`.

### `[unowned self]`

```swift
// ⚠️ Use only when self CANNOT outlive the subscription
.subscribe(onNext: { [unowned self] value in … })
```

Reserve `unowned` for situations where the subscription is **strictly** scoped to `self`'s lifetime (e.g., subscribing in `init`, disposing in `deinit`-bound bag, no async hops). When in doubt, `weak`.

## Retain cycles (Bad → Good)

### Closure captures `self`

```swift
// ❌ Cycle
button.rx.tap
    .subscribe(onNext: { self.handleTap() })
    .disposed(by: disposeBag)
```

```swift
// ✅ Break with weak
button.rx.tap
    .subscribe(with: self) { owner, _ in owner.handleTap() }
    .disposed(by: disposeBag)
```

### Subject owned by `self`, subscribed by `self`

```swift
// ❌ self → subject → subscription → self
private let event = PublishSubject<Void>()

init() {
    event.subscribe(onNext: { self.didFire() })
        .disposed(by: bag)
}
```

```swift
// ✅ Same fix — the owning side must capture weakly
init() {
    event.subscribe(with: self) { owner, _ in owner.didFire() }
        .disposed(by: bag)
}
```

### Storing closures captured from streams

```swift
// ❌ Stream completes, but `self.handler` keeps the closure alive forever
single
    .subscribe(onSuccess: { value in self.handler = { value } })
    .disposed(by: bag)
```

If a closure escapes the stream, weak-capture **inside** the escaping closure too:

```swift
// ✅
single
    .subscribe(with: self) { owner, value in
        owner.handler = { [weak owner] in owner?.use(value) }
    }
    .disposed(by: bag)
```

## "It never fires" — the disposable disappeared

```swift
// ❌ `_ = …` discards the Disposable; subscription is torn down at end of statement
_ = button.rx.tap.subscribe(onNext: { print("tap") })

// ❌ Local Disposable; same problem
func setup() {
    let d = button.rx.tap.subscribe(onNext: { print("tap") })
}   // `d` deinits here → dispose() runs → no taps ever observed
```

```swift
// ✅
button.rx.tap
    .subscribe(onNext: { print("tap") })
    .disposed(by: disposeBag)
```

If subscriptions appear to "do nothing", the first thing to check is that they're rooted in a long-lived bag.

## Composition over nested subscribe

The single most common smell. If you find yourself subscribing inside a `subscribe`, you almost always want a flatMap-family operator (see `operators.md`).

```swift
// ❌ Nested — disposal of the inner subscription is unmanaged
search.text
    .subscribe(onNext: { query in
        api.search(query)
            .subscribe(onNext: { results in self.show(results) })
            .disposed(by: self.bag)         // ← stale, never replaced
    })
    .disposed(by: bag)
```

```swift
// ✅ Composition — flatMapLatest cancels the previous inner request automatically
search.text
    .flatMapLatest { query in api.search(query) }
    .bind(with: self) { owner, results in owner.show(results) }
    .disposed(by: bag)
```

`flatMapLatest` not only flattens — it **cancels the previous inner Observable** when a new outer value arrives. That's the right behaviour for search: stale results are dropped automatically. This is also the canonical fix for race conditions in dependent network calls.

## Take-until: scoping subscriptions to a lifetime

When you want a subscription to die when some other event happens (instead of when a bag deinits), use `take(until:)`:

```swift
let stop = PublishRelay<Void>()

source
    .take(until: stop)        // completes the stream when `stop` emits
    .subscribe(onNext: { … })
    .disposed(by: bag)

// Later:
stop.accept(())               // subscription completes cleanly
```

Useful for "subscribe until this dialog dismisses" or "subscribe until this Reactor's transformation phase ends."

A common helper is `rx.deallocated` (RxCocoa, on `NSObject`):

```swift
source
    .take(until: someObject.rx.deallocated)
    .subscribe(…)
    .disposed(by: bag)
```

## Rules of thumb

- **Top-level `let disposeBag = DisposeBag()`** for VCs, Views, ViewModels, Reactors.
- **`var disposeBag` only on cells**, replaced in `prepareForReuse`.
- **`subscribe(with:)` / `bind(with:)` / `drive(with:)`** by default for any closure that touches `self`.
- **`disposed(by:)` on every subscription**, no exceptions in app code.
- **One outer subscribe, many composed operators** — never `subscribe` inside `subscribe`.
- **`take(until:)`** when the lifetime is event-driven, not owner-driven.

## Cross-references

- Why nested subscribe is wrong + flatMap family fix → `operators.md`
- Subjects/Relays leaking write access (and how `asDriver` solves it) → `subjects-and-relays.md`, `traits.md`
- Anti-patterns catalog (missing `disposed(by:)`, `unowned` misuse, …) → `anti-patterns.md`
