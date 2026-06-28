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
