# Glossary

Alphabetical, one-to-three-sentence definitions for every term used in this skill. Zero code. Look here first when a word is unfamiliar; jump to the linked file for depth.

---

**Action** (ReactorKit). A user-intent value emitted by the View into the Reactor (e.g., `.refresh`, `.tapFollow`). The Reactor's `mutate(action:)` turns each Action into zero or more Mutations. → `architecture.md`

**`accept(_:)`** (RxRelay). The only way to push a value into a Relay. Mirrors `Subject.onNext(_:)` but is incapable of emitting `.error` or `.completed`. → `subjects-and-relays.md`

**`asAsyncSequence` / `.values`** (RxSwift 6.5+). Bridge that exposes an Observable/Trait as a throwing or non-throwing `AsyncSequence`. Requires the source to terminate. → `swift-concurrency-interop.md`

**`AsyncSubject`**. Subject that emits only the **last** value, and only when the source completes. Rarely used in app code. → `subjects-and-relays.md`

**`BehaviorRelay`**. Relay that holds a current value, emits it to new subscribers, and exposes a synchronous `.value` reader. The workhorse for ViewModel state. → `subjects-and-relays.md`

**`BehaviorSubject`**. Subject variant that holds the latest value and replays it to new subscribers. Subject-side analogue of `BehaviorRelay`. → `subjects-and-relays.md`

**`bind(to:)` / `bind(onNext:)`**. RxCocoa verbs for subscribing an Observable to an `Observer`-conforming sink (typically a Subject, Relay, Binder, or `rx`-extension property). Intent-revealing alternative to `subscribe`. → `rxcocoa-bindings.md`

**`Binder<T>`**. RxCocoa adapter that turns a write closure into something an Observable can `bind(to:)`. Enforces a scheduler (defaults to `MainScheduler`) and traps source errors. → `rxcocoa-bindings.md`

**`catch` / `catchAndReturn`**. Recovery operators that swap a failed source for another Observable / a constant value. RxSwift 6 renames of `catchError` / `catchErrorJustReturn`. → `error-handling.md`

**Cold Observable**. Observable that starts producing values **per subscriber**, on subscription. Side effects (network calls, file reads) re-run for each subscriber. Contrast with Hot. → `observables.md`

**`Completable`**. Trait that emits only `.completed` or `.error` — no values. Use for fire-and-forget side effects (writes, deletes). → `traits.md`

**`combineLatest`**. Operator that emits whenever any source emits, using the latest value from each. All sources must emit at least once before the first combined value. → `operators.md`

**`ControlEvent<T>`** (RxCocoa). Trait for UIKit control events (`tap`, `editingDidEnd`). Behaves like a `PublishRelay`: no replay, never errors, MainScheduler. → `rxcocoa-bindings.md`

**`ControlProperty<T>`** (RxCocoa). Trait for UIKit control values (`text`, `isOn`). Two-way binding: replays the current value on subscribe, never errors, MainScheduler. → `rxcocoa-bindings.md`

**`Disposable`**. Returned by `subscribe(_:)`. Calling `dispose()` cancels the subscription and runs the cleanup closure passed to `Observable.create`. → `disposal-and-memory.md`

**`DisposeBag`**. Container that disposes its contents when itself deallocated. Standard tool for tying subscription lifetimes to an owner (VC, View, ViewModel). → `disposal-and-memory.md`

**`debounce`**. Operator that emits the **last** value after the source has been quiet for a given time window. Search-as-you-type's typical operator. → `operators.md`

**`distinctUntilChanged`**. Filter that drops consecutive duplicate values. Essential for state streams to avoid redundant UI updates. → `operators.md`

**`Driver<T>`** (RxCocoa). Trait for UI **state** streams: never errors, always MainScheduler, replays the latest value to new subscribers. Bound with `drive(_:)`. → `traits.md`

**`drive(_:)` / `drive(onNext:)`** (RxCocoa). Driver-specific binding verb. Mirrors `bind(to:)` but enforces the Driver contract on its caller. → `rxcocoa-bindings.md`

**`emit(to:)` / `emit(onNext:)`** (RxCocoa). Signal-specific binding verb. Mirrors `drive` but for one-shot events rather than state. → `rxcocoa-bindings.md`

**Event** (in `Recorded<Event<T>>`). The `.next(T)`, `.error(Error)`, or `.completed` enum used by `RxTest` to assert on the values an Observable produced. → `testing.md`

**`flatMap`**. Per outer value, subscribe to a new inner Observable and merge all inner emissions in parallel. → `operators.md`

**`flatMapLatest`**. Like `flatMap`, but **disposes the previous inner subscription** when a new outer value arrives. The right choice for cancellable async work driven by user input. → `operators.md`

**`flatMapFirst`**. Like `flatMap`, but **ignores new outer values while an inner is still in flight**. Use for tap-debouncing submit buttons. → `operators.md`

**Hot Observable**. Observable that produces values **regardless of subscribers**, sharing them. UI events, NotificationCenter, Subjects/Relays. Contrast with Cold. → `observables.md`

**`Infallible<T>`**. Trait that's like an Observable but provably never errors. Less common in app code than Driver/Signal but useful for expressing the contract on plain Observables. Indirectly referenced via `infallible.values`. → `swift-concurrency-interop.md`

**Input** (MVVM I/O). The struct of source streams the View pushes into a ViewModel (typically `Driver`/`Signal`). Half of the `transform(input:) -> Output` contract. → `architecture.md`

**`just(_:)`**. Creation operator that emits a single value, then completes. → `observables.md`

**KVO via Rx** (`rx.observe(_:_:)`). Reactive Key-Value Observing for `NSObject` subclasses. Useful for legacy ObjC integration. → `rxcocoa-bindings.md`

**`MainScheduler.instance` / `.asyncInstance`**. The thread on which UIKit operations are valid. `.instance` runs synchronously if already on main; `.asyncInstance` always dispatches asynchronously. → `schedulers.md`

**`materialize` / `dematerialize`**. Convert `Event<T>` into plain values (and back), letting a stream survive errors as observable data rather than terminal events. → `operators.md`, `error-handling.md`

**`Maybe<T>`**. Trait that emits at most one of `.success(T)`, `.completed`, or `.error`. Use for cache lookups where "nothing" is normal. → `traits.md`

**Multicasting**. Sharing one underlying subscription across many subscribers, instead of running the source's work per subscriber. Implemented via `share`, `share(replay:scope:)`, `publish`/`connect`, `multicast`. → `observables.md`

**Mutation** (ReactorKit). Internal value the Reactor produces from an Action, then applies via `reduce` to derive a new State. Decouples user intent from state transitions. → `architecture.md`

**`observe(on:)`**. Operator that controls the scheduler for **everything downstream of it**. The hop boundary. Place once, near the bottom (e.g., before binding to UI). → `schedulers.md`

**`Observable<T>`**. The core type: a sequence of zero or more values over time, terminated by `.completed` or `.error`. → `observables.md`

**`Observer`**. Anything that consumes an Observable (`.next`, `.error`, `.completed`). Subjects and Relays are Observers as well as Observables. → `subjects-and-relays.md`

**`OperationQueueScheduler`**. Scheduler that bridges to an `OperationQueue`. Useful for fine-grained concurrency limits or `Operation`-based legacy code. → `schedulers.md`

**Output** (MVVM I/O). The struct of derived state/event streams the ViewModel exposes to the View. Always `Driver`/`Signal` (or read-only Observable). → `architecture.md`

**`PublishRelay`**. Relay that emits only values arriving after subscription. Use for UI events. → `subjects-and-relays.md`

**`PublishSubject`**. Subject variant analogous to `PublishRelay` but capable of `.error`/`.completed`. → `subjects-and-relays.md`

**`@Pulse`** (ReactorKit). Property wrapper that makes a `State` field re-emit on every mutation, even if the value is unchanged. Use for one-shot UI events that live inside `State` (alerts, navigation). → `architecture.md`

**Reactor** (ReactorKit). The protocol that ties Action/Mutation/State into a unidirectional flow with `mutate(action:)` (side effects) and `reduce(state:mutation:)` (pure state derivation). → `architecture.md`

**`Recorded<Event<T>>`** (RxTest). Equatable wrapper for an event plus the virtual time it occurred. The currency of TestScheduler-based assertions. → `testing.md`

**`reduce(state:mutation:)`** (ReactorKit). Pure synchronous function that derives the next State from the current State and an incoming Mutation. Side effects forbidden. → `architecture.md`

**Relay** (RxRelay). A Subject that cannot emit `.error` or `.completed`. Push values via `accept(_:)`. Ideal for UI state and event streams. → `subjects-and-relays.md`

**`ReplayRelay`**. Relay variant that buffers the last N values for new subscribers. Bounded history. → `subjects-and-relays.md`

**`ReplaySubject`**. Subject variant that buffers the last N values for new subscribers. Subject-side analogue of `ReplayRelay`. → `subjects-and-relays.md`

**`retry` / `retry(when:)`**. Recovery operators that resubscribe on error. **Always bound** the count or delay; bare `retry()` loops forever. → `error-handling.md`

**`scan`**. Accumulator operator: each emission updates an accumulator state, which is itself emitted. Like `reduce`, but without requiring completion. → `operators.md`

**Scheduler**. Abstraction over a thread/queue. Operators take a scheduler to control where work runs. → `schedulers.md`

**`SerialDispatchQueueScheduler`**. Scheduler backed by a serial `DispatchQueue`. Preferred over the concurrent variant for sequential pipelines because RxSwift can apply optimizations. → `schedulers.md`

**`share` / `share(replay:scope:)`**. Multicasting operators. Default to `share(replay: 1, scope: .whileConnected)` for derived UI state. → `observables.md`

**`SharedSequence`**. Internal trait on which `Driver` and `Signal` are built. Guarantees: never errors, always MainScheduler, multicast. → `traits.md`

**`SharingScheduler.mock(scheduler:_:)`**. Test helper that swaps the Driver/Signal scheduler for the duration of a closure. Lets you test Driver-exposing ViewModels with a `TestScheduler`. → `testing.md`

**`Signal<T>`** (RxCocoa). Trait for UI **events** (no replay) — never errors, always MainScheduler, doesn't replay. Bound with `emit(to:)`. → `traits.md`

**`Single<T>`**. Trait that emits exactly one `.success(T)` or one `.failure(Error)`. The natural shape for HTTP requests. → `traits.md`

**State** (ReactorKit). A `struct` value-type that holds everything the View renders. Single source of truth for one screen. → `architecture.md`

**Subject**. An object that is both an Observable and an Observer — values pushed in are emitted out. Four variants: Publish, Behavior, Replay, Async. → `subjects-and-relays.md`

**`subscribe(on:)`**. Operator that controls the scheduler where the **source** of the chain runs (the `Observable.create` body). Set once near the top. → `schedulers.md`

**`subscribe(with:)` / `bind(with:onNext:)` / `drive(with:onNext:)` / `emit(with:onNext:)`**. RxSwift-6+ APIs that weakly capture the first argument and pass it back as `owner`. Replace the `[weak self] in guard let self else { return }` boilerplate. → `disposal-and-memory.md`

**`take(until:)`**. Operator that completes the stream when a notifier emits. Useful for "subscribe until this event happens." → `disposal-and-memory.md`

**Terminal event**. `.error` or `.completed` — both stop the subscription permanently. The mental model behind `error-handling.md` and the case for Relays over Subjects.

**`TestScheduler`** (RxTest). Virtual-time scheduler. Ticks are integers; nothing happens until `start()` is called. Makes time-based tests deterministic and fast. → `testing.md`

**`throttle(_, latest:)`**. Operator that emits at most one value per time window. `latest: false` emits the first; `latest: true` emits the first and the last in the window. → `operators.md`

**`toBlocking()`** (RxBlocking). Bridge that lets a test synchronously drain a small Observable into an array, single value, or materialized result. → `testing.md`

**`transform(input:)`** (MVVM I/O). The pure function turning an `Input` struct of source streams into an `Output` struct of derived ones. → `architecture.md`

**`transform(action:/mutation:/state:)`** (ReactorKit). Three optional hook methods on `Reactor` that intercept and merge global streams into the per-Reactor flow. → `architecture.md`

**Trait**. A specialized Observable wrapper with a narrower contract (Single, Maybe, Completable, Driver, Signal, Infallible). Makes intent type-checked. → `traits.md`

**`URLSession.rx`**. Reactive extensions wrapping `URLSession` data tasks as Observables. Convenience for prototypes; production code typically wraps a network client into a `Single`. → `rxcocoa-bindings.md`

**`ViewModelType`** (MVVM I/O). The conventional protocol with associated `Input`/`Output` types and a `transform(input:) -> Output` method. Not part of RxSwift; a community convention. → `architecture.md`

**Virtual time**. The time used by `TestScheduler` — integer ticks, advanced explicitly via `scheduler.start()`. Lets tests assert on debounce/throttle/delay deterministically. → `testing.md`

**`withLatestFrom(_:)`**. Operator that samples one or more sources at the moment the trigger emits. The form-submit pattern: tap fires the rate, form state contributes the values. → `operators.md`

**`zip`**. Operator that pairs values **by position** across sources, emitting when all sources have produced their Nth value. → `operators.md`

---

For deeper treatment of any term, follow the cross-reference. The skill's [`_index.md`](_index.md) maps symptoms to files when you don't know which term applies.
