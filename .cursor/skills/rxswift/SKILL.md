---
name: rxswift
description: Use when writing, reviewing, or debugging RxSwift / RxCocoa / RxRelay code in iOS projects. Covers Observables, Subjects, Relays, Schedulers, operators, Traits (Single/Maybe/Completable/Driver/Signal), UIKit bindings, MVVM Input/Output and ReactorKit architectures, memory management with DisposeBag, testing with RxTest, and Swift Concurrency interop.
version: 1.0.0
---

# RxSwift Skill

Expert guidance on **RxSwift 6.x** and its companion libraries **RxCocoa** and **RxRelay** for iOS development.

Targets real-world work: designing streams that don't leak, picking the correct `flatMap` variant, binding UIKit safely on the main thread, structuring testable ViewModels, and bridging into `async/await` when needed — without dumping the entire RxSwift documentation into context.

## When to use this skill

Activate when you see any of:

- **Imports**: `import RxSwift`, `import RxCocoa`, `import RxRelay`, `import RxTest`, `import RxBlocking`, `import ReactorKit`
- **Symbols**: `Observable<`, `DisposeBag`, `BehaviorRelay`, `PublishSubject`, `Driver<`, `Signal<`, `.rx.`, `bind(to:)`, `drive(`, `disposed(by:)`, `Reactor`, `Action`, `Mutation`, `State`
- **Dependency files**: `Podfile` mentioning `RxSwift`/`RxCocoa`/`RxRelay`; `Package.swift` with `ReactiveX/RxSwift`; `Cartfile` with `ReactiveX/RxSwift`
- **User asks**: "why does this stream fire twice", "memory leak in my subscription", "how do I test this ViewModel", "should I use Subject or Relay", "convert this Observable to async/await"

## Skip if

- **Pure Combine** (`import Combine`, `AnyPublisher`, `@Published`) — different framework with different operator names. Don't translate Rx idioms blindly.
- **SwiftUI-only project with no Rx** — the user wants idiomatic SwiftUI, not Rx bridges.
- **`async/await` only, no Rx** — defer to a Swift Concurrency skill if available. Only engage `swift-concurrency-interop.md` when both worlds coexist.
- **RxJava / RxJS** questions — same family, different language semantics. Do not assume API parity.

## Core capabilities

- ✅ **Design Observable streams** with the correct hot/cold semantics and share strategy
- ✅ **Pick the right Subject vs Relay vs Trait** and the right operator for the job (especially the `flatMap` family and `debounce` vs `throttle`)
- ✅ **Manage subscriptions without leaks** using `DisposeBag` and weak captures
- ✅ **Build UIKit bindings** with `Driver`/`Signal` that are guaranteed main-thread and error-free
- ✅ **Structure and test ViewModels** with MVVM Input/Output or ReactorKit, using `RxTest`/`RxBlocking`

## Progressive disclosure

This file stays small on purpose. **Do not paste large reference content here.** Use the Decision Tree below to load only the `references/*.md` files relevant to the current task. Each reference is self-contained and ≤ 2.5k words.

If you're unsure where to start, read `references/_index.md` for a navigable problem router.

---

## Workflow Decision Tree

Match the user's question/code to the **scenario**, then load the listed reference(s). Most tasks need 1–2 references; complex reviews may need 3–4.

### Stream design and lifecycle

| Scenario | Read |
|---|---|
| Creating an Observable from scratch (`create`, `just`, `from`, `deferred`, …) | `observables.md` |
| Stream fires twice / once per subscriber when only one was expected | `observables.md` (Cold vs Hot, `share` variants) |
| Need to multicast: which `share`/`share(replay:scope:)`/`publish` to pick | `observables.md` (Multicasting) |
| Stream completes unexpectedly after one error | `error-handling.md` (terminal events) + `anti-patterns.md` (silent termination) |

### State, events, and writable sources

| Scenario | Read |
|---|---|
| Need a writable source the ViewModel can push into | `subjects-and-relays.md` |
| Choosing PublishSubject vs BehaviorSubject vs Replay vs Async | `subjects-and-relays.md` |
| Choosing Subject vs Relay (when do I want errors/completion?) | `subjects-and-relays.md` (decision table) |
| Want to expose state to View but not let it write back | `subjects-and-relays.md` + `traits.md` (Driver) |

### Operators

| Scenario | Read |
|---|---|
| Picking between `map`, `flatMap`, `flatMapLatest`, `flatMapFirst` | `operators.md` (flatMap family decision matrix) |
| Search box: `debounce` vs `throttle` | `operators.md` (debounce vs throttle table) |
| Combining streams: `combineLatest` vs `withLatestFrom` vs `zip` | `operators.md` (Combining) |
| Error recovery operators (`catch`, `retry`, `materialize`) | `operators.md` (Error) + `error-handling.md` |
| Building a custom operator | `operators.md` (advanced section) |

### Return types and UI streams

| Scenario | Read |
|---|---|
| What return type for a one-shot network call (`Single`, `Maybe`, `Completable`)? | `traits.md` |
| Output stream for a UIKit view (`Driver` vs `Signal` vs `BehaviorRelay`) | `traits.md` + `rxcocoa-bindings.md` |
| Converting Observable → Trait or vice versa | `traits.md` |

### Threading

| Scenario | Read |
|---|---|
| UI updated on background thread / "Main Thread Checker" warning | `schedulers.md` + `rxcocoa-bindings.md` (Driver/Signal guarantees) |
| `subscribe(on:)` vs `observe(on:)` placement question | `schedulers.md` |
| Heavy work blocking UI scroll | `schedulers.md` (Concurrent vs Serial) |

### Memory and disposal

| Scenario | Read |
|---|---|
| Suspected retain cycle / leak in a subscription | `disposal-and-memory.md` |
| `DisposeBag` in a `UITableViewCell` (cell reuse) | `disposal-and-memory.md` (per-cell pattern) |
| Forgot `disposed(by:)` / subscription disappears | `disposal-and-memory.md` |
| Nested `subscribe` inside `subscribe` | `disposal-and-memory.md` + `anti-patterns.md` + `operators.md` (flatMap family) |

### UIKit bindings (RxCocoa)

| Scenario | Read |
|---|---|
| Bind any control to/from a stream (`bind(to:)`, `drive(_:)`, `emit(to:)`) | `rxcocoa-bindings.md` |
| `ControlProperty` vs `ControlEvent` | `rxcocoa-bindings.md` |
| `UITableView` / `UICollectionView` with `rx.items` | `rxcocoa-bindings.md` |
| Custom `Binder` for a non-RxCocoa property | `rxcocoa-bindings.md` |
| `NotificationCenter.rx`, `URLSession.rx`, KVO | `rxcocoa-bindings.md` |

### Architecture

| Scenario | Read |
|---|---|
| Structuring a ViewModel (Input/Output struct or Reactor?) | `architecture.md` |
| Implementing the `Reactor` protocol (Action/Mutation/State) | `architecture.md` (ReactorKit section) |
| `@Pulse` for one-shot UI events from a Reactor | `architecture.md` |
| Choosing between MVVM I/O and ReactorKit for a new screen | `architecture.md` (selection guide) |

### Swift Concurrency interop

| Scenario | Read |
|---|---|
| `for try await x in observable.values` — caveats? | `swift-concurrency-interop.md` |
| `try await single.value` — when does it deadlock? | `swift-concurrency-interop.md` |
| Wrap an `async` function as `Single`/`Observable` | `swift-concurrency-interop.md` |
| Convert `AsyncStream` → `Observable` | `swift-concurrency-interop.md` |
| Cancellation: `Task` cancel vs `Disposable.dispose()` | `swift-concurrency-interop.md` (cancellation interplay) |

### Error handling

| Scenario | Read |
|---|---|
| Network call should retry with backoff | `error-handling.md` (`retry(when:)`) |
| Stream dies after one error — keep it alive | `error-handling.md` (`materialize`/`dematerialize` or `catchAndReturn`) |
| Designing an error-less output for the UI | `error-handling.md` + `traits.md` (Driver) |

### Testing

| Scenario | Read |
|---|---|
| Test a `debounce`d / `throttle`d stream | `testing.md` (TestScheduler virtual time) |
| Test a `Driver`/`Signal` output | `testing.md` |
| Test a `Reactor` | `testing.md` (Reactor stub) + `architecture.md` |
| Quick blocking assertion on a `Single` | `testing.md` (RxBlocking) |

### Code review and smell check

| Scenario | Read |
|---|---|
| "Review this Rx code for smells" | `anti-patterns.md` (always) + the most relevant topic file |
| Best-practice / convention check | `anti-patterns.md` + `disposal-and-memory.md` |

### Vocabulary

| Scenario | Read |
|---|---|
| Unfamiliar term ("what is a Binder / multicasting / pulse / VirtualTime?") | `glossary.md` |

---

## Quick verification checklist

Before giving advice, take ≤ 30 seconds to ground yourself in the project's reality:

1. **RxSwift version** — RxSwift 6 renamed `catchError` → `catch` (the latter is also a Swift keyword and needs backticks in some contexts), `catchErrorJustReturn` → `catchAndReturn`, and added `bind(with:onNext:)` for safe `self`-capturing binds. Check `Package.resolved` / `Podfile.lock` if uncertain. Default assumption: **6.x**.
2. **Dependency surface** — grep `Podfile`, `Package.swift`, `Cartfile` for `RxSwift`, `RxCocoa`, `RxRelay`, `RxTest`, `RxBlocking`, `ReactorKit`. Don't recommend RxRelay APIs if RxRelay isn't a dependency.
3. **Swift version** — RxSwift 6.x supports Swift 5.x and Swift 6 (with strict concurrency caveats). If the project enables strict concurrency (`-strict-concurrency=complete` or Swift 6 mode), expect `Sendable` warnings around closures captured in `subscribe`/`bind`. See `swift-concurrency-interop.md`.
4. **Architecture in use** — search for `protocol ViewModelType`, `struct Input`, `struct Output`, or `: Reactor`/`: View` (ReactorKit). Match advice to the existing pattern; don't impose a different one.
5. **Disposal pattern** — confirm the codebase uses a top-level `let disposeBag = DisposeBag()` per VC/cell, not ad-hoc local bags that go out of scope.

If any of these signals contradict the user's code, surface the contradiction before answering.

---

## How to answer

- **Lead with the answer**, then cite the operator/API by name with file path if it lives in the codebase.
- **Show Bad → Good** when correcting code. The Rx mental model is unforgiving; a snippet beats a paragraph.
- **Prefer composition over nested subscribe.** If a fix requires a nested `subscribe`, you almost certainly need `flatMap`/`flatMapLatest` instead — see `operators.md`.
- **Always weak-capture `self`** in `subscribe`/`bind` closures unless using `bind(with:onNext:)` or `subscribe(with:onNext:)`. See `disposal-and-memory.md`.
- **Don't silently change architecture.** If the screen is MVVM I/O, don't refactor it into ReactorKit unprompted.

---

## Sources

When in doubt, the upstream repos are authoritative:

- **RxSwift / RxCocoa / RxRelay / RxTest / RxBlocking** — <https://github.com/ReactiveX/RxSwift> (baseline: 6.10.x). The `Documentation/` folder contains canonical specs for Schedulers, Subjects, Traits, Hot vs Cold, Unit Tests, and Swift Concurrency interop.
- **ReactorKit** — <https://github.com/ReactorKit/ReactorKit> (Action / Mutation / State, `View` protocol, `@Pulse`, stub-based testing).
