# Swift Concurrency Interop

RxSwift 6.5+ ships first-class bridges between Observable streams and Swift's `async`/`await` model. This file covers the **interop** APIs — `observable.values`, `single.value`, `Single.create { try await … }`, and the cancellation interplay between `Task` and `Disposable`. **This is not a migration guide.** It's for projects that keep RxSwift as the backbone but selectively call into async APIs (or call Rx code from a `Task { }`).

> Read this when: bridging an Observable into a `Task`, calling an async function from a Reactor's `mutate`, wrapping `AsyncStream` as `Observable`, or hitting cancellation ambiguity between Rx and Swift Concurrency.

## API surface

### Observable → AsyncSequence (throwing)

```swift
let observable: Observable<Int> = …
do {
    for try await value in observable.values {
        print("got:", value)
    }
    print("stream completed")
} catch {
    print("stream errored:", error)
}
```

`observable.values` is a throwing `AsyncSequence`. The `for try await` loop:

- Yields each `.next(Int)` as a value.
- Throws on `.error(Error)`.
- Returns normally on `.completed`.

⚠️ **Critical caveat**: the source **must complete** (or error) for the awaiting `Task` to make forward progress past the loop. **Iterating an infinite Observable suspends the Task forever** — including never letting the Task be reaped on cancellation if cancellation isn't checked elsewhere.

```swift
// ❌ Hangs forever — UI events never complete
Task {
    for try await tap in button.rx.tap.asObservable().values {
        print("tap")
    }
}

// ✅ Bound the stream so completion is guaranteed
Task {
    for try await tap in button.rx.tap.asObservable().take(10).values {
        print("tap")
    }
}
```

### Trait → single await

```swift
let user = try await single.value          // T
let cached = try await maybe.value         // T?  (nil if Maybe completed empty)
try await completable.value                // Void
```

Trait `value` properties are async-throwing computed properties. Same caveat applies: `maybe`/`completable` must terminate.

`Single` always terminates by design (one success or one error), so `try await single.value` is the safest of the three.

### Infallible / Driver / Signal → AsyncSequence (non-throwing)

```swift
for await value in infallible.values { … }
for await value in driver.values { … }
for await value in signal.values { … }
```

These don't need `try` because the underlying Trait can't error. **Same termination caveat** — Driver/Signal usually don't complete, so guard with `take`/`take(until:)`.

### AsyncSequence → Observable

```swift
let stream: AsyncStream<Int> = …
let obs: Observable<Int> = stream.asObservable()
```

`AsyncStream` and other `AsyncSequence`s have an `asObservable()` extension. Iteration runs in a Task that the resulting Observable manages; disposing the Observable cancels the Task.

### Wrapping async functions as Traits

```swift
let single: Single<Data> = Single.create {
    try await api.fetchData(id: 42)        // any throwing async function
}

let maybe: Maybe<User> = Maybe.create {
    try await cache.user()                 // returns User? — nil ⇒ Maybe completes empty
}

let completable: Completable = Completable.create {
    try await storage.write(settings)
}
```

This `create` overload (RxSwift 6.5+) takes an `async throws` closure. Compare to the legacy callback form:

```swift
// Legacy form, still valid
Single.create { observer in
    let task = api.fetch { result in
        switch result {
        case .success(let v): observer(.success(v))
        case .failure(let e): observer(.failure(e))
        }
    }
    return Disposables.create { task.cancel() }
}
```

For brand-new code, the async-closure form is more concise. For existing callback APIs, the legacy form is still appropriate.

## Cancellation interplay

The interop layer wires cancellation **in both directions**, but with subtleties.

### `Task` cancellation → `Disposable.dispose()`

When a `Task` iterating over `observable.values` is cancelled:

1. The async iterator detects cancellation.
2. The bridge **disposes the underlying subscription**.
3. The `Disposables.create { … }` cleanup (network task cancel, timer invalidate, etc.) runs.

```swift
let task = Task {
    for try await value in api.fetchUserStream().values {
        print(value)
    }
}
// Later:
task.cancel()                  // Disposable disposed; underlying network call cancelled
```

This is the well-behaved direction.

### `Disposable.dispose()` → async closure

When you wrap an async function in `Single.create { try await … }` and dispose the returned subscription mid-flight, the bridge **does not magically cancel the running async function**. You must either:

- Use cancellable async APIs (`URLSession.shared.data(for:)` checks `Task.isCancelled` cooperatively), or
- Check `Task.isCancelled` inside the closure yourself.

```swift
// ✅ Cancellation-aware async work
let single = Single.create {
    try await withTaskCancellationHandler {
        try await longRunningWork()
    } onCancel: {
        cancelTokenStore.cancelInFlight()
    }
}
```

Inside the wrapped closure, the bridge runs the work in a child Task; cancelling the outer Disposable cancels that child Task, but **only cooperative cancellation** (i.e., async functions that check `Task.isCancelled` or use cancellable APIs) actually stops.

### `Task` cancellation → `Single.value` await

```swift
let task = Task {
    do {
        let user = try await single.value
        use(user)
    } catch is CancellationError {
        // Task was cancelled while awaiting
    }
}
```

Cancelling the Task cancels the underlying subscription and throws `CancellationError` from the await.

## `Sendable` and `@MainActor`

With Swift 6 strict concurrency, the boundary between Rx and async/await sometimes surfaces `Sendable` warnings.

### Capturing `self` inside `Single.create` async closure

```swift
final class ProfileViewModel {
    func load() -> Single<User> {
        Single.create {
            try await self.api.fetchUser()    // ⚠️ self captured into a Sendable context
        }
    }
}
```

If `ProfileViewModel` isn't `Sendable`, the compiler warns. Fixes:

- Make the type `Sendable` (preferred when possible).
- Capture only the `Sendable` dependencies needed:

```swift
func load() -> Single<User> {
    let api = self.api
    return Single.create {
        try await api.fetchUser()
    }
}
```

### `@MainActor` types crossing into Rx pipelines

A `@MainActor` ViewModel exposing `Driver<State>` is fine — Driver is already `MainScheduler`-bound. But if the underlying source crosses actor boundaries (e.g., a background actor's `async` method), wrap with `Single.create { await mainActorBoundCall() }` and let the bridge handle the hop.

### `Reactor.mutate(action:)` calling async

```swift
func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case .refresh:
        return Single.create { try await self.api.fetch() }
            .map(Mutation.setUser)
            .catch { .just(.setError($0.localizedDescription)) }
            .asObservable()
    }
}
```

Common pattern in mixed codebases. Keep `mutate` returning `Observable<Mutation>` so the rest of the Reactor pipeline is unchanged.

## Decision: `.values` vs full conversion vs leaving as Observable

| You want to… | Do this |
|---|---|
| Pull a single result from RxSwift land into an async function | `try await single.value` |
| Iterate a finite Rx stream in a `Task` | `for try await x in observable.take(N).values` |
| Expose an existing AsyncStream/AsyncSequence to Rx-based code | `stream.asObservable()` |
| Run an async function as one Reactor mutation | `Single.create { try await … }.map(Mutation.…)` |
| Subscribe to an infinite Rx stream from async code | **Don't** — use `subscribe(_:)` and route via a Subject if needed |

## Anti-patterns

### `for try await` over an infinite Observable

```swift
// ❌ Hangs the Task forever
Task {
    for try await event in heartbeatRelay.asObservable().values { … }
}
```

```swift
// ✅ Bound it
Task {
    for try await event in heartbeatRelay.asObservable().take(until: closeRelay).values { … }
}
```

### Using `asObservable` on an `AsyncStream` you didn't bound

If the AsyncStream never finishes, the resulting Observable never completes — the same disposal/leak considerations as any infinite Hot Observable apply.

### Discarding the `Task`

```swift
// ❌ Task is fire-and-forget; no way to cancel
Task { for try await x in observable.values { … } }

// ✅ Hold the Task to cancel it later (or use a structured Task in a parent)
let task = Task { for try await x in observable.values { … } }
// later: task.cancel()
```

### Mixing `disposed(by: bag)` and `Task` for the same subscription

Pick one ownership model per subscription. Either the Disposable is in a bag and you don't await it, or you await it inside a Task and let Task cancellation dispose it. Mixing leads to double-cancellation noise and confusing teardown order.

## Cross-references

- Trait return types (`Single`/`Maybe`/`Completable`) → `traits.md`
- Disposal mechanics (which the interop layer hooks into) → `disposal-and-memory.md`
- Schedulers (the bridge defers thread management to them) → `schedulers.md`
- Reactor `mutate` returning Observable<Mutation> from async work → `architecture.md`
