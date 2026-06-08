# Architecture: MVVM Input/Output and ReactorKit

Two patterns dominate RxSwift-based iOS architecture, and both are first-class in this skill:

1. **MVVM with Input/Output structs** — the canonical RxSwift ViewModel shape, taught in countless tutorials and used in many Korean-iOS codebases.
2. **ReactorKit** — a strict unidirectional pattern (Action → Mutation → State) built on RxSwift, very popular in the Korean iOS ecosystem (Kakao, Toss, LINE Pay, Kurly, StyleShare).

Both are valid, both are testable, both are widely deployed. **Match the project's existing pattern.** Don't refactor between them unprompted.

> Read this when: structuring a new ViewModel, picking between MVVM I/O and ReactorKit, implementing the `Reactor` protocol, or adapting an existing screen.

## Design principles shared by both

- **Pure functions where possible.** State derivations should be expressible as `map` / `combineLatest` / `scan`. Side effects (network, persistence) live in well-defined places — never sprinkled across the View.
- **Outputs never error.** Use `Driver`/`Signal` for everything the View consumes. Convert errors to values (`Result<T, E>`, custom `RemoteState` enum) before they reach the boundary. See `error-handling.md`.
- **Public read, private write.** Subjects/Relays are `private`; the View sees `Driver`/`Signal`/`Observable`. See `subjects-and-relays.md`.
- **Composition over nesting.** No `subscribe` inside `subscribe`. Use the `flatMap` family. See `operators.md`, `disposal-and-memory.md`.

## MVVM with Input/Output

The pattern packages user input on one side, derived UI state on the other, and a `transform(input:)` function that wires them. Made popular by RxSwift community samples; lives in projects across the Korean iOS scene.

### The `ViewModelType` protocol

```swift
protocol ViewModelType {
    associatedtype Input
    associatedtype Output
    func transform(input: Input) -> Output
}
```

### A worked example

```swift
final class LoginViewModel: ViewModelType {
    struct Input {
        let username: Driver<String>          // textField.rx.text.orEmpty.asDriver()
        let password: Driver<String>
        let loginTap: Signal<Void>            // button.rx.tap.asSignal()
    }

    struct Output {
        let isLoginEnabled: Driver<Bool>
        let isLoading: Driver<Bool>
        let didLogin: Signal<User>
        let errorMessage: Signal<String>
    }

    private let api: AuthAPI
    init(api: AuthAPI) { self.api = api }

    func transform(input: Input) -> Output {
        let credentials = Driver.combineLatest(input.username, input.password) { Credentials($0, $1) }

        let isLoginEnabled = credentials
            .map { $0.isComplete }
            .distinctUntilChanged()

        let isLoadingRelay = BehaviorRelay(value: false)
        let didLoginRelay = PublishRelay<User>()
        let errorRelay = PublishRelay<String>()

        input.loginTap
            .withLatestFrom(credentials)
            .asObservable()
            .flatMapLatest { creds -> Observable<RemoteState<User>> in
                api.login(creds)
                    .map(RemoteState.loaded)
                    .catch { .just(.failed($0)) }
                    .startWith(.loading)
            }
            .subscribe(onNext: { state in
                switch state {
                case .loading:           isLoadingRelay.accept(true)
                case .loaded(let user):  isLoadingRelay.accept(false); didLoginRelay.accept(user)
                case .failed(let err):   isLoadingRelay.accept(false); errorRelay.accept(err.localizedDescription)
                case .idle:              break
                }
            })
            .disposed(by: disposeBag)

        return Output(
            isLoginEnabled: isLoginEnabled,
            isLoading: isLoadingRelay.asDriver(),
            didLogin: didLoginRelay.asSignal(),
            errorMessage: errorRelay.asSignal(onErrorJustReturn: "Unknown error")
        )
    }

    private let disposeBag = DisposeBag()
}
```

### View wiring

```swift
final class LoginViewController: UIViewController {
    private let viewModel: LoginViewModel
    private let bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        let input = LoginViewModel.Input(
            username: usernameField.rx.text.orEmpty.asDriver(),
            password: passwordField.rx.text.orEmpty.asDriver(),
            loginTap: loginButton.rx.tap.asSignal()
        )
        let output = viewModel.transform(input: input)

        output.isLoginEnabled.drive(loginButton.rx.isEnabled).disposed(by: bag)
        output.isLoading.drive(activityIndicator.rx.isAnimating).disposed(by: bag)
        output.didLogin.emit(with: self) { owner, user in owner.router.show(user) }.disposed(by: bag)
        output.errorMessage.emit(with: self) { owner, msg in owner.showAlert(msg) }.disposed(by: bag)
    }
}
```

### Why this pattern works

- **Boundary clarity.** Input is what the View pushes; Output is what it consumes. Anything else is internal.
- **Testability.** `transform(input:)` is a pure function from streams to streams. Drive the inputs with a `TestScheduler`; assert on the outputs (see `testing.md`).
- **Replaceable.** Swapping the API or coordinating with another VM only touches `transform`.

### Common variations

- `Input`/`Output` may be `protocol`s rather than structs — same idea.
- Some teams use `Observable<T>` instead of `Driver`/`Signal` in `Input` to avoid coupling the ViewModel to RxCocoa. The Output side should still be `Driver`/`Signal` to enforce UI safety.
- For very simple screens, the pair degenerates into a single struct of relays — at that point, consider whether MVC + RxCocoa is enough.

## ReactorKit

ReactorKit enforces a strict unidirectional flow: the View dispatches an `Action`, the Reactor turns it into one or more `Mutation`s, and a pure `reduce` function applies each `Mutation` to the current `State`. The View binds to `state` and renders.

### The `Reactor` protocol

```swift
protocol Reactor: AnyObject {
    associatedtype Action
    associatedtype Mutation = Action
    associatedtype State

    var initialState: State { get }
    var currentState: State { get }            // synchronous read
    var action: ActionSubject<Action> { get }
    var state: Observable<State> { get }

    func mutate(action: Action) -> Observable<Mutation>
    func reduce(state: State, mutation: Mutation) -> State

    func transform(action: Observable<Action>) -> Observable<Action>
    func transform(mutation: Observable<Mutation>) -> Observable<Mutation>
    func transform(state: Observable<State>) -> Observable<State>
}
```

You implement `Action`, `Mutation`, `State`, `initialState`, `mutate`, `reduce`. ReactorKit synthesizes the rest.

### A worked example

```swift
final class ProfileReactor: Reactor {
    enum Action {
        case refresh
        case toggleFollow
    }

    enum Mutation {
        case setLoading(Bool)
        case setUser(User)
        case setFollowing(Bool)
        case setError(String)
    }

    struct State {
        var user: User?
        var isLoading: Bool = false
        var isFollowing: Bool = false
        @Pulse var errorMessage: String?            // re-fires even if same value
    }

    let initialState = State()
    private let api: ProfileAPI
    init(api: ProfileAPI) { self.api = api }

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .refresh:
            return Observable.concat([
                .just(.setLoading(true)),
                api.fetchProfile()
                    .map(Mutation.setUser)
                    .catch { .just(.setError($0.localizedDescription)) },
                .just(.setLoading(false))
            ])
        case .toggleFollow:
            let now = !currentState.isFollowing
            return api.setFollow(now)
                .andThen(.just(.setFollowing(now)))
                .catch { .just(.setError($0.localizedDescription)) }
        }
    }

    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        switch mutation {
        case .setLoading(let v):    state.isLoading = v
        case .setUser(let u):       state.user = u
        case .setFollowing(let v):  state.isFollowing = v
        case .setError(let msg):    state.errorMessage = msg
        }
        return state
    }
}
```

### View wiring

```swift
final class ProfileViewController: UIViewController, View {
    typealias Reactor = ProfileReactor
    var disposeBag = DisposeBag()

    func bind(reactor: ProfileReactor) {
        // Action
        rx.viewDidAppear
            .map { _ in Reactor.Action.refresh }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        followButton.rx.tap
            .map { Reactor.Action.toggleFollow }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        // State
        reactor.state.map { $0.user?.name }
            .distinctUntilChanged()
            .bind(to: nameLabel.rx.text)
            .disposed(by: disposeBag)

        reactor.state.map { $0.isLoading }
            .distinctUntilChanged()
            .bind(to: spinner.rx.isAnimating)
            .disposed(by: disposeBag)

        reactor.state.map { $0.isFollowing }
            .distinctUntilChanged()
            .bind(to: followButton.rx.isSelected)
            .disposed(by: disposeBag)

        // @Pulse ensures the same error string re-fires
        reactor.pulse(\.$errorMessage)
            .compactMap { $0 }
            .bind(with: self) { owner, msg in owner.showAlert(msg) }
            .disposed(by: disposeBag)
    }
}
```

### `transform` hooks

The three `transform` methods let you intercept and merge global streams into the per-Reactor flow:

```swift
// Inject a global "user" mutation when the logged-in user changes
func transform(mutation: Observable<Mutation>) -> Observable<Mutation> {
    return Observable.merge(mutation, GlobalUser.changes.map(Mutation.setUser))
}
```

`transform(action:)` is useful for global action filtering/logging; `transform(state:)` is the right place to attach a global `share(replay:scope:)` to the state stream if you have many subscribers.

### `@Pulse`

`@Pulse` makes a property re-emit on **every** mutation, even if the value is unchanged. Use for one-shot UI events that live inside `State` (alerts, navigation, toasts):

```swift
struct State {
    @Pulse var routeToDetail: Detail?
}

reactor.pulse(\.$routeToDetail)
    .compactMap { $0 }
    .bind(with: self) { owner, detail in owner.router.show(detail) }
    .disposed(by: disposeBag)
```

Without `@Pulse`, presenting the same alert twice in a row wouldn't fire the second time (because of implicit deduplication on `state` subscriptions).

### Stub-based testing

ReactorKit provides a `stub` for testing the View → Reactor → View loop without running `mutate`/`reduce`:

```swift
let reactor = ProfileReactor(api: mockAPI)
reactor.isStubEnabled = true
reactor.stub.state.value.user = User.mock

XCTAssertEqual(reactor.stub.actions.last, .refresh)        // assert on dispatched actions
reactor.stub.state.accept(updatedState)                    // push a synthetic state
```

See `testing.md` for the full pattern.

## Comparison and selection

| Dimension | MVVM Input/Output | ReactorKit |
|---|---|---|
| **Boilerplate** | Moderate (Input/Output structs + `transform`) | Higher (Action + Mutation + State + reduce) |
| **State shape** | Many small relays/drivers, ad-hoc | Single `State` struct, single source of truth |
| **Async work** | Anywhere in `transform` body | Concentrated in `mutate(action:)` |
| **Side-effect discipline** | Convention | Compiler-encouraged (`reduce` is pure by intent) |
| **Testability** | High (`transform` is a function) | High (Reactor is a function on streams; `stub` for View tests) |
| **Team familiarity (KR ecosystem)** | Very common | Very common, especially at large companies (Kakao, Toss, LINE Pay, Kurly, StyleShare) |
| **Onboarding cost** | Low | Medium (concepts: Action/Mutation/State, transform pipeline) |
| **Best fit** | Small/medium screens, simple state | Complex state, many concurrent inputs, audit trails |

### Selection guide

Start with whatever the codebase already uses. For a greenfield project:

- **Pick MVVM I/O when**: solo/small team, simple to medium screens, you want minimal ceremony, the team is new to Rx.
- **Pick ReactorKit when**: medium-to-large screens with many concurrent inputs, complex state with derived sub-properties, you want a strict reduce-only state machine, the team is comfortable with unidirectional patterns.

Mixing both in the same project is fine — adopt ReactorKit per-screen as complexity warrants.

## Anti-patterns

- **Putting closures in `State`.** `State` should be a value type with displayable data. Closures break Equatable, hide dependencies, and surprise testers.
- **Heavy `reduce`.** `reduce(state:mutation:)` must be pure and synchronous. Move computation to `mutate`. (See `anti-patterns.md`.)
- **View dispatching multiple Mutations directly.** The View dispatches **Actions**. Only `mutate` produces Mutations.
- **MVVM Output that emits Subjects.** Outputs must be `Driver`/`Signal` (or read-only `Observable`); never expose the raw Subject.
- **Coordinator/Router calls inside `reduce`.** Side effects belong in `mutate` (or a separate effects layer); `reduce` derives state.

## Cross-references

- Subjects/Relays as the writable backing store → `subjects-and-relays.md`
- Driver/Signal contract for outputs → `traits.md`
- Why outputs must be error-less → `error-handling.md`
- Testing both patterns → `testing.md`
- Anti-patterns specific to architecture → `anti-patterns.md`
