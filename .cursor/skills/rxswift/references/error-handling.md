# Error Handling

The single most-violated assumption in Rx code: **errors terminate streams, permanently**. Once an Observable emits `.error(Error)`, no further events will ever flow through that subscription. The fix is to design with this in mind — pick **error-less designs** for UI streams, and use the recovery operators (`catch`, `catchAndReturn`, `retry`, `materialize`) where errors are legitimate signals.

> Read this when: a stream "dies" after one network failure, designing retry logic, deciding whether to surface errors as terminal events or as values, or recovering from errors mid-pipeline.

## The mental model

Recall the Observable grammar (see `observables.md`):

```
next* (error | completed)?
```

Both `.error` and `.completed` are **terminal**. A subscription that errors:

1. **Never re-emits.** Even if the underlying source recovers, the subscription is dead.
2. **Disposes itself.** The `Disposable` is cleaned up automatically.
3. **Cannot be reused.** A new subscription on the same `Observable` may produce a fresh stream (Cold) or the latest state (Hot), but **the failed subscription is gone**.

Common consequence: a search-as-you-type ViewModel that emits an error from one network failure stops responding to all future input. You must **either** prevent the error from reaching the public stream, **or** model the failure as a value (e.g., `.failure(reason)`).

## RxSwift 6 naming reminder

- `catchError` → **`catch`** (Swift keyword; sometimes needs backticks like `` `catch` `` in unusual positions).
- `catchErrorJustReturn` → **`catchAndReturn`**.

If a codebase uses the old names, it's on RxSwift 5. Don't recommend the new names without confirming the dependency version.

## Recovery operators

### `catch` — recover with another Observable

```swift
api.fetchUser()
    .catch { error in
        log.warn("fetchUser failed:", error)
        return cache.user()                   // Single<User> (asObservable() implied)
    }
    .subscribe(…)
    .disposed(by: bag)
```

`catch` lets you swap the failed stream for a recovery stream. Use when the recovery is itself async or itself fallible.

### `catchAndReturn` — recover with a constant

```swift
api.fetchTitle()
    .catchAndReturn("(no title)")
    .bind(to: titleLabel.rx.text)
    .disposed(by: bag)
```

The simplest recovery: substitute a default value. Indispensable for `asDriver(onErrorJustReturn:)` / `asSignal(onErrorJustReturn:)` conversions where the Trait demands an error-free contract.

### `retry`

```swift
api.fetchUser().retry(3)               // up to 3 attempts on error
api.fetchUser().retry()                // ⚠️ retries FOREVER — almost always wrong
```

**Never** `retry()` with no argument in app code. A persistent backend failure becomes an infinite tight loop hammering the API. Always pass a count or use `retry(when:)`.

### `retry(when:)` — backoff

```swift
api.fetchUser()
    .retry { errors -> Observable<Int> in
        errors
            .enumerated()
            .flatMap { attempt, error -> Observable<Int> in
                guard attempt < 3 else { return .error(error) }      // give up after 3
                let delay = Int(pow(2.0, Double(attempt)))
                return .timer(.seconds(delay), scheduler: MainScheduler.instance)
            }
    }
```

The closure receives the error stream; emit a value to retry, emit error to abort. Standard exponential-backoff template.

### `materialize` / `dematerialize`

```swift
let events = api.fetchUser().materialize()       // Observable<Event<User>> — never errors

events
    .compactMap { $0.element }                    // values only
    .bind(to: userRelay)
    .disposed(by: bag)

events
    .compactMap { $0.error }
    .bind(to: errorRelay)
    .disposed(by: bag)
```

`materialize` converts each event into a plain value, so the stream survives errors. Useful for telemetry, "log every event", and pipelines that branch into separate value/error streams. `dematerialize` reverses the conversion.

### `do(onError:)` — observe without recovering

```swift
api.fetch()
    .do(onError: { Analytics.log(failure: $0) })
    .subscribe(…)
```

Side-effect observation only. The stream still terminates on error.

## Designing for error-less UI streams

UI streams should almost never carry `.error`. The View can't usefully react to a "dead stream"; it needs **values** (including failure values) to render.

### Pattern 1: convert to `Result` at the boundary

```swift
let userResult: Driver<Result<User, Error>> = api.fetchUser()
    .map { Result.success($0) }
    .catch { .just(.failure($0)) }
    .asDriver(onErrorJustReturn: .failure(URLError(.cancelled)))

userResult
    .drive(with: self) { owner, result in
        switch result {
        case .success(let user): owner.show(user)
        case .failure(let error): owner.showError(error)
        }
    }
    .disposed(by: bag)
```

The stream stays alive forever; failures become values the View pattern-matches.

### Pattern 2: split into success / error streams

```swift
let result = api.fetchUser().materialize().share(replay: 1, scope: .whileConnected)

let user = result.compactMap { $0.element }.asDriver(onErrorJustReturn: .placeholder)
let failure = result.compactMap { $0.error }.asSignal(onErrorJustReturn: someError)

user.drive(profileView.rx.user).disposed(by: bag)
failure.emit(to: errorBannerRelay).disposed(by: bag)
```

Two driver/signal outputs from one underlying source. Common in MVVM Input/Output ViewModels (see `architecture.md`).

### Pattern 3: hold the latest state in a Relay

```swift
let state = BehaviorRelay<RemoteState<User>>(value: .idle)

button.rx.tap
    .flatMapLatest { _ in
        api.fetchUser()
            .map(RemoteState.loaded)
            .catch { .just(.failed($0)) }
            .startWith(.loading)
    }
    .bind(to: state)
    .disposed(by: bag)
```

`RemoteState` is a custom enum (`.idle | .loading | .loaded(T) | .failed(Error)`). The View renders the current state; the stream behind the relay is allowed to error internally because the error becomes a value (`.failed`). The relay never errors.

## When errors *should* propagate

For **bounded async work** with a single result — a network call returning a `Single`, a save `Completable` — errors are legitimate terminal events. The caller of the function is expected to handle them. Don't reach for `materialize` on a `Single`; just use `subscribe(onSuccess:onFailure:)`.

```swift
api.saveSettings(s)
    .subscribe(onCompleted: { ack() },
               onFailure: { showError($0) })
    .disposed(by: bag)
```

The pattern shifts only when these one-shot streams feed a longer-lived UI stream — that's where the conversions above apply.

## Common bugs

### "My ViewModel goes silent after one failed request"

```swift
// ❌ Stream terminates on error; no future inputs are processed
search.text.orEmpty
    .flatMapLatest { api.search($0) }       // errors propagate
    .bind(to: resultsRelay)
    .disposed(by: bag)
```

```swift
// ✅ Catch inside flatMapLatest so the outer stream never errors
search.text.orEmpty
    .flatMapLatest { query in
        api.search(query)
            .catchAndReturn([])             // contain failure to one query
    }
    .bind(to: resultsRelay)
    .disposed(by: bag)
```

The `catch` belongs **inside** the `flatMapLatest`, not outside — you want to recover the inner Observable so the outer remains healthy.

### "`retry()` saturates the network"

Always bound. See `retry(when:)` above.

### "Driver crashes on conversion"

`asDriver()` requires either `onErrorJustReturn:` (constant fallback) or `onErrorRecover:` (Observable fallback) for any source that can error.

```swift
// ❌
api.fetchUser().asDriver()                                  // compile error

// ✅
api.fetchUser().asDriver(onErrorJustReturn: .placeholder)
api.fetchUser().asDriver(onErrorRecover: { _ in .never() })
api.fetchUser().asDriver(onErrorDriveWith: .empty())
```

### "Errors silently disappear"

```swift
// ❌ bind(onNext:) only handles .next; .error is logged in debug, swallowed in release
api.fetch()
    .bind(onNext: { use($0) })
    .disposed(by: bag)
```

```swift
// ✅
api.fetch()
    .subscribe(onNext: { use($0) },
               onError: { handle($0) })
    .disposed(by: bag)
```

For UI bindings via `bind(to:)` to a Subject/Relay this is enforced by the type — relays can't accept errors. For freeform `bind(onNext:)`, take responsibility for the error case.

## Cross-references

- All recovery operators in catalog form → `operators.md` (Error)
- Why `Driver`/`Signal` are guaranteed error-free → `traits.md`
- Capstone validation example using `catchAndReturn` + `flatMapLatest` → `rxcocoa-bindings.md`
- Subject vs Relay choice (Relay = no terminal events) → `subjects-and-relays.md`
- Anti-patterns: unbounded `retry()`, missing `catch` inside `flatMapLatest`, swallowing errors → `anti-patterns.md`
