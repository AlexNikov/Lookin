# Observables

`Observable<T>` is the heart of RxSwift: a sequence of zero or more values over time, terminated by either `.completed` or `.error`. This file covers the **lifecycle**, the **creation operators**, the **Cold vs Hot** distinction (the single most-misunderstood concept in Rx), and **multicasting** to share work across subscribers.

> Read this when: building an Observable from scratch, debugging "fires twice", picking a `share` variant, or explaining stream semantics.

## The grammar

Every Observable obeys this regular grammar:

```
next* (error | completed)?
```

- Zero or more `.next(Element)` events.
- Optionally terminated by **either** `.error(Error)` or `.completed`.
- After termination, **no further events are delivered**, ever. The subscription is over.

This terminal-once rule explains many surprises: a single error from a network call kills the stream, and reusing a "dead" Observable produces nothing. See `error-handling.md` for designs that survive errors.

## Creation operators

```swift
// Static, finite values
Observable.just(42)                    // emits 42, then .completed
Observable.of(1, 2, 3)                 // emits 1, 2, 3, then .completed
Observable.from([1, 2, 3])             // same, from a Sequence
Observable<Int>.empty()                // immediately .completed
Observable<Int>.never()                // never emits, never terminates (testing only)
Observable<Int>.error(MyError.boom)    // immediately .error

// Lazy / per-subscription
Observable.deferred {                  // factory runs on every subscribe
    Observable.just(Date())
}

// Time-based
Observable<Int>.interval(.seconds(1),
                         scheduler: MainScheduler.instance)
Observable<Int>.timer(.seconds(2),
                      scheduler: MainScheduler.instance)

// Custom — the escape hatch
Observable<Data>.create { observer in
    let task = URLSession.shared.dataTask(with: url) { data, _, error in
        if let error { observer.onError(error); return }
        observer.onNext(data ?? Data())
        observer.onCompleted()
    }
    task.resume()
    return Disposables.create { task.cancel() }   // ← cleanup on dispose
}
```

The `Disposables.create { … }` returned from `create` runs when the subscription is disposed — **this is where you cancel the underlying work** (network task, timer, observer registration). Forgetting it is a leak; see `disposal-and-memory.md`.

### `just` vs `deferred`

```swift
let now1 = Observable.just(Date())          // captured once at construction
let now2 = Observable.deferred { Observable.just(Date()) }  // captured per subscription
```

If you need a fresh value (current date, randomized seed, freshly-instantiated dependency) at subscribe time, use `deferred`. Otherwise prefer `just`.

## The subscription lifecycle

```swift
let subscription = observable.subscribe(
    onNext:      { value in print("next:", value) },
    onError:     { error in print("error:", error) },
    onCompleted: { print("done") },
    onDisposed:  { print("disposed") }
)
// later, somewhere:
subscription.dispose()
```

Subscribing **starts** the work for a Cold Observable. Disposing **stops** it (via the cleanup closure passed to `Observable.create`). Most application code uses `disposed(by: disposeBag)` instead of holding the `Disposable` manually — see `disposal-and-memory.md`.

RxSwift 6 also offers `subscribe(with:)` and `bind(with:)` to capture `self` weakly without writing `[weak self] in guard let self else { return … }`:

```swift
observable.subscribe(with: self) { owner, value in
    owner.handle(value)        // `owner` is `self`, weakly captured
}
```

## Cold vs Hot — the most important distinction

A **Cold** Observable starts producing values **per subscriber**, on subscription. A **Hot** Observable produces values **regardless of subscribers** and shares them.

| | Cold | Hot |
|---|---|---|
| When does work start? | On each `subscribe` | Independently of subscriptions |
| New subscriber gets… | Its own pipeline from the start | Whatever is happening **right now** |
| Examples | `Observable.create { … }` (network call, `URLSession`), `just`, `from`, most "factory" Observables | `UIControl.rx.tap`, `NotificationCenter.rx`, mouse/keyboard streams, Subjects, Relays |
| State | Usually stateless | Usually stateful |
| Side-effect risk | Easy: side effects fire **per subscriber** | Easy: late subscribers miss past events |

### The classic "fires twice" bug

```swift
// ❌ Cold Observable subscribed twice → request fires twice
let user = api.fetchUser(id: 1)        // returns Observable<User>

user.subscribe(onNext: { print("Header:", $0) }).disposed(by: bag)
user.subscribe(onNext: { print("Footer:", $0) }).disposed(by: bag)
// Network: 2 requests
```

Fix by multicasting — make the stream Hot:

```swift
// ✅ One request, two subscribers
let user = api.fetchUser(id: 1)
    .share(replay: 1, scope: .whileConnected)

user.subscribe(onNext: { print("Header:", $0) }).disposed(by: bag)
user.subscribe(onNext: { print("Footer:", $0) }).disposed(by: bag)
// Network: 1 request
```

If you control the API, returning a `Single` (see `traits.md`) and converting once at the call site is also fine — but the second subscriber on a `Single` will still re-fire.

## Multicasting: which `share` to use

`share(replay:scope:)` covers ~95% of real-world needs.

```swift
.share()                                   // = .share(replay: 0, scope: .whileConnected)
.share(replay: 1, scope: .whileConnected)  // most common: cache last value, reset when no subscribers
.share(replay: 1, scope: .forever)         // cache last value forever
```

| Variant | When the cached buffer resets | Use case |
|---|---|---|
| `.share()` | n/a (no buffer) | Hot fan-out of an event stream that has no meaningful "current value" |
| `.share(replay: 1, scope: .whileConnected)` | When the last subscriber disposes | UI state derived from a network call; late subscribers should still see the value |
| `.share(replay: N, scope: .whileConnected)` | When the last subscriber disposes | History/log feeds where late subscribers want the last N entries |
| `.share(replay: 1, scope: .forever)` | Never (until the source completes) | Singleton-like state that should survive zero-subscriber periods (rare; usually you want a `BehaviorRelay`) |

**Picking `whileConnected` vs `forever`:**

- `.whileConnected`: when subscribers drop to zero, the cached value is **discarded**, and the **next subscription re-runs the source**. This is what you want for screens that come and go.
- `.forever`: cached value lives until the underlying Observable completes. Be careful — this can hold references and prevent deinit.

If you need a value-holding source that you can also `accept(_:)` into, you probably want **`BehaviorRelay`** instead of `share(replay: 1, …)`. See `subjects-and-relays.md`.

### Lower-level multicasting

`publish()` + `connect()` give explicit control:

```swift
let connectable = source.publish()      // returns ConnectableObservable<T>
let s1 = connectable.subscribe(…)
let s2 = connectable.subscribe(…)
let connection = connectable.connect()  // ← work starts here, after both subscribed
```

Reach for `publish`/`connect` only when timing of the first subscription matters. In app code, `share(replay:scope:)` is almost always what you want.

## Worked example: reactive values

A small example showing why "value over time" beats imperative reassignment. Adapted from the RxSwift `Documentation/Examples.md`.

```swift
// Imperative:
var a = 1
var b = 2
var c = a + b      // c == 3
a = 10
print(c)           // still 3, c is stale

// Reactive:
let a = BehaviorRelay(value: 1)
let b = BehaviorRelay(value: 2)
let c = Observable.combineLatest(a, b) { $0 + $1 }   // recomputes on every change

c.subscribe(onNext: { print("c =", $0) })
    .disposed(by: bag)
// c = 3
a.accept(10)
// c = 12
```

`c` becomes a **derived** stream that updates whenever either source changes — no manual recomputation, no stale state. This is the core proposition of Rx.

## Common pitfalls (cross-references)

- Forgetting `disposed(by:)` → `disposal-and-memory.md`
- Confusing `subscribe(on:)` with `observe(on:)` → `schedulers.md`
- Subscribing inside a subscribe → `operators.md` (use `flatMap`/`flatMapLatest`)
- Stream "dies" after one error → `error-handling.md` and `subjects-and-relays.md` (Relay vs Subject)
- Driving UI off a Cold Observable → `traits.md` (use Driver) and `rxcocoa-bindings.md`
