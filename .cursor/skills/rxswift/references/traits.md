# Traits

A **Trait** is a specialized wrapper around `Observable<T>` that narrows the contract — fewer events, stronger guarantees, clearer intent. RxSwift ships three Traits in the core (`Single`, `Maybe`, `Completable`) and RxCocoa adds two more for UI work (`Driver`, `Signal`). Picking the right Trait makes the call site self-documenting and the type system enforce constraints that would otherwise live in comments.

> Read this when: choosing a return type for a function, deciding what a ViewModel should expose, converting between Trait and Observable.

## Why Traits exist

A function returning `Observable<User>` could in principle emit zero, one, or many users; complete cleanly or with an error; and run on any scheduler. The caller has to read the body to know which is meant. Traits fix this:

- **`Single`** — one value or one error. Compiler-enforced.
- **`Maybe`** — zero or one value, or an error.
- **`Completable`** — no value, just success or error.
- **`Driver`** — UI-safe stream: never errors, always main-thread, replays the latest.
- **`Signal`** — UI-safe stream: never errors, always main-thread, **does not** replay.

## RxSwift Traits

### `Single<T>`

Emits **exactly one** of `.success(T)` or `.failure(Error)`.

```swift
func fetchUser(id: Int) -> Single<User> {
    Single.create { single in
        let task = api.user(id: id) { result in
            switch result {
            case .success(let user): single(.success(user))
            case .failure(let error): single(.failure(error))
            }
        }
        return Disposables.create { task.cancel() }
    }
}

fetchUser(id: 1)
    .subscribe(onSuccess: { user in print(user) },
               onFailure: { error in print(error) })
    .disposed(by: bag)
```

**Use for**: HTTP requests, file reads, anything with a single async result.

### `Maybe<T>`

Emits **at most one** of `.success(T)`, `.completed`, or `.error(Error)`.

```swift
func loadCachedUser() -> Maybe<User> {
    cache.contains(.user)
        ? .just(cache.user)        // success with value
        : .empty()                 // completion, no value
}
```

**Use for**: cache lookups, optional async lookups where "nothing" is a normal outcome (distinct from "error").

### `Completable`

Emits **only** `.completed` or `.error(Error)`. No values.

```swift
func saveSettings(_ s: Settings) -> Completable {
    Completable.create { completable in
        do {
            try storage.write(s)
            completable(.completed)
        } catch {
            completable(.error(error))
        }
        return Disposables.create()
    }
}
```

**Use for**: fire-and-forget side effects whose only outcomes are success/failure (writes, DELETE requests, animations).

### Conversions

```swift
let observable: Observable<User> = single.asObservable()
let observable: Observable<Void> = completable.asObservable()
let single: Single<User?> = maybe.ifEmpty(default: nil).asSingle()
let single: Single<User> = observable.asSingle()        // errors if 0 or 2+ values
let maybe: Maybe<User> = observable.asMaybe()           // errors if 2+ values
```

`asSingle()` and `asMaybe()` enforce the Trait contract at runtime — if the underlying Observable misbehaves, you get an error.

## RxCocoa Traits

These live in `RxCocoa` (and depend on `RxRelay` indirectly). Both belong to a family called `SharedSequence`, which guarantees:

1. **Never errors** — error is impossible at the type level.
2. **Always delivered on `MainScheduler`** — safe to bind to UI without an explicit `observe(on:)`.
3. **Multicast** — under the hood, `share` is applied. Multiple subscribers share one upstream subscription.

### `Driver<T>`

`SharedSequence` with `replay: 1`. New subscribers immediately get the latest value.

```swift
let title: Driver<String> = viewModel.title
title.drive(titleLabel.rx.text)
    .disposed(by: bag)
```

**Use for**: UI **state** (current title, isLoading, the user's profile). The "drive" verb signals "this stream powers the UI."

### `Signal<T>`

`SharedSequence` without replay. New subscribers get values from the moment they subscribe — past values are lost.

```swift
let didLogin: Signal<User> = viewModel.didLogin
didLogin.emit(onNext: { user in router.show(user) })
    .disposed(by: bag)
```

**Use for**: UI **events** that have meaning only at the moment they fire (didLogin, showAlert, popToRoot). The "emit" verb signals "this is a one-shot event."

### `Driver` vs `Signal` decision

| Question | Driver | Signal |
|---|---|---|
| Should a new subscriber receive the latest value immediately? | Yes | No |
| Re-presenting the View (rotation, push/pop) — should it still show the right thing? | Yes | n/a (events are gone) |
| Are values meaningful in isolation (each one is a fresh event)? | n/a | Yes |
| Common analogy | "Property" | "Notification" |

If you're not sure, `Driver` is the safer default for ViewModel outputs that the View renders.

### `Driver` vs `BehaviorRelay` as a ViewModel output

| | `BehaviorRelay<T>` (exposed) | `Driver<T>` (via `asDriver()`) |
|---|---|---|
| External callers can `accept`? | Yes (encapsulation broken) | No |
| Multicast | No (each subscribe re-runs) | Yes (built-in `share`) |
| Main-thread guarantee | No | Yes |
| Error possible | No | No |
| Use as | Internal storage | Public output |

The pattern: store as `private let _x = BehaviorRelay(value: …)`, expose as `var x: Driver<T> { _x.asDriver() }`. See `subjects-and-relays.md` and `architecture.md`.

## Conversions to and from Cocoa Traits

```swift
// Observable → Driver
let driver = observable.asDriver(onErrorJustReturn: .placeholder)
let driver = observable.asDriver(onErrorRecover: { _ in .empty() })
let driver = observable.asDriver(onErrorDriveWith: .never())

// Observable → Signal
let signal = observable.asSignal(onErrorJustReturn: defaultValue)

// BehaviorRelay → Driver
let driver = behaviorRelay.asDriver()         // no error case needed; relays never error

// PublishRelay → Signal
let signal = publishRelay.asSignal()

// ControlProperty → Driver (free; ControlProperty is already MainScheduler + share)
let textDriver = textField.rx.text.asDriver()
```

The `onErrorJustReturn:` / `onErrorRecover:` parameter is mandatory when converting a fallible source — the Trait promises "never errors", so you must specify the recovery up front.

## Trait operators

Most familiar operators have Trait counterparts: `map`, `filter`, `flatMap`, `flatMapLatest`, `do`, `observe(on:)`, `subscribe(on:)`, etc. They preserve the Trait shape:

```swift
single.map { $0.name }                  // Single<String>
single.flatMap { fetch(by: $0.id) }     // Single<U> (inner must also be Single)

driver.distinctUntilChanged()           // Driver<T> — already MainScheduler
driver.map { $0.uppercased() }          // Driver<U>
```

Mixed shapes typically require dropping back to `Observable`:

```swift
// Single<T> + Observable<U> → Observable<…> (loses Single-ness)
Observable.combineLatest(single.asObservable(), publisher) { … }
```

## When to drop a Trait

If you find yourself fighting the type — wrapping `Observable.create` to return a `Single`, then immediately converting back, or `flatMap`ping into a non-Trait result — you may not actually want a Trait. Use `Observable<T>` and add a doc comment about the expected shape. The Trait is only worth it when **callers benefit** from the narrower contract.

## Cross-references

- Driver/Signal binding APIs (`drive`, `emit`) → `rxcocoa-bindings.md`
- Why Relays pair with `asDriver()` for ViewModel outputs → `subjects-and-relays.md`, `architecture.md`
- Error recovery operators that feed `asDriver(onErrorJustReturn:)` → `error-handling.md`
- Testing Driver/Signal → `testing.md`
- Trait values from async code (`try await single.value`) → `swift-concurrency-interop.md`
