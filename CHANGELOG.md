## 1.0.1

No change to the API or to the `^3.8.0` SDK floor — Flutter 3.32 and newer stays
supported.

- Verified against Flutter 3.47 / Dart 3.13. The Material and Cupertino split in
  3.47 does not reach this package — it imports only `foundation.dart` and
  `widgets.dart`.
- `example/` moved from `package:flutter/material.dart` to `material_ui` 1.0 and
  now requires Flutter 3.44 or newer on its own.

## 1.0.0

First stable release. The API surface is now committed to: additions come in
minor versions, removals only in 2.0.0.

Coming from 0.2.0, this release renames the widget layer, hardens the view
model lifecycle, and raises the SDK floor. There are no deprecated aliases —
old names are compile errors, not warnings.

### Renamed

| 0.2.0 | 1.0.0 |
| --- | --- |
| `Consumer<S>` | `ViewModelBuilder<S>` |
| `Selector<S, T>` | `ViewModelSelector<S, T>` |
| `Selector.shouldRebuild` | `ViewModelSelector.buildWhen` |
| `context.readVm<VM>()` | `context.viewModel<VM>()` |
| `ConsumerBuilder<S>` | `ViewModelWidgetBuilder<S>` |
| `SelectorBuilder<T>` | `SelectorWidgetBuilder<T>` |
| `StateSelector<S, T>` | `StateProjection<S, T>` |
| `SelectorShouldRebuild<T>` | `ViewModelBuilderCondition<T>` |

`Consumer` only ever built, so it is a builder. `StateSelector` read as a
sibling of the `Selector` widget while actually being the projection function.
`readVm` lost its suffix because there is no `watch` to contrast it with —
subscriptions belong to the widgets.

### Added

- `ViewModelListener<S>` runs a side effect on state changes without rebuilding
  anything — navigation, snack bars, dialogs, analytics. Its `listenWhen`
  receives the previous and the next state, which makes edge-triggered effects
  expressible: `(previous, next) => !previous.done && next.done` fires once on
  the transition, where a `next.done` check inside the effect keeps firing on
  every later change. That level-versus-edge slip is the failure this widget
  exists to prevent. The README's side-effects section now separates the three
  cases that usually hide behind one "navigation event" field: results of a tap
  (return them from the method), transitions of real state (this widget), and
  genuine one-shot messages (a nullable field that must be cleared).
- `ViewModelProvider.value` exposes a view model the provider must not own —
  `dispose` is never called for it. This is what makes pages testable: pump a
  page with a fake or pre-seeded view model and keep the lifecycle in the test.
  README gained a Testing section covering both view-model and widget tests.
- `bindStream` gained optional `onError`, `onDone` and `cancelOnError`
  parameters and returns the `StreamSubscription`, so a subscription can be
  cancelled early without keeping a separate field. Omitting `onError` keeps
  Dart's default (the error reaches the surrounding `Zone`). All three
  callbacks are skipped once the view model is disposed.
- `ViewModelBuilder` gained `buildWhen`, so all three widgets now share one
  shape: a callback that receives data — the state for the builder and the
  listener, the projected value for the selector — and a `*When` gate over the
  previous and next of whatever that callback consumes. `previous` is the state
  the widget was last built with, so a change it declined never becomes a
  baseline. None of the gates apply to the first pass: a builder and a selector
  always render once — they have to put something on screen — while a listener
  never fires for the state that was already there when it mounted.
- `ViewModel.mounted` is public rather than protected: tests and owning code
  legitimately need to ask whether a view model is still alive.
- `ViewModelProvider` reports its view model, current state and ownership
  through `debugFillProperties`, so page state is visible in the Flutter
  inspector.

### Changed

- **`ViewModelProvider` lost its state type parameter** and is now
  `ViewModelProvider<VM>`, inferred from `create`. Lookups match the view model
  by **assignability at runtime** rather than by exact generic type, which
  removes two whole failure modes:
  - Below Dart 3.7 the language could not infer the old `S` from the view
    model's bound, so `ViewModelProvider(create: ...)` written without explicit
    type arguments silently resolved `S` to `dynamic`, and every widget beneath
    it then failed at runtime with a message pointing at the wrong thing. With
    no `S` to infer, the trap is gone at any language version — the runtime type
    of the view model always carries the real state type.
  - A fake that subclasses the real view model, injected through
    `ViewModelProvider.value`, is now found by `context.viewModel<RealVm>()`.
    Before, the scope was registered under the fake's exact type and the
    documented testing recipe threw on the first interaction.
- **Requires Dart `^3.8.0`** (Flutter 3.32 and newer), up from `^3.0.0`. The
  constraint is a single number now: the `flutter:` bound is gone, because the
  Dart version follows from the Flutter release and declaring both invites a
  pair that contradicts itself. 3.8 is the lowest version at which this
  repository verifies itself — `flutter_lints` resolves there and everything
  compiles and formats unchanged.
- **Writing `state` after `dispose()` throws** a descriptive `FlutterError` in
  both debug and release builds, and leaves the state untouched. Previously the
  field was assigned *before* `ChangeNotifier` raised its debug-only assertion,
  so a disposed view model ended up holding a state nobody could observe — and
  in release the write landed silently.
- `bindStream` throws when called after `dispose()`; such a subscription would
  never be cancelled.
- `ViewModelProvider` throws a descriptive `FlutterError` when neither (or
  both) of `child`/`builder` is given, instead of relying on the constructor
  assertion that release builds strip.
- **`ViewModel<S>` implements `ValueListenable<S>`**, so a view model can be
  handed to `ValueListenableBuilder`, `ListenableBuilder` or anything else in
  the framework that accepts one. Breaking for any subclass that already
  declared a member named `value`.
- `ViewModelListener` runs its effect once per logical state change. A
  `ChangeNotifier` re-enters its listener list, so an effect that writes state —
  clearing a one-shot event, for instance — used to make every listener
  registered after it fire twice, the second time with `previous == next`. Those
  repeats are now skipped.
- Switching a mounted `ViewModelProvider` between the default and `.value`
  constructors is supported instead of asserted against: the widget disposes
  what it created and adopts what it is handed, and never disposes a view model
  it does not own. Previously the debug assertion left the created view model
  leaked and the release build disposed the caller's.
- `bindStream` hands back a subscription that removes itself from the view
  model's list when cancelled or when its stream completes, so a view model that
  binds and cancels repeatedly no longer accumulates dead subscriptions until
  dispose.
- `ViewModelSelector` skips rebuild work once unmounted, matching
  `ViewModelBuilder`, and its `buildWhen` is now also consulted when a new
  selector closure arrives from a parent rebuild — previously any parent rebuild
  slipped a new value past the gate. `ViewModelBuilder` does the same for a
  changed `buildWhen`, so relaxing a gate no longer leaves the widget frozen
  until the next notification.
- A consumer that loses its provider reports from `build` rather than from
  `didChangeDependencies`. The latter runs outside the framework's build-error
  recovery, so the widget stayed permanently unbuilt — one console error, no
  error widget, and its subscription retained.
- `ViewModelProvider` disposes exactly the view model it created. Handing a
  provider back the instance it had created — `create` then `.value` with that
  same object — used to leave it alive with nothing left to dispose it.
- `dispose` no longer lets a failing `cancel()` abort the rest: a stream whose
  `onCancel` throws used to skip the remaining subscriptions and
  `super.dispose()`, or surface as an uncaught asynchronous error.
- The subscription returned by `bindStream` keeps its bookkeeping when the
  caller replaces `onDone` or calls `asFuture`; both used to silently drop it.

### Documentation

- `create` runs in `initState`, which permits `context.viewModel` and
  service-locator lookups but not `Theme.of` / `MediaQuery.of` /
  `context.watch`. Documented, with the workaround, and pinned by a test.
- The side-effects section explains why a one-shot event must be cleared after
  handling (equal states don't notify, so an uncleared event can never fire
  twice) and why a page below the top of the stack has to check that it is
  still the current route before navigating.
- Fixed a claim that the bundled example uses `get_it` — it doesn't.
- Resolution by state type is now stated as a contract rather than advice, with
  the wrapper-type example and two things that surprise people: extension types
  are erased, so `ViewModel<SavedCount>` and `ViewModel<int>` are the same type
  at runtime and the wrapper buys nothing; and generics are covariant, so a
  builder keyed on a supertype binds to a provider of its subtype.

### Tooling

- GitHub Actions CI: format, analyze, package and example tests, publish dry
  run and `pana` on stable, plus a job running the suite on the exact declared
  floor.
- `example/.pubignore` drops the generated platform folders from the published
  archive: 290 KB to 26 KB, with the pub.dev "Example" tab intact. It has to
  live in `example/`, never in the repository root — a root-level `.pubignore`
  replaces the root `.gitignore` for pub and pulls `build/` back in. The same
  replacement applies one level down, so `coverage/` is listed explicitly:
  `example/.gitignore` no longer has any effect on what is published.
- `CONTRIBUTING.md`.
- Test suite grew from 17 to 57 tests.
- Dependabot keeps the CI actions current; the package itself has no
  dependencies to watch.
- Lints come from `flutter_lints`, the official set for Flutter packages,
  instead of the language-only `lints`. It adds ten Flutter-specific rules
  (`use_build_context_synchronously`, `use_key_in_widget_constructors`,
  `no_logic_in_create_state` among them); the code passed all of them without
  a change.

## 0.2.0

- **Behavior change:** `ViewModelProvider` now creates its view model in
  `initState` instead of lazily on first build. This fixes a latent bug where a
  throwing `create` (or a throw during the first build) re-ran `create` a second
  time during `dispose`, masking the original error. The view model is now
  created exactly once.
- **Behavior change:** `context.readVm<VM>()`, `Consumer`, and `Selector` now
  throw a descriptive `FlutterError` when no matching `ViewModelProvider` is in
  scope — in both debug and release builds. Previously this was a debug-only
  `assert`, so release builds surfaced an opaque null-check error instead.
- Documented that `Consumer`/`Selector` resolve the view model by **state type**
  (nearest provider wins), whereas `readVm` resolves by view-model type — use a
  dedicated state class per provider.
- Tooling: bumped the `lints` dev-dependency to `^6.1.0` and enabled the
  `directives_ordering` and `always_declare_return_types` lints. No change to the
  supported SDK floor (`Dart >=3.0.0`, `Flutter >=3.10.0`).

## 0.1.0

Initial release.

- `ViewModel<S>` — `ChangeNotifier`-based base class with immutable state,
  `mounted` lifecycle flag, and a `bindStream` helper for "subscribe once,
  listen forever" patterns.
- `ViewModelProvider<VM, S>` — widget that creates, scopes, and disposes a
  view model for a subtree. Supports either `child` or `builder`.
- `Consumer<S>` — rebuilds on every state change.
- `Selector<S, T>` — rebuilds only when a derived projection changes;
  supports a custom `shouldRebuild` for value-equality-less types.
- `BuildContext.readVm<VM>()` — retrieves the view model without subscribing.
