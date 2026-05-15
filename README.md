# mvvm_lite

A tiny, zero-dependency MVVM toolkit for Flutter.

`mvvm_lite` gives you a `ViewModel` base class, a scoped provider that owns its lifecycle, and `Consumer` / `Selector` widgets with sane parameter names — and nothing else. No DI, no routing, no service-locator, no code generation. A few hundred lines across six small files; the only dependency is the Flutter SDK.

It's for teams that picked MVVM with constructor injection on purpose and just need a clean reactive primitive that won't be quietly deprecated or grow into a framework.

## Why another one

| You want                                                                                      | Use                                          |
| --------------------------------------------------------------------------------------------- | -------------------------------------------- |
| Global cross-screen caching, async lifecycle, fine-grained reactivity, a strong opinion       | [`riverpod`](https://pub.dev/packages/riverpod) |
| Event-sourced, audit-friendly state machines for big teams                                    | [`flutter_bloc`](https://pub.dev/packages/flutter_bloc) |
| MVVM with constructor injection, `ChangeNotifier` semantics, granular rebuilds, zero magic    | **this**                                     |

`provider` is the closest thing in spirit, but: it hasn't seen new features in years, the `Selector` builder shows `p0, p1` in IDE autocomplete instead of named parameters, and it's a much larger surface than the MVVM pattern actually needs. `mvvm_lite` extracts the 5% you'd use anyway, fixes the param-naming nit, and stops.

## Install

```yaml
dependencies:
  mvvm_lite: ^0.1.0
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:mvvm_lite/mvvm_lite.dart';

class CounterState {
  const CounterState({this.count = 0});
  final int count;
  CounterState copyWith({int? count}) => CounterState(count: count ?? this.count);

  @override
  bool operator ==(Object other) =>
      other is CounterState && other.count == count;
  @override
  int get hashCode => count.hashCode;
}

class CounterViewModel extends ViewModel<CounterState> {
  CounterViewModel() : super(const CounterState());
  void increment() => state = state.copyWith(count: state.count + 1);
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) =>
      ViewModelProvider<CounterViewModel, CounterState>(
        create: (_) => CounterViewModel(),
        builder: (context) => Scaffold(
          body: Center(
            child: Selector<CounterState, int>(
              selector: (state) => state.count,
              builder: (_, count, __) => Text('$count'),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.readVm<CounterViewModel>().increment(),
            child: const Icon(Icons.add),
          ),
        ),
      );
}
```

## API

### `ViewModel<S>`

```dart
abstract class ViewModel<S> extends ChangeNotifier {
  ViewModel(S initial);

  S get state;
  @protected set state(S value);   // notifyListeners only on `!=`

  @protected bool get mounted;     // check after every await
  @protected void bindStream<E>(Stream<E>, void Function(E));
}
```

Subclass it and write `state = state.copyWith(...)`. Equality decides whether listeners fire — pair with `freezed`, records, or `==`-implementing classes.

`bindStream` is for "subscribe once and forget"; if you need to cancel mid-life or replace on event, keep your own `StreamSubscription` field.

### `ViewModelProvider<VM, S>`

```dart
ViewModelProvider<MyVM, MyState>(
  create: (_) => MyVM(getIt<MyRepo>()),
  child: const MyPage(),
)
```

Creates the view model eagerly when mounted, disposes it when removed. Pass either `child` (static subtree) or `builder` (when the immediate child needs `context.readVm<VM>()`). Not both, not neither.

Resolve VM dependencies inside `create` however you like — `mvvm_lite` doesn't ship a service locator. The example uses `get_it`; manual construction, `Provider.of`, or any other approach works equally well.

The `BuildContext` passed to `create` can be used to look up parent view models via `context.readVm<ParentVm>()` when one VM needs to observe or reference another.

### `Consumer<S>`

```dart
Consumer<MyState>(
  builder: (context, state, child) => ...,
  child: const ExpensiveStaticSubtree(), // optional
)
```

Rebuilds on every state change. Pass a `child` when part of the subtree is static — it's forwarded into `builder` without rebuilding.

### `Selector<S, T>`

```dart
Selector<MyState, String>(
  selector: (state) => state.userName,
  builder: (context, name, child) => Text(name),
)
```

Rebuilds only when the projected value changes. Uses `==` by default. For collections without value equality, pass `shouldRebuild`:

```dart
Selector<MyState, List<Item>>(
  selector: (state) => state.items,
  shouldRebuild: (a, b) => !const ListEquality().equals(a, b),
  builder: ...,
)
```

The `selector` and `builder` callbacks use named typedef'd signatures, so your IDE autocompletes `(state)`, `(context, value, child)` — not `(p0, p1)`.

### `context.readVm<VM>()`

```dart
context.readVm<MyVM>().doSomething();
```

Looks up the nearest `ViewModelProvider<VM, …>` ancestor and returns the view model without subscribing. Use for one-shot calls from event handlers.

Named `readVm` rather than `read` to avoid colliding with `provider`'s `BuildContext.read<T>()` extension when both packages are present during migration.

## Patterns

### `mounted` checks after `await`

Always:

```dart
Future<void> save() async {
  state = state.copyWith(isSaving: true);
  try {
    await repo.save(state.payload);
    if (!mounted) return;
    state = state.copyWith(isSaving: false, saved: true);
  } catch (e) {
    if (!mounted) return;
    state = state.copyWith(isSaving: false, error: e);
  }
}
```

The base class flips `mounted` to `false` in `dispose` — without the guard, your `state` setter will throw because the underlying `ChangeNotifier` has been disposed.

### Stream subscriptions

For "listen forever, until the view model dies":

```dart
class FeedViewModel extends ViewModel<FeedState> {
  FeedViewModel(this._repo) : super(const FeedState()) {
    bindStream(_repo.stream, (event) {
      state = state.copyWith(items: event.items);
    });
  }
  final FeedRepo _repo;
}
```

For subscriptions you replace or cancel mid-life, hold a `StreamSubscription` field yourself and cancel it in an overridden `dispose`.

### Navigation events

Keep navigation in the UI layer. Have the view model write `navEvent` into state; the page listens to its own view model and routes:

```dart
@override
Widget build(BuildContext context) =>
    ViewModelProvider<MyVm, MyState>(
      create: (_) {
        final vm = MyVm();
        vm.addListener(() {
          final event = vm.state.navEvent;
          if (event == null) return;
          vm.clearNavEvent();
          switch (event) {
            case PopMyPageNavEvent(): Navigator.of(context).pop();
            case OpenChildPageNavEvent(:final id):
              Navigator.of(context).pushNamed('/child', arguments: id);
          }
        });
        return vm;
      },
      child: const MyPageContent(),
    );
```

This keeps side-effects local and testable — view model logic is pure, side-effects are wired up exactly once per page.

## Trade-offs (read before adopting)

- **No DI.** You wire dependencies into the `create` callback yourself, typically via a service locator like `get_it`. By design — DI is a separate concern.
- **No async-state primitive.** `ViewModel<S>` is just `S`. If you want `AsyncValue<T>`-style sealed loading/data/error states, define them yourself in your project (a few dozen lines). The package intentionally doesn't ship one — different projects want different semantics.
- **No cross-screen state sharing.** Each `ViewModelProvider` owns one view model that lives exactly as long as the page. If you need a shared, app-wide cached state graph, you want `riverpod` instead.
- **No code generation.** State classes (`copyWith`, `==`, `hashCode`) are your responsibility — use `freezed` or records if hand-writing them is painful.
- **No reactive composition.** A view model can listen to another's stream via `bindStream`, but there's no "computed provider" abstraction. Compose at the application/use-case layer instead.

## Comparison

| Feature                       | mvvm_lite        | provider              | riverpod         | flutter_bloc     |
| ----------------------------- | ---------------- | --------------------- | ---------------- | ---------------- |
| LOC of source                 | ~250             | ~3000                 | ~10k+            | ~5k+             |
| External dependencies         | 0                | 2 (`collection`, `nested`) | several     | several          |
| Code generation               | no               | no                    | optional         | optional         |
| Built-in DI                   | no               | partial               | yes              | no               |
| Async-state sealed type       | no               | no                    | yes (`AsyncValue`)| no              |
| Cross-screen state cache      | no               | manual                | yes              | manual           |
| Granular rebuilds via selector| yes              | yes                   | yes (`select`)   | yes (`buildWhen`)|
| IDE-friendly param names      | yes              | no (`p0, p1`)         | yes              | yes              |
| Side-effects from state       | UI layer         | UI layer              | discouraged      | UI layer (`listener`) |

## Status

- Stable API surface; semantic versioning from `0.1.0`.
- Targets Flutter `>=3.10.0`, Dart `>=3.0.0`. Uses only ancient Flutter SDK primitives (`ChangeNotifier`, `InheritedWidget`, `StatefulWidget`) — no version-specific APIs.
- Public-member docstrings on everything; `public_member_api_docs` is on in the lint config.

## Contributing

Issues and PRs welcome at the repository. Keep the surface area small — this is deliberately a tiny package and will stay one.

## License

[MIT](LICENSE)
