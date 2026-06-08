# Operators

The operator catalog. Operators are the daily-driver toolkit: ~30 of them cover ~95% of real-world Rx code. This file groups them by purpose and includes two reference tables you'll come back to often: the **flatMap family decision matrix** and **debounce vs throttle**.

> Read this when: choosing between operators, debugging a stream that emits the wrong shape of data, or composing a non-trivial pipeline.

## Operator design principles

Before reaching for a custom operator, try these in order:

1. **Compose built-in operators first.** Most "I need a custom thing" turns out to be `map` + `filter` + `scan`.
2. **Extract recurring chains as `extension` methods on `ObservableType`** (convenience operators) before writing genuinely-new operators with `Observable.create`.
3. **Only handcraft a custom operator** when (a) the chain repeats in many places and (b) the semantics aren't expressible as a composition.
4. **Pure functions over side effects.** Operators should transform values, not mutate external state. Side effects belong in `subscribe(onNext:)` or, very rarely, `do(onNext:)`.

## Transforming

### `map`

```swift
input.map { $0.uppercased() }            // (T) -> U, synchronous
```

The most-used operator. Pure synchronous transformation.

### `compactMap`

```swift
input.compactMap { Int($0) }             // (T) -> U?, drops nils
```

Equivalent to `map { … }.filter { $0 != nil }.map { $0! }` but type-safe and idiomatic.

### `flatMap`

```swift
queries.flatMap { query in api.search(query) }   // (T) -> Observable<U>
```

For each outer value, subscribe to a new inner Observable and merge all inner emissions. **Inner subscriptions run in parallel** and stay alive until each completes.

### `flatMapLatest`

```swift
queries.flatMapLatest { query in api.search(query) }
```

Same shape as `flatMap`, but **disposes the previous inner subscription** the moment a new outer value arrives. The right choice for search-as-you-type, "tap to load latest", and any case where stale inner work should be cancelled.

### `flatMapFirst`

```swift
button.rx.tap.flatMapFirst { _ in api.submit() }
```

Ignores **new outer values while an inner is still in flight**. Right choice for "tap throttling": a second tap is dropped until the first request finishes.

### `scan`

```swift
input.scan(0) { acc, value in acc + value }      // running total
```

Accumulator without a terminating boundary (unlike `reduce`, which requires completion). The functional way to "remember the last N things" or build derived state.

### Decision matrix: flatMap family

| Operator | Inner concurrency | Behaviour on new outer value while inner running | Typical use |
|---|---|---|---|
| `flatMap` | Many in parallel | Start another in parallel | Independent fan-out (e.g., per-id detail fetches) |
| `flatMapLatest` | One at a time | **Cancel** previous, start new | Search-as-you-type, "load latest" |
| `flatMapFirst` | One at a time | **Ignore** new outer values until inner completes | Tap-debouncing for submit buttons |
| `concatMap` (= `flatMap(maxConcurrent: 1)`) | One at a time | **Queue** new outer values until inner completes | Sequential ordered work |

If you find yourself second-guessing, default to `flatMapLatest` for UI-driven outer streams and `flatMap` for collection iteration.

## Filtering

### `filter`

```swift
input.filter { $0 > 0 }
```

### `distinctUntilChanged`

```swift
state.distinctUntilChanged()                                   // requires Equatable
state.distinctUntilChanged { $0.id == $1.id }                  // custom comparator
state.distinctUntilChanged(\.id)                               // KeyPath
```

Indispensable for state streams to avoid redundant UI updates. Forgetting it is a common cause of "the cell flickers / animates twice."

### `take`, `skip`

```swift
input.take(3)                       // first 3
input.skip(1)                       // drop first
input.take(.seconds(5), scheduler: MainScheduler.instance)   // first 5s of values
```

### `debounce`

```swift
search.text.orEmpty
    .debounce(.milliseconds(300), scheduler: MainScheduler.instance)
```

Emit the **last** value once `300ms` have passed **without** any new value. Search-as-you-type's best friend.

### `throttle`

```swift
button.rx.tap
    .throttle(.milliseconds(500), latest: true, scheduler: MainScheduler.instance)
```

Emit at most one value per window. Two flavors via `latest:`: emit the **first** in the window (`latest: false`) or the **last** (`latest: true`).

### Decision: `debounce` vs `throttle`

| | `debounce(N)` | `throttle(N, latest: false)` | `throttle(N, latest: true)` |
|---|---|---|---|
| Emits the | last value after a quiet period | first value, then ignores for N | first value, then last in the window |
| Good for | search input (wait for typing to settle) | preventing double-tap on a button | sampling fast-moving values (scroll position) |
| Latency | always at least N | zero on the first event | first event immediate, follow-ups delayed by N |

Misusing `throttle` for search creates a request **on every keystroke** at the throttle interval, hammering the API. Misusing `debounce` for a tap means the user has to wait N before anything happens. Match the operator to the **user perception** you want.

## Combining

### `combineLatest`

```swift
Observable.combineLatest(name, age) { name, age in
    "\(name), \(age)"
}
```

Re-emits **whenever any source emits**, using the latest value from each. Each source must emit at least once before the first combined value appears.

### `withLatestFrom`

```swift
button.rx.tap.withLatestFrom(formState)
```

Sample `formState`'s latest value **only when** the trigger emits. The trigger fires the rate; the sources contribute values. The form-submit pattern.

### `zip`

```swift
Observable.zip(first, second) { $0 + $1 }
```

Pair values **by position**: emits when **all** sources have produced their Nth value. Slowest source paces the stream. Good for joining parallel results that must arrive in lockstep.

### `merge`

```swift
Observable.merge(of: streamA, streamB)
```

Interleave events from multiple streams of the **same type**. Order: whoever emits first.

### `concat`

```swift
Observable.concat(first, second)
```

Subscribe to `second` **only when `first` completes**. Use for sequential work where the second stream depends on the first being finished but not on its values.

### `switchLatest`

```swift
let outer = PublishSubject<Observable<Int>>()
outer.switchLatest()                          // subscribes to the most recent inner
```

Same dynamics as `flatMapLatest`, but for an `Observable<Observable<T>>` you've already constructed.

### `startWith`

```swift
remote.startWith(.loading)
    .bind(to: state)
```

Prepend a synchronous initial value. Useful to seed UI state before async values arrive.

## Error operators

These coexist with `error-handling.md`. Use that file for **strategy** (when to recover, when to propagate); this section just lists the operators.

### `catch` / `catchAndReturn`

```swift
api.fetch()
    .catch { error in api.fetchFromCache() }       // recover with another Observable
    .catchAndReturn(.empty)                        // recover with a default value
```

**RxSwift 6 renamed:** `catchError` → `catch`, `catchErrorJustReturn` → `catchAndReturn`. If you see the old names, the codebase is on RxSwift 5.

### `retry`

```swift
api.fetch().retry(3)                                // retry up to 3 times on error
api.fetch().retry { errors in
    errors.enumerated()
        .flatMap { idx, _ in
            Observable<Int>.timer(.seconds(1 << idx),
                                  scheduler: MainScheduler.instance)
        }
}                                                   // exponential backoff
```

`retry()` with no argument retries **forever** — almost always a bug. Always pass a count or a delay strategy. See `error-handling.md`.

### `materialize` / `dematerialize`

```swift
source.materialize()                                // Observable<Event<T>>: never errors
    .filter { $0.element != nil }
    .dematerialize()                                // back to Observable<T>
```

Convert events into plain values so an error doesn't terminate the stream. Use for telemetry, "keep going on error" pipelines, and tests.

## Utility

### `do(onNext:)`, `do(onError:)`, …

```swift
api.fetch()
    .do(onNext:    { print("got", $0) },
        onError:   { print("err", $0) },
        onSubscribe: { print("subscribed") },
        onDispose: { print("disposed") })
    .subscribe(…)
```

For **observation only** — debug logs, analytics, light tracing. **Never put state mutation here.** State mutation belongs in `subscribe(onNext:)` or in a Reactor's `reduce`. A `do(onNext:)` that mutates is brittle (it runs per subscription, and reordering operators changes its position in the pipeline).

### `observe(on:)`, `subscribe(on:)`

Threading. See `schedulers.md` — placement matters enormously.

### `timeout`

```swift
api.fetch()
    .timeout(.seconds(10), scheduler: MainScheduler.instance)
```

Emit `RxError.timeout` if no value arrives within the window.

### `delay`

```swift
toast.delay(.seconds(2), scheduler: MainScheduler.instance)
```

Shifts every emission forward in time. Useful for animations and demos; rarely the right answer for production logic.

### `share` / `share(replay:scope:)`

Multicasting. See `observables.md`.

## Convenience operators (writing your own)

Extract recurring patterns to extensions on `ObservableType` (and `SharedSequenceConvertibleType` for Driver/Signal):

```swift
extension ObservableType where Element: OptionalType {
    func filterNil() -> Observable<Element.Wrapped> {
        compactMap { $0.value }
    }
}

extension ObservableType where Element == Bool {
    func not() -> Observable<Bool> { map(!) }
}
```

Resist publishing these as new "operators" until they've reproduced in 3+ files. Premature extension explosion makes a codebase opaque to newcomers.

## Anti-patterns (cross-reference)

- `subscribe` inside `subscribe` → use the flatMap family. See `disposal-and-memory.md`.
- `do(onNext:)` as a state-mutation dump → see `anti-patterns.md`.
- `flatMap` where `flatMapLatest` belongs (race conditions on search) → see `anti-patterns.md`.
- `retry()` with no bound → see `error-handling.md`.

## Cross-references

- Threading and `observe(on:)` placement → `schedulers.md`
- Error operators in context (when to recover) → `error-handling.md`
- Driver/Signal versions of these operators → `traits.md`
- Multicasting variants → `observables.md`
