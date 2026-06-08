# References Index

This is the navigation hub for the RxSwift skill's reference library. Each entry has a one-line purpose. Use the **Problem Router** below to jump from a symptom to the right file. If you're new to the skill, follow the **Reading order**.

## Files at a glance

| File | Purpose |
|---|---|
| [`glossary.md`](glossary.md) | One-paragraph definitions for every Rx/RxCocoa/RxRelay/ReactorKit term used in this skill. Zero code. Look here first when a word is unfamiliar. |
| [`observables.md`](observables.md) | `Observable<T>` lifecycle, creation operators, **Cold vs Hot**, multicasting (`share`, `share(replay:scope:)`, `publish`/`connect`). |
| [`subjects-and-relays.md`](subjects-and-relays.md) | The four Subjects (Publish/Behavior/Replay/Async) and the three Relays. Decision table for Subject vs Relay. |
| [`operators.md`](operators.md) | Operator catalog grouped by Transforming / Filtering / Combining / Error / Utility. Includes the **flatMap family decision matrix** and **debounce vs throttle** comparison. |
| [`traits.md`](traits.md) | `Single`, `Maybe`, `Completable` (RxSwift) and `Driver`, `Signal` (RxCocoa). When to use which, conversion APIs. |
| [`schedulers.md`](schedulers.md) | All scheduler types and the **`subscribe(on:)` vs `observe(on:)` placement** rules. The Rx threading story lives entirely here. |
| [`disposal-and-memory.md`](disposal-and-memory.md) | `DisposeBag` patterns, `[weak self]` vs `[unowned self]`, retain cycles, cell reuse, take-until. |
| [`error-handling.md`](error-handling.md) | The mental model that errors **terminate** streams, plus `catch`/`catchAndReturn`/`retry`/`retry(when:)`/`materialize`. |
| [`rxcocoa-bindings.md`](rxcocoa-bindings.md) | UIKit binding APIs (`bind(to:)`, `drive(_:)`, `emit(to:)`), `ControlProperty` vs `ControlEvent`, `rx.items`, custom `Binder`, `NotificationCenter.rx` / `URLSession.rx` / KVO. |
| [`architecture.md`](architecture.md) | **MVVM Input/Output** *and* **ReactorKit** patterns side-by-side, with a selection guide. |
| [`swift-concurrency-interop.md`](swift-concurrency-interop.md) | RxSwift 6.5+ ↔ `async`/`await` bridges. Cancellation interplay between `Task` and `Disposable`. |
| [`testing.md`](testing.md) | `RxTest` (TestScheduler, virtual time, `Recorded<Event>`) and `RxBlocking`. Testing Driver/Signal/Reactor. |
| [`anti-patterns.md`](anti-patterns.md) | Catalog of common mistakes as Bad/Good pairs. Read this on every code review. |

## Problem Router

Match the **symptom** the user is describing to a file. Most problems map cleanly to one or two references.

### "It fires the wrong number of times"

- Stream fires once per subscriber when only one was wanted → **Cold Observable** issue. Read `observables.md` (Cold vs Hot, then `share(replay: 1, scope: .whileConnected)`).
- Stream fires zero times after the first error → errors are **terminal**. Read `error-handling.md` and `subjects-and-relays.md` (Subject vs Relay decision).
- Stream emits **twice** per user action → check for duplicate `bind` / two `observe(on:)` hops / forgotten `distinctUntilChanged`. Read `anti-patterns.md` then `operators.md` (Filtering).

### "It crashes / leaks / doesn't deinit"

- "Main Thread Checker" warning → read `schedulers.md` (use `observe(on: MainScheduler.instance)`) and `rxcocoa-bindings.md` (prefer `Driver`).
- View controller doesn't deinit → retain cycle in `subscribe { self.… }`. Read `disposal-and-memory.md`.
- Crash in `UITableViewCell` after scrolling → cell-reuse disposal bug. Read `disposal-and-memory.md` (per-cell `disposeBag` + `prepareForReuse`).
- Subscription "disappears" / never fires → forgot `disposed(by:)` and the `Disposable` was deallocated immediately. Read `disposal-and-memory.md`.

### "I don't know which API to pick"

- Subject vs Relay → `subjects-and-relays.md` (decision table).
- `flatMap` vs `flatMapLatest` vs `flatMapFirst` → `operators.md` (flatMap family decision matrix).
- `debounce` vs `throttle` → `operators.md`.
- `combineLatest` vs `withLatestFrom` vs `zip` → `operators.md` (Combining).
- Return type for a network call → `traits.md` (`Single` for one shot, `Completable` for fire-and-forget).
- Output of a ViewModel → `traits.md` (Driver) + `architecture.md`.

### "How do I structure / test this?"

- "How should this ViewModel look?" → `architecture.md` (compare MVVM I/O vs ReactorKit, then commit to the project's existing pattern).
- "How do I test this stream?" → `testing.md` first; if the test involves `debounce`/`delay`, you must use `TestScheduler`.
- "How do I unit-test a Reactor?" → `testing.md` (Reactor stub) + `architecture.md`.

### "I want to use async/await"

- Read an Observable in a `Task` → `swift-concurrency-interop.md` (Observable.values caveat: source must complete).
- Wrap an async function as a Single → `swift-concurrency-interop.md` (`Single.create { try await … }`).
- Cancel a long Rx subscription from a `Task.cancel()` → `swift-concurrency-interop.md` (cancellation interplay).

### "It's working but feels wrong"

- Code review request → `anti-patterns.md` (always) plus the topic file matching the worst smell.
- "Is this idiomatic?" → `anti-patterns.md` + `disposal-and-memory.md` (composition over nested subscribe).

## Reading order for newcomers

If the user is learning RxSwift on this codebase, suggest this order. **You** (the agent) usually only need one or two of these per task — the reading order is for human onboarding, not for context loading.

1. `glossary.md` — orient on terminology.
2. `observables.md` — the foundation: streams, lifetimes, hot vs cold.
3. `subjects-and-relays.md` — bidirectional sources.
4. `operators.md` — the daily-driver toolkit.
5. `traits.md` — return types and UI streams.
6. `disposal-and-memory.md` — keeping subscriptions sane.
7. `schedulers.md` — threading.
8. `error-handling.md` — terminal-event mental model.
9. `rxcocoa-bindings.md` — connecting to UIKit.
10. `architecture.md` — MVVM I/O or ReactorKit.
11. `testing.md` — verification.
12. `anti-patterns.md` — what to avoid.
13. `swift-concurrency-interop.md` — bridging into async/await.

## When to load nothing

Some questions are answerable from the SKILL.md Decision Tree alone (e.g., "what's `bind(to:)`?" → one-line answer). Don't load a reference just to paraphrase it. Reach for references when you need **decision criteria, comparison tables, or worked code examples** that the SKILL.md routing already promised.
