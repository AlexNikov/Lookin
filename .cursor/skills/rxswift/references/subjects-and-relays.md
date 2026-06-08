# Subjects and Relays

A **Subject** is both an `Observer` (you push values in) and an `Observable` (others subscribe out). A **Relay** is a thin wrapper around a Subject that **never errors and never completes** — you only push values via `accept(_:)`.

If you only need a read-only stream (factory of values), see `observables.md`. Reach for a Subject/Relay when something **outside the stream** (a tap handler, a network callback, a parent ViewModel) needs to push values **into** it.

> Read this when: you need a writable source, you're choosing between Publish/Behavior/Replay/Async, or you need to decide Subject vs Relay.

## The four Subjects

All four live in `RxSwift`. They differ only in **what late subscribers receive**.

### `PublishSubject<T>`

Emits **only the values that arrive after subscription**. Late subscribers miss prior values.

```swift
let subject = PublishSubject<String>()
subject.onNext("a")                           // no one is listening; lost
subject.subscribe(onNext: { print($0) })
    .disposed(by: bag)
subject.onNext("b")                           // prints "b"
```

Use for **events**: button taps, request-completed signals, ephemeral notifications.

### `BehaviorSubject<T>`

Holds the **most recent value** (or an initial seed) and replays it to new subscribers.

```swift
let subject = BehaviorSubject<String>(value: "initial")
subject.onNext("a")
subject.subscribe(onNext: { print($0) })      // prints "a" immediately
    .disposed(by: bag)
subject.onNext("b")                           // prints "b"
```

Use for **state**: current user, selected tab, loading flag — anything where a new subscriber must immediately know the current value.

You can also read the current value synchronously: `try subject.value()` (throws if the subject has terminated).

### `ReplaySubject<T>`

Buffers the last **N** values and replays them all to new subscribers.

```swift
let subject = ReplaySubject<String>.create(bufferSize: 3)
subject.onNext("a"); subject.onNext("b"); subject.onNext("c"); subject.onNext("d")
subject.subscribe(onNext: { print($0) })      // prints "b", "c", "d"
    .disposed(by: bag)
```

Use for **history feeds**: chat messages, notification logs, the last few errors. Beware unbounded buffers — `ReplaySubject.createUnbounded()` exists but holds every value forever.

### `AsyncSubject<T>`

Emits **only the last value**, and only when the source **completes**.

```swift
let subject = AsyncSubject<String>()
subject.onNext("a"); subject.onNext("b"); subject.onNext("c")
subject.subscribe(onNext: { print($0) })
    .disposed(by: bag)
subject.onCompleted()                         // prints "c", then completes
```

Rarely used in app code. The same effect is usually clearer with a `Single` (see `traits.md`).

## The three Relays (RxRelay)

Relays are Subjects with two safety guarantees:

1. **Never emit `.error`** — the API has no `onError` method.
2. **Never emit `.completed`** — the API has no `onCompleted` method.

You push values with `accept(_:)`. Because relays cannot terminate, they're ideal for **state and event streams that must outlive transient errors** — exactly what UIs need.

> Note: `RxRelay` is a **separate module** since RxSwift 5. Add `RxRelay` to your dependencies and `import RxRelay` to use it.

### `PublishRelay<T>`

`PublishSubject` + relay guarantees. Use for **UI events**.

```swift
let tap = PublishRelay<Void>()
tap.subscribe(onNext: { print("tapped") }).disposed(by: bag)
tap.accept(())
```

### `BehaviorRelay<T>`

`BehaviorSubject` + relay guarantees + a **synchronous `.value`** read.

```swift
let isLoading = BehaviorRelay(value: false)
print(isLoading.value)        // false (synchronous)
isLoading.accept(true)
isLoading.subscribe(onNext: { print("loading:", $0) })
    .disposed(by: bag)         // immediately prints "loading: true"
```

The workhorse for **ViewModel state**. Pair with `asDriver()` to expose to the View (see `traits.md`).

### `ReplayRelay<T>`

`ReplaySubject` + relay guarantees. Use for **bounded history**.

```swift
let recent = ReplayRelay<String>.create(bufferSize: 5)
recent.accept("hello")
recent.accept("world")
recent.subscribe(onNext: { print($0) }).disposed(by: bag)  // prints both
```

## Subject vs Relay — decision table

| Question | Choose Subject if… | Choose Relay if… |
|---|---|---|
| Can the stream produce a **terminal error**? | Yes — caller needs to react to failure | No — error handling lives elsewhere |
| Should the stream ever **complete**? | Yes — finite work (download finished, dialog closed) | No — outlives the producer (UI state, app-wide events) |
| Will it back a **UI binding** (Driver/Signal source)? | Rare | Yes — UI must never see `.error`/`.completed` |
| Pushed into from **synchronous code**? | Either | Either |
| Synchronous read of "current value" needed? | Use `BehaviorSubject.value()` (throws) | Use `BehaviorRelay.value` (clean) |

**Default for app code: Relay.** Subjects are correct only when the terminal events carry meaning that the consumer must handle.

## Mapping table

| Need | Subject | Relay |
|---|---|---|
| Push events, no replay | `PublishSubject` | `PublishRelay` |
| Push state, replay current | `BehaviorSubject` | `BehaviorRelay` |
| Push history, replay last N | `ReplaySubject` | `ReplayRelay` |
| Push values, emit only the last on completion | `AsyncSubject` | (no relay equivalent — use `Single`) |

## Pitfall: leaking write access

Exposing a Subject/Relay publicly lets **any caller** push into it, breaking the ViewModel's encapsulation.

```swift
// ❌ Anyone can call self.items.accept(…) from outside
final class ListViewModel {
    let items = BehaviorRelay<[Item]>(value: [])
}
```

```swift
// ✅ Internal write, public read-only Driver
final class ListViewModel {
    private let _items = BehaviorRelay<[Item]>(value: [])
    var items: Driver<[Item]> { _items.asDriver() }
}
```

The View consumes `items` as a `Driver` and physically cannot call `accept`. This pattern shows up everywhere; see `architecture.md` (MVVM I/O) and `traits.md` (Driver).

## Pitfall: imperative reads on `BehaviorRelay`

```swift
// ❌ Treats Rx state as a mutable variable
let current = relay.value
relay.accept(current + 1)
```

This works but defeats the point of Rx — every consumer of `relay` recomputes from scratch on every `accept`. If you find yourself reading `.value` to compute the next `.value`, consider `scan`:

```swift
// ✅ Pure derivation
input.scan(0) { acc, _ in acc + 1 }
    .bind(to: counterRelay)
    .disposed(by: bag)
```

`.value` reads are still legitimate when **bridging** to non-Rx code (e.g., providing a snapshot to a delegate-based API), but treat them as the exception, not the default.

## Pitfall: infinite loop via self-feedback

```swift
// ❌ relay.accept inside relay.subscribe → loops forever
relay.subscribe(onNext: { value in
    relay.accept(value + 1)
}).disposed(by: bag)
```

Use `scan` or `withLatestFrom` to derive without writing back into the same source. If two relays genuinely depend on each other, the loop must be broken with `distinctUntilChanged` plus careful seeding — and that's almost always a sign the design should be flattened.

## Pitfall: `BehaviorSubject` as an Observable seed

```swift
// ❌ Hidden assumption: subscriber wants the seed re-emitted on every subscribe
private let _state = BehaviorSubject<State>(value: .idle)
var state: Observable<State> { _state.asObservable() }
```

This is fine, but if the consumer is a UI, expose a **Driver** instead so the seed is replayed and the stream is guaranteed main-thread + error-free. See `traits.md`.

## Cross-references

- Hot vs Cold mechanics → `observables.md`
- Why Subjects publicly exposed cause leaks (`asDriver()`, `asSignal()`) → `traits.md`, `rxcocoa-bindings.md`
- Why errors terminate streams → `error-handling.md`
- Anti-patterns: leaking write access, imperative `.value`, infinite loops → `anti-patterns.md`
