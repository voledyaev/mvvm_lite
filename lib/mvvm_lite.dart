/// A tiny, zero-dependency MVVM toolkit for Flutter.
///
/// Exposes:
///
/// * [ViewModel] — `ChangeNotifier`-based base class with immutable state,
///   mounted lifecycle tracking, and a `bindStream` helper.
/// * [ViewModelProvider] — widget that creates, scopes, and disposes a view
///   model for a subtree.
/// * [Consumer] — rebuilds on every state change.
/// * [Selector] — rebuilds only when a derived projection changes.
/// * `BuildContext.readVm<VM>()` — retrieves the view model without
///   subscribing (use for invoking methods).
library;

export 'src/view_model.dart';
export 'src/widgets.dart';
