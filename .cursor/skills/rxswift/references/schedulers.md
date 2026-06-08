# Schedulers

A `Scheduler` is RxSwift's threading abstraction. It decides **on what queue/thread an operator runs**. The Rx threading story is unusually clean: everything flows through Schedulers — no `DispatchQueue.async` sprinkled inside `subscribe` blocks, no manual `OperationQueue` plumbing. Two operators (`subscribe(on:)` and `observe(on:)`) control the entire pipeline.

> Read this when: UI updates from a background thread, "Main Thread Checker" warnings, scroll jank, deciding `subscribe(on:)` vs `observe(on:)`, or just picking a scheduler.

## Scheduler types

### `MainScheduler`

```swift
MainScheduler.instance         // schedules synchronously if already on main; else async
MainScheduler.asyncInstance    // always asynchronous
```

`MainScheduler.instance` performs an **optimization**: if you're already on the main thread, the work runs synchronously without a `DispatchQueue.main.async` hop. Use this everywhere except inside `bind` / `drive` chains where re-entrancy matters — in those rare cases use `.asyncInstance`.

**Use for**: every UI-side `observe(on:)`. Driver/Signal already enforce this — see `traits.md`.

### `SerialDispatchQueueScheduler`

```swift
SerialDispatchQueueScheduler(qos: .userInitiated)
SerialDispatchQueueScheduler(queue: customSerialQueue, internalSerialQueueName: "io.app.serial")
```

Wraps a serial `DispatchQueue`. RxSwift can apply optimizations on serial schedulers (e.g., `observe(on:)` may avoid extra context switches), so prefer this over `ConcurrentDispatchQueueScheduler` when ordering matters.

**Use for**: chained background work where each step depends on the previous one (most common case).

### `ConcurrentDispatchQueueScheduler`

```swift
ConcurrentDispatchQueueScheduler(qos: .background)
```

Wraps a concurrent queue. Multiple emissions can run in parallel.

**Use for**: parallel independent work (e.g., fanning out multiple unrelated requests). For sequential pipelines, **prefer the serial scheduler** — concurrent schedulers add synchronization overhead.

### `OperationQueueScheduler`

```swift
let queue = OperationQueue()
queue.maxConcurrentOperationCount = 4
let scheduler = OperationQueueScheduler(operationQueue: queue)
```

Bridges to `OperationQueue`. Mostly useful when integrating with existing `Operation`-based code or when you need fine-grained concurrency limits.

### `ImmediateSchedulerType` family

```swift
ImmediateScheduler                  // runs work synchronously, immediately
CurrentThreadScheduler.instance     // trampoline — recursive scheduling on same thread (default)
```

You almost never specify these explicitly. `CurrentThreadScheduler` is the default for unscheduled operators; `ImmediateScheduler` is mostly for tests or building custom operators.

## `subscribe(on:)` vs `observe(on:)`

The single most-asked threading question. The answer is captured by **placement**.

```
                       subscribe(on:) →  affects setup direction
                                          (where Observable.create's body runs)
        ┌──────────┐                    ┌────────────┐                    ┌──────────┐
Source ─┤ create() ├─── operators ──────┤ map / filter├─── operators ─────┤subscribe │
        └──────────┘                    └────────────┘                    └──────────┘
                                          observe(on:) →  affects downstream direction
                                                          (where this and following operators run)
```

### Mental model

- **`subscribe(on:)`** controls the thread where the **source** of the chain runs (the `Observable.create` body, the network call, etc.). It's set **once**, near the top of the chain. **Order-independent** — only one matters; later `subscribe(on:)` calls are ignored.
- **`observe(on:)`** controls the thread for **everything downstream of it**. It's the boundary marker. Use multiple `observe(on:)` calls if you want different sections of the pipeline on different threads.

### Typical pattern

```swift
api.fetchHeavyData()                                     // ← runs wherever the source decides
    .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .userInitiated))  // ← move source to background
    .map { decode($0) }                                  // ← also background (downstream of subscribe(on:))
    .observe(on: MainScheduler.instance)                 // ← hop to main
    .bind(to: titleLabel.rx.text)                        // ← UI on main, safe
    .disposed(by: bag)
```

### Common mistakes

```swift
// ❌ subscribe(on:) at the bottom: usually a no-op, the source already chose its thread
api.fetch()
    .observe(on: MainScheduler.instance)
    .subscribe(on: backgroundScheduler)        // pointless here
    .subscribe(…)
```

```swift
// ❌ Multiple observe(on:) hops with no purpose
source
    .observe(on: schedulerA)
    .map { … }
    .observe(on: schedulerB)
    .map { … }
    .observe(on: MainScheduler.instance)
    .bind(…)
```

Each `observe(on:)` is a context switch. Two or three are fine; a chain of five usually means the design has unclear thread responsibility.

```swift
// ❌ Forgot to hop back to main before binding to UI
api.fetch()
    .subscribe(on: backgroundScheduler)
    .bind(to: titleLabel.rx.text)              // 💥 Main Thread Checker
```

```swift
// ✅ Always observe(on: MainScheduler.instance) before UI bindings
api.fetch()
    .subscribe(on: backgroundScheduler)
    .observe(on: MainScheduler.instance)
    .bind(to: titleLabel.rx.text)
```

Or, simpler — convert to a Driver, which guarantees the main hop:

```swift
api.fetch()
    .asDriver(onErrorJustReturn: .placeholder)
    .drive(titleLabel.rx.text)
    .disposed(by: bag)
```

## Placement rules

1. **`subscribe(on:)` near the top, once.** If you find yourself wanting a second one, you actually want `observe(on:)`.
2. **`observe(on: MainScheduler.instance)` immediately before any UIKit binding.** Driver/Signal/`bind(to:)` on RxCocoa-aware controls already do this — but explicit `observe(on:)` is the safe default for plain Observables.
3. **Most operators don't care about scheduler.** `map`, `filter`, `scan` run wherever the upstream emission runs. Don't `observe(on:)` between every operator.
4. **Time-based operators take an explicit scheduler.** `debounce`, `throttle`, `delay`, `timeout`, `interval` all need one. Pass `MainScheduler.instance` for UI-driven streams, a background scheduler for background work.

## Picking a scheduler

| Need | Scheduler |
|---|---|
| Touch UIKit | `MainScheduler.instance` |
| Time-based operator on a UI stream | `MainScheduler.instance` |
| Background work, sequential | `SerialDispatchQueueScheduler(qos: …)` |
| Background work, parallel fan-out | `ConcurrentDispatchQueueScheduler(qos: …)` |
| Bound to existing `OperationQueue` | `OperationQueueScheduler` |
| Test (virtual time) | `TestScheduler` (see `testing.md`) |

## QoS

Pass the right Quality-of-Service:

| QoS | Use for |
|---|---|
| `.userInteractive` | Reserved for the system; rarely used in app Rx code |
| `.userInitiated` | User is waiting on a result (network, search) |
| `.default` | Generic background |
| `.utility` | Long-running, user-visible (uploads, sync) |
| `.background` | Maintenance, cleanup |

When unsure, `.userInitiated` for foreground network calls and `.utility` for syncs.

## Synchronizing Hot Observables

If you have a Hot source (a Subject/Relay) that's pushed into from multiple threads, **`observe(on:)` does not protect the producer side** — it only schedules the consumers. Push into the Subject from the appropriate thread to begin with, or wrap the Subject's `accept`/`onNext` in a serial queue.

`SerializedSubject` doesn't exist as a stock type — for cross-thread producers, the common solution is a serial queue around the relay's `accept`.

## Cross-references

- Driver / Signal main-thread guarantees → `traits.md`
- Why `bind`/`drive` is safer than manual `subscribe` for UI → `rxcocoa-bindings.md`
- Time-based operators (`debounce`, `throttle`, `delay`, `timeout`) → `operators.md`
- TestScheduler for virtual-time testing → `testing.md`
- Anti-patterns: too many `observe(on:)` hops, missing hop before UI → `anti-patterns.md`
