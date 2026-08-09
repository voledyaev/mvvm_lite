/// A tiny, zero-dependency MVVM toolkit for Flutter.
///
/// Exposes:
///
/// * [ViewModel] — `ChangeNotifier`-based base class with immutable state,
///   mounted lifecycle tracking, and a `bindStream` helper.
/// * [ViewModelProvider] — widget that creates, scopes, and disposes a view
///   model for a subtree.
/// * [ViewModelBuilder] — rebuilds on every state change.
/// * [ViewModelSelector] — rebuilds only when a derived projection changes.
/// * [ViewModelListener] — runs a side effect on state changes, rebuilding
///   nothing.
/// * `BuildContext.viewModel<VM>()` — retrieves the view model without
///   subscribing (use for invoking methods).
library;

export 'src/view_model.dart';
export 'src/widgets.dart';
