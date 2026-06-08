# Testing

RxSwift provides two test libraries:

- **`RxTest`** — `TestScheduler` for **virtual time**, `Recorded<Event<T>>` for assertions, hot/cold Observable factories. The right tool for testing time-based operators (`debounce`, `throttle`, `delay`) and ViewModels.
- **`RxBlocking`** — `toBlocking()` for synchronous-style assertions on small Observables. The quickest way to write a one-liner test.

This file covers both, plus testing `Driver`/`Signal` (which need their own scheduler trick) and `ReactorKit` Reactors (which support a built-in stub).

> Read this when: writing unit tests for any Rx code, debugging a flaky time-based test, asserting on a ViewModel's outputs, or testing a Reactor.

## Setup

```swift
import XCTest
import RxSwift
import RxCocoa
import RxTest
import RxBlocking
@testable import MyApp
```

Add `RxTest` and `RxBlocking` as **test-only** dependencies in `Package.swift` / `Podfile`. Don't ship them in app targets.

## TestScheduler basics

```swift
final class CounterTests: XCTestCase {
    var scheduler: TestScheduler!
    var bag: DisposeBag!

    override func setUp() {
        super.setUp()
        scheduler = TestScheduler(initialClock: 0)
        bag = DisposeBag()
    }
}
```

`TestScheduler` runs in **virtual time**. Time is measured in integer ticks; nothing happens until you call `scheduler.start()`. This makes time-based tests deterministic and instant.

### Recording outputs

```swift
let observer = scheduler.createObserver(Int.self)

source.subscribe(observer).disposed(by: bag)

scheduler.start()

XCTAssertEqual(observer.events, [
    .next(200, 1),         // virtual time 200, value 1
    .next(300, 2),
    .completed(400)
])
```

`observer.events` is `[Recorded<Event<Int>>]`. `.next(time, value)`, `.completed(time)`, `.error(time, error)` are the three event constructors. `Recorded` is `Equatable` if the wrapped value is.

### Hot vs Cold Observables

```swift
// Hot: emits at the absolute virtual time given, regardless of subscription
let hot = scheduler.createHotObservable([
    .next(150, 1),
    .next(250, 2),
    .next(350, 3),
    .completed(400)
])

// Cold: emits relative to subscription time (default subscribe at 200)
let cold = scheduler.createColdObservable([
    .next(50, 1),    // emits at subscribeTime + 50
    .next(150, 2),
    .completed(200)
])
```

`scheduler.start()` defaults to subscribing at **time 200** and disposing at **time 1000**. Use `scheduler.start(disposed: 500) { observableUnderTest }` to customize.

### Time-based test (`debounce`)

```swift
func test_debounce_emitsLastValueAfterQuietPeriod() {
    let input = scheduler.createHotObservable([
        .next(100, "a"),
        .next(150, "b"),       // within debounce window, replaces "a"
        .next(400, "c"),       // separate burst
        .completed(500)
    ])

    let observer = scheduler.createObserver(String.self)

    input
        .debounce(.seconds(100), scheduler: scheduler)     // ← scheduler is TestScheduler
        .subscribe(observer)
        .disposed(by: bag)

    scheduler.start()

    XCTAssertEqual(observer.events, [
        .next(250, "b"),       // 150 + 100 quiet period
        .next(500, "c"),       // 400 + 100 quiet period
        .completed(500)
    ])
}
```

**Key**: pass the `TestScheduler` to every time-based operator under test (`debounce`, `throttle`, `delay`, `timeout`). They use the scheduler for their internal timers; with `MainScheduler`, your test is suddenly real-time and slow/flaky.

## Testing a ViewModel

The `transform(input:)` shape (see `architecture.md`) makes ViewModel tests straightforward.

```swift
func test_loginButton_enabledWhenBothFieldsFilled() {
    let viewModel = LoginViewModel(api: MockAuthAPI())
    let scheduler = TestScheduler(initialClock: 0)

    let username = scheduler.createHotObservable([
        .next(100, ""),
        .next(200, "user"),
        .next(300, "user")
    ])
    let password = scheduler.createHotObservable([
        .next(100, ""),
        .next(150, "pwd"),
        .next(250, "")
    ])

    let input = LoginViewModel.Input(
        username: username.asDriver(onErrorJustReturn: ""),
        password: password.asDriver(onErrorJustReturn: ""),
        loginTap: .never()
    )
    let output = viewModel.transform(input: input)

    let observer = scheduler.createObserver(Bool.self)
    output.isLoginEnabled.drive(observer).disposed(by: bag)

    scheduler.start()

    // The exact tick numbers depend on Driver's MainScheduler-based delivery —
    // see "Testing Driver/Signal" below for the workaround.
    XCTAssert(observer.events.contains(.next(any, true)))   // schematic
}
```

## Testing Driver and Signal

`Driver`/`Signal` always deliver on `MainScheduler.instance` — which is real-time and not under your `TestScheduler`'s control. Two strategies:

### Strategy 1: override at the SharedSequence level

```swift
SharingScheduler.mock(scheduler: scheduler) {
    // Inside this closure, Driver/Signal use `scheduler` instead of MainScheduler
    let output = viewModel.transform(input: input)
    output.isLoginEnabled.drive(observer).disposed(by: bag)
    scheduler.start()
}
```

`SharingScheduler.mock(scheduler:_:)` swaps the Driver/Signal scheduler for the duration of the closure. This is the recommended way to test code that exposes Drivers.

### Strategy 2: convert to Observable in the test

If the production code can be tested at the Observable level, do that:

```swift
viewModel.someInternalObservable        // an Observable<T>, not a Driver
    .subscribe(observer)
    .disposed(by: bag)
```

Use Strategy 2 only if exposing the inner Observable doesn't break encapsulation; otherwise prefer `SharingScheduler.mock`.

## RxBlocking

For small, synchronous-style assertions on Observables that complete quickly:

```swift
func test_validation_rejectsShortPassword() throws {
    let result = try validate(password: "ab")
        .toBlocking()
        .single()                          // expects exactly one .next + .completed

    XCTAssertEqual(result, .failed("Too short"))
}

let values = try observable.toBlocking().toArray()           // [T]
let first = try observable.toBlocking().first()              // T?
let last = try observable.toBlocking().last()                // T?
let materialized = observable.toBlocking().materialize()     // .completed([T]) or .failed([T], Error)
```

`toBlocking().materialize()` is the safe variant — it never throws; you pattern-match on the `MaterializedSequenceResult`. The other accessors throw on error.

**Don't use RxBlocking for**: streams that don't terminate, time-based operators (it'll wait real time), or anything driven by a Subject you can't synchronously close. Use `TestScheduler` instead.

## Testing a `Reactor` (ReactorKit)

ReactorKit supports two testing modes.

### Mode 1: Test the real Reactor

```swift
func test_refresh_setsLoadingThenUser() {
    let reactor = ProfileReactor(api: MockAPI(user: .mock))

    reactor.action.onNext(.refresh)

    let states = reactor.state.take(3).toBlocking().toArray()

    XCTAssertEqual(states[0].isLoading, false)             // initial
    XCTAssertEqual(states[1].isLoading, true)              // setLoading(true)
    XCTAssertEqual(states[2].user, .mock)                  // setUser
}
```

Asserts the actual `mutate` + `reduce` pipeline. Best for unit-testing the Reactor in isolation.

### Mode 2: Stub the Reactor for View tests

```swift
let reactor = ProfileReactor(api: MockAPI())
reactor.isStubEnabled = true                       // bypass mutate/reduce

let view = ProfileViewController()
view.reactor = reactor
_ = view.view                                      // trigger viewDidLoad → bind(reactor:)

// Push a synthetic state
var state = reactor.initialState
state.user = .mock
reactor.stub.state.accept(state)

XCTAssertEqual(view.nameLabel.text, User.mock.name)

// Assert what actions the View dispatched
view.followButton.sendActions(for: .touchUpInside)
XCTAssertEqual(reactor.stub.actions.last, .toggleFollow)
```

`reactor.stub.actions` is an `ActionSubject`; `reactor.stub.state` is a `BehaviorRelay`. The stub disables `mutate`/`reduce`, so the View can be tested in isolation.

## Tips

- **One `TestScheduler` per test method.** Reusing across tests leaks state.
- **Prefer `Recorded<Event<T>>` equality** over manual subscription tracking — it's clearer and less brittle.
- **Test the operators you actually use, not the framework.** Don't write tests for `map` or `filter`; test the **composition** in your ViewModel.
- **Keep `Single` tests cheap** — `try observable.toBlocking().single()` is a one-liner and reads well.
- **Time-based operators always need `TestScheduler`.** If a test runs for hundreds of milliseconds in real time, you forgot to pass `scheduler` to `debounce`/`throttle`/`delay`/`timeout`.

## Cross-references

- The operators most commonly tested → `operators.md`
- Driver/Signal scheduler considerations → `traits.md`, `schedulers.md`
- ViewModel/Reactor structure that makes tests easy → `architecture.md`
- Disposing test subscriptions → `disposal-and-memory.md`
