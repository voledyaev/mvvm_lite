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
