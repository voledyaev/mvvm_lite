# mvvm_lite

A tiny, zero-dependency MVVM toolkit for Flutter: a `ViewModel` base class, a provider that owns its lifecycle, and three widgets to read it. No DI, no routing, no code generation.

## Install

```yaml
dependencies:
  mvvm_lite: ^1.0.0
```

## Quick start

```dart
class CounterState {
  const CounterState({this.count = 0, this.isSaving = false});

  final int count;
  final bool isSaving;

  CounterState copyWith({int? count, bool? isSaving}) =>
      CounterState(count: count ?? this.count, isSaving: isSaving ?? this.isSaving);

  @override
  bool operator ==(Object other) =>
      other is CounterState && other.count == count && other.isSaving == isSaving;

  @override
  int get hashCode => Object.hash(count, isSaving);
}

class CounterViewModel extends ViewModel<CounterState> {
  CounterViewModel(this._repo) : super(const CounterState());

  final CounterRepo _repo;

  void increment() => state = state.copyWith(count: state.count + 1);

  Future<void> save() async {
    state = state.copyWith(isSaving: true);
    await _repo.save(state.count);
    if (!mounted) return;
    state = state.copyWith(isSaving: false);
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider(
        create: (_) => CounterViewModel(getIt()),
        builder: (context) => Scaffold(
          body: Center(
            child: ViewModelSelector<CounterState, int>(
              selector: (state) => state.count,
              builder: (context, count, child) => Text('$count'),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: context.viewModel<CounterViewModel>().increment,
            child: const Icon(Icons.add),
          ),
        ),
      );
}
```

## ViewModel

```dart
class ProfileViewModel extends ViewModel<ProfileState> {
  ProfileViewModel(this._repo) : super(const ProfileState()) {
    bindStream(
      _repo.updates,
      (user) => state = state.copyWith(user: user),
      onError: (error, _) => state = state.copyWith(error: error),
    );
  }

  final ProfileRepo _repo;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    final user = await _repo.fetch();
    if (!mounted) return;               // always, after every await
    state = state.copyWith(isLoading: false, user: user);
  }
}
```

```dart
abstract class ViewModel<S> extends ChangeNotifier implements ValueListenable<S> {
  ViewModel(S initial);

  S get state;
  S get value;                          // ValueListenable — same as `state`
  @protected set state(S value);        // notifies only when `!=`

  bool get mounted;

  @protected StreamSubscription<E> bindStream<E>(
    Stream<E> stream,
    void Function(E event) onData, {
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  });
}
```

Equality decides whether listeners fire, so pair it with `freezed`, records, or hand-written `==`.

Writing `state` after `dispose` throws a `FlutterError` in debug and release, without changing the state — that is what the `mounted` check prevents. Subscriptions from `bindStream` are cancelled on dispose; the returned subscription can be cancelled earlier. Without `onError` a stream error goes to the surrounding `Zone` and never reaches the view model.

## ViewModelProvider

```dart
ViewModelProvider(
  create: (_) => ProfileViewModel(getIt()),
  child: const ProfileBody(),
)

ViewModelProvider(
  create: (_) => ProfileViewModel(getIt()),
  builder: (context) => ProfileBody(
    onRefresh: context.viewModel<ProfileViewModel>().refresh,
  ),
)

ViewModelProvider.value(
  value: fakeViewModel,          // never disposed by the provider
  child: const ProfileBody(),
)
```

Creates the view model when mounted, disposes it when removed. Pass exactly one of `child` or `builder`. The type argument is inferred from `create`.

`create` runs in `initState`, so it can use `context.viewModel<ParentVm>()`, `get_it` or `Provider.of(context, listen: false)`, but not `Theme.of`, `MediaQuery.of` or anything else that registers an inherited-widget dependency. Read those above the provider and pass them in.

## ViewModelBuilder

```dart
ViewModelBuilder<ProfileState>(
  builder: (context, state, child) => Text(state.userName),
)

ViewModelBuilder<ProfileState>(
  buildWhen: (previous, next) => previous.items != next.items,
  builder: (context, state, child) => ItemList(state.items),
  child: const ExpensiveHeader(),      // built once, forwarded unchanged
)
```

## ViewModelSelector

```dart
ViewModelSelector<ProfileState, String>(
  selector: (state) => state.userName,
  builder: (context, name, child) => Text(name),
)

ViewModelSelector<ProfileState, (int, bool)>(
  selector: (state) => (state.unread, state.isPremium),
  builder: (context, value, child) => UnreadCount(value.$1, premium: value.$2),
)

ViewModelSelector<ProfileState, List<Item>>(
  selector: (state) => state.items,
  buildWhen: (a, b) => !const ListEquality().equals(a, b),  // package:collection
  builder: (context, items, child) => ItemList(items),
)
```

Rebuilds only when the projection changes, compared with `==` unless `buildWhen` says otherwise.

## ViewModelListener

```dart
ViewModelListener<ProfileState>(
  listenWhen: (previous, next) => !previous.saved && next.saved,
  listener: (context, state) =>
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved'))),
  child: const ProfileBody(),
)
```

Runs a side effect and rebuilds nothing. `listenWhen` receives the previous and next state, which is what makes an effect fire on a transition rather than on every change while a flag stays set.

The `*When` gates apply to changes, not to the first pass: a builder and a selector always render once, and a listener never fires for the state that was already there when it mounted. In `buildWhen`, `previous` is the state the widget was last built with, so a declined change never becomes the baseline; in `listenWhen` it always advances.

## context.viewModel

```dart
onPressed: () => context.viewModel<ProfileViewModel>().refresh(),
```

Returns the nearest view model assignable to `VM` without subscribing. Throws a `FlutterError` in debug and release when there is no matching provider above.

## Resolution

The three widgets bind to the **nearest** provider whose view model is a `ViewModel<S>`, so keeping state types distinct is up to you:

```dart
// Ambiguous: nest these, even by accident, and the inner one wins silently.
class SavedCountViewModel extends ViewModel<int> { ... }
class DonationSumViewModel extends ViewModel<int> { ... }

// Unambiguous: a type per view model.
class SavedCount {
  const SavedCount(this.value);
  final int value;
}
```

Two things that surprise people: extension types are erased at runtime, so `ViewModel<SavedCount>` and `ViewModel<int>` are the same type and the wrapper buys nothing — use a class or a record. And generics are covariant, so `ViewModelBuilder<ProfileState>` also binds to a provider of `PremiumProfileState extends ProfileState`.

## Side effects

Three different things tend to hide behind one "navigation event" field, and each has a shorter path.

The result of a tap — return it:

```dart
onPressed: () async {
  final paid = await context.viewModel<CheckoutViewModel>().pay();
  if (paid && context.mounted) Navigator.of(context).pushNamed('/receipt');
},
```

A transition of real state — `ViewModelListener`:

```dart
ViewModelListener<ProfileState>(
  listenWhen: (previous, next) => previous.profile is! AsyncError && next.profile is AsyncError,
  listener: (context, state) {
    if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
  },
  child: const ProfileBody(),
)
```

A genuine one-shot message — a nullable field that the effect clears:

```dart
ViewModelListener<MyState>(
  listenWhen: (previous, next) => previous.navEvent == null && next.navEvent != null,
  listener: (context, state) {
    context.viewModel<MyVm>().clearNavEvent();
    switch (state.navEvent!) {
      case OpenChildPageNavEvent(:final id):
        Navigator.of(context).pushNamed('/child', arguments: id);
    }
  },
  child: const MyPageContent(),
)
```

Clearing is load-bearing: the setter only notifies when the state changed, so an uncleared event can never fire twice. And a page below the top of the stack stays mounted, so check the route before navigating.

## Testing

```dart
test('increments', () {
  final vm = CounterViewModel(FakeRepo());
  addTearDown(vm.dispose);

  vm.increment();

  expect(vm.state.count, 1);
});
```

```dart
class FakeProfileViewModel extends ProfileViewModel {
  FakeProfileViewModel(ProfileState initial) : super(FakeProfileRepo()) {
    emit(initial);
  }

  void emit(ProfileState next) => state = next;

  @override
  Future<void> refresh() async {}
}

testWidgets('renders the profile', (tester) async {
  final vm = FakeProfileViewModel(const ProfileState(name: 'Ada'));
  addTearDown(vm.dispose);

  await tester.pumpWidget(
    MaterialApp(home: ViewModelProvider.value(value: vm, child: const ProfilePage())),
  );
  expect(find.text('Ada'), findsOneWidget);

  vm.emit(const ProfileState(name: 'Grace'));
  await tester.pump();
  expect(find.text('Grace'), findsOneWidget);
});
```

`ViewModelProvider.value` never disposes what it is handed, so the test owns the lifecycle. Lookups match by assignability, so the page's own `context.viewModel<ProfileViewModel>()` finds the fake.

## Trade-offs

- **No DI.** Wire dependencies in `create` yourself.
- **No async-state type.** `ViewModel<S>` is just `S`; define your own loading/data/error union if you want one.
- **No cross-screen sharing.** A provider owns one view model for as long as its subtree lives.
- **No code generation.** `copyWith`, `==` and `hashCode` are yours to write or generate.
- **No reactive composition.** Compose at the use-case layer, not between view models.

## Migrating from 0.2.x

| 0.2.x | 1.0.0 |
| --- | --- |
| `Consumer<S>` | `ViewModelBuilder<S>` |
| `Selector<S, T>` | `ViewModelSelector<S, T>` |
| `Selector.shouldRebuild` | `ViewModelSelector.buildWhen` |
| `context.readVm<VM>()` | `context.viewModel<VM>()` |
| `ViewModelProvider<VM, S>` | `ViewModelProvider<VM>` |
| `ConsumerBuilder<S>` | `ViewModelWidgetBuilder<S>` |
| `SelectorBuilder<T>` | `SelectorWidgetBuilder<T>` |
| `StateSelector<S, T>` | `StateProjection<S, T>` |
| `SelectorShouldRebuild<T>` | `ViewModelBuilderCondition<T>` |

There are no deprecated aliases: a stale call site is a compile error.

## Status

Stable API from `1.0.0`. Requires Dart `^3.8.0` (Flutter 3.32 and newer).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Keep the surface small — that is the feature.

## License

[MIT](LICENSE)
