# Anti-Patterns

A catalog of the most common RxSwift mistakes, as **Bad → Good** pairs. Read this on every code review and whenever a stream "feels off." Each entry links back to the topic file with the full explanation.

> Read this when: reviewing Rx code, refactoring a noisy ViewModel, or trying to articulate why a working snippet still smells.

## 1. Nested `subscribe`

```swift
// ❌ Subscription inside a subscription
search.text.orEmpty
    .subscribe(onNext: { query in
        api.search(query)
            .subscribe(onNext: { results in self.show(results) })
            .disposed(by: self.bag)             // bag accumulates dead subs
    })
    .disposed(by: bag)
```

```swift
// ✅ Compose with flatMapLatest — also cancels the previous request
search.text.orEmpty
    .flatMapLatest { query in api.search(query).catchAndReturn([]) }
    .bind(with: self) { owner, results in owner.show(results) }
    .disposed(by: bag)
```

Nested subscribe **never** beats `flatMap`/`flatMapLatest`/`flatMapFirst`. See `operators.md`, `disposal-and-memory.md`.

## 2. Missing `disposed(by:)`

```swift
// ❌ Disposable thrown away → subscription dies immediately
_ = button.rx.tap.subscribe(onNext: { print("tap") })

func setup() {
    let d = button.rx.tap.subscribe(onNext: { print("tap") })
}   // d goes out of scope → no taps observed
```

```swift
// ✅
button.rx.tap.subscribe(onNext: { print("tap") }).disposed(by: bag)
```

Every `subscribe`/`bind`/`drive`/`emit` in app code ends in `.disposed(by: bag)`. See `disposal-and-memory.md`.

## 3. Strong `self` capture in closures

```swift
// ❌ Cycle: self → bag → Disposable → closure → self
viewModel.greeting
    .subscribe(onNext: { self.label.text = $0 })
    .disposed(by: disposeBag)
```

```swift
// ✅ Use the with-form (RxSwift 6+)
viewModel.greeting
    .subscribe(with: self) { owner, greeting in owner.label.text = greeting }
    .disposed(by: disposeBag)

// Or the explicit weak form
viewModel.greeting
    .subscribe(onNext: { [weak self] greeting in self?.label.text = greeting })
    .disposed(by: disposeBag)
```

`subscribe(with:)`, `bind(with:onNext:)`, `drive(with:onNext:)`, `emit(with:onNext:)` all weak-capture — prefer them. Reserve `[unowned self]` for proven-safe lifetimes only. See `disposal-and-memory.md`.

## 4. Imperative `.value` reads on `BehaviorRelay`

```swift
// ❌ Treats Rx state like a mutable variable
let next = counter.value + 1
counter.accept(next)
```

```swift
// ✅ Derive with scan
trigger
    .scan(0) { acc, _ in acc + 1 }
    .bind(to: counter)
    .disposed(by: bag)
```

`.value` reads are legitimate **only** at boundaries (handing a snapshot to a delegate-based API, asserting in tests). Inside a stream, derive. See `subjects-and-relays.md`.

## 5. Exposing a Subject/Relay publicly

```swift
// ❌ Anyone can call accept from outside; encapsulation broken
final class FeedViewModel {
    let items = BehaviorRelay<[Item]>(value: [])
}
```

```swift
// ✅ Private write, public Driver
final class FeedViewModel {
    private let _items = BehaviorRelay<[Item]>(value: [])
    var items: Driver<[Item]> { _items.asDriver() }
}
```

The View consumes a `Driver` and **can't** push back. See `subjects-and-relays.md`, `architecture.md`.

## 6. UI bound to a non-MainScheduler stream

```swift
// ❌ "Main Thread Checker" warning, intermittent crashes
api.fetchTitle()
    .subscribe(on: backgroundScheduler)
    .bind(to: titleLabel.rx.text)
    .disposed(by: bag)
```

```swift
// ✅ Hop back to main before binding
api.fetchTitle()
    .subscribe(on: backgroundScheduler)
    .observe(on: MainScheduler.instance)
    .bind(to: titleLabel.rx.text)
    .disposed(by: bag)

// Or — even simpler — convert to Driver
api.fetchTitle()
    .asDriver(onErrorJustReturn: "")
    .drive(titleLabel.rx.text)
    .disposed(by: bag)
```

See `schedulers.md`, `traits.md`, `rxcocoa-bindings.md`.

## 7. `flatMap` where `flatMapLatest` belongs

```swift
// ❌ Search fires every keystroke; race conditions reorder results
search.text.orEmpty
    .flatMap { api.search($0) }              // multiple in-flight requests
    .bind(to: results)
    .disposed(by: bag)
```

```swift
// ✅ Only the latest survives
search.text.orEmpty
    .flatMapLatest { api.search($0).catchAndReturn([]) }
    .bind(to: results)
    .disposed(by: bag)
```

For UI-driven outer streams, the default is `flatMapLatest`. See `operators.md` (flatMap family decision matrix).

## 8. Manual `DispatchQueue.main.async` inside `subscribe`

```swift
// ❌ Bypassing Rx's threading model
api.fetch().subscribe(onNext: { value in
    DispatchQueue.main.async { self.label.text = value }
}).disposed(by: bag)
```

```swift
// ✅
api.fetch()
    .observe(on: MainScheduler.instance)
    .subscribe(with: self) { owner, value in owner.label.text = value }
    .disposed(by: bag)
```

Schedulers exist for exactly this. See `schedulers.md`.

## 9. `do(onNext:)` as a side-effect dump

```swift
// ❌ State mutation inside do — fires per subscription, hard to reason about
source
    .do(onNext: { self.cache.write($0) })
    .map { $0.title }
    .bind(to: titleLabel.rx.text)
    .disposed(by: bag)
```

```swift
// ✅ Side effects live in subscribe (or in a Reactor's mutate)
source
    .do(onNext: { Analytics.log(saw: $0) })          // pure observation: OK
    .map { $0.title }
    .bind(to: titleLabel.rx.text)
    .disposed(by: bag)

source
    .subscribe(with: self) { owner, value in owner.cache.write(value) }
    .disposed(by: bag)
```

`do` is for **non-state-mutating observation** (logging, telemetry, breakpoints). Anything that changes app state belongs in `subscribe(onNext:)` or `mutate(action:)`. See `operators.md`.

## 10. Silent error termination

```swift
// ❌ bind(onNext:) swallows errors in release; ViewModel goes silent after first failure
search.text.orEmpty
    .flatMapLatest { api.search($0) }     // can error
    .bind(onNext: { results in self.show(results) })
    .disposed(by: bag)
```

```swift
// ✅ Contain the error inside flatMapLatest so the outer stream survives
search.text.orEmpty
    .flatMapLatest { api.search($0).catchAndReturn([]) }
    .bind(with: self) { owner, results in owner.show(results) }
    .disposed(by: bag)
```

The catch belongs **inside** the `flatMapLatest`. See `error-handling.md`.

## 11. Unbounded `retry()`

```swift
// ❌ Infinite retry on persistent failure → tight loop hammering the API
api.fetch().retry()
```

```swift
// ✅ Always bound: count or backoff
api.fetch().retry(3)

api.fetch().retry { errors in
    errors.enumerated().flatMap { attempt, _ -> Observable<Int> in
        guard attempt < 3 else { return .error(StopRetrying()) }
        let delay = Int(pow(2.0, Double(attempt)))
        return .timer(.seconds(delay), scheduler: MainScheduler.instance)
    }
}
```

See `error-handling.md`.

## 12. Multiple `observe(on:)` hops with no purpose

```swift
// ❌ Five context switches for no reason
source
    .observe(on: schedulerA).map { … }
    .observe(on: schedulerB).map { … }
    .observe(on: schedulerC).filter { … }
    .observe(on: MainScheduler.instance)
    .bind(…)
```

```swift
// ✅ One background hop, one main hop
source
    .observe(on: backgroundScheduler)
    .map { … }.map { … }.filter { … }
    .observe(on: MainScheduler.instance)
    .bind(…)
```

Most operators (`map`, `filter`, `scan`) are scheduler-agnostic. Hop only at thread boundaries. See `schedulers.md`.

## 13. `subscribe(onNext:)` directly on a UI control

```swift
// ❌ Reinvents bind(to:); error handling unclear
viewModel.title
    .subscribe(onNext: { self.titleLabel.text = $0 })
    .disposed(by: bag)
```

```swift
// ✅
viewModel.title
    .bind(to: titleLabel.rx.text)
    .disposed(by: bag)

// Or, for a Driver
viewModel.title
    .drive(titleLabel.rx.text)
    .disposed(by: bag)
```

`bind`/`drive`/`emit` reveal intent and benefit from RxCocoa's main-thread guarantees. See `rxcocoa-bindings.md`.

## 14. `DisposeBag` declared as `var` and reassigned mid-life

```swift
// ❌ Reassignment silently disposes ALL existing subscriptions
class MyVC {
    var disposeBag = DisposeBag()
    func reset() {
        disposeBag = DisposeBag()                  // throws away every binding so far
    }
}
```

```swift
// ✅ Top-level let + scoped resets via take(until:)
class MyVC {
    private let disposeBag = DisposeBag()
    private let resetTrigger = PublishRelay<Void>()
    func bindResettableSubscription() {
        viewModel.stream
            .take(until: resetTrigger)
            .subscribe(…)
            .disposed(by: disposeBag)
    }
    func reset() { resetTrigger.accept(()) }
}
```

The only case where `var disposeBag` is correct: **`UITableViewCell` / `UICollectionViewCell` reset in `prepareForReuse`**. See `disposal-and-memory.md`.

## 15. Subscribing inside a Reactor's `reduce`

```swift
// ❌ reduce must be pure; subscribing here causes leaks and breaks testability
func reduce(state: State, mutation: Mutation) -> State {
    var s = state
    api.log(mutation).subscribe().disposed(by: bag)     // 💥 wrong place
    return s
}
```

```swift
// ✅ Side effects belong in mutate
func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .somethingHappened:
        return api.log(.somethingHappened).andThen(.empty())
    }
}
```

See `architecture.md`.

## 16. `BehaviorRelay` self-feedback loop

```swift
// ❌ Infinite loop
relay.subscribe(onNext: { value in
    relay.accept(value + 1)
}).disposed(by: bag)
```

```swift
// ✅ Derive without writing back into the same source
trigger
    .scan(0) { acc, _ in acc + 1 }
    .bind(to: relay)
    .disposed(by: bag)
```

See `subjects-and-relays.md`.

## 17. `Driver` with side effects in `do(onNext:)`

```swift
// ❌ Driver is shared; each subscriber re-runs side effects, or the share replays them on every subscribe
viewModel.user
    .do(onNext: { Analytics.viewedProfile(of: $0) })
    .drive(profileView.rx.user)
    .disposed(by: bag)
```

The Analytics call fires per subscription **and** per replayed value on re-binds. Move analytics to a `Signal` or a discrete event stream:

```swift
// ✅
viewModel.didViewProfile
    .emit(onNext: { Analytics.viewedProfile(of: $0) })
    .disposed(by: bag)
```

See `traits.md`, `rxcocoa-bindings.md`.

## 18. `for try await` over an infinite Observable

```swift
// ❌ Hangs the Task forever
Task {
    for try await tap in button.rx.tap.asObservable().values { … }
}
```

```swift
// ✅ Bound the stream
Task {
    for try await tap in button.rx.tap.asObservable().take(until: closeRelay).values { … }
}
```

See `swift-concurrency-interop.md`.

## 19. `disposed(by:)` on a bag belonging to a different owner

```swift
// ❌ Cell stores subscription in parent VC's bag → cell dealloc doesn't dispose
class Cell {
    func bind(parentBag: DisposeBag) {
        viewModel.title.bind(to: label.rx.text).disposed(by: parentBag)
    }
}
```

```swift
// ✅ Each owner has its own bag
class Cell {
    var disposeBag = DisposeBag()
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
    func bind(viewModel: ViewModel) {
        viewModel.title.bind(to: label.rx.text).disposed(by: disposeBag)
    }
}
```

See `disposal-and-memory.md`.

## 20. Swallowing errors with `bind(onNext:)` on fallible sources

```swift
// ❌ Errors silently logged in debug, swallowed in release
api.fetchUser()
    .bind(onNext: { user in self.show(user) })
    .disposed(by: bag)
```

```swift
// ✅ Handle both cases
api.fetchUser()
    .subscribe(
        with: self,
        onNext: { owner, user in owner.show(user) },
        onError: { owner, error in owner.show(error) }
    )
    .disposed(by: bag)

// Or convert to a Single and handle explicitly
api.fetchUser()
    .asSingle()
    .subscribe(onSuccess: { user in self.show(user) },
               onFailure: { error in self.show(error) })
    .disposed(by: bag)
```

`bind(onNext:)` is intended for sources known not to error (Relays, Drivers, Signals). For fallible Observables, use full `subscribe(_:)` or convert to a Trait. See `error-handling.md`.

## Cross-references

This catalog is a checklist; for full explanation of any item, follow the link. Most reviews surface 2–4 items here per file. The two highest-yield checks:

1. **Item 1 (nested subscribe)** — refactor with `flatMap`-family.
2. **Item 7 (`flatMap` vs `flatMapLatest`)** — single most common production race condition.
