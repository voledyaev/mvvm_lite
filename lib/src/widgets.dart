/// Widget primitives that scope a [ViewModel] to a subtree and expose its
/// state for granular consumption.
library mvvm_lite.widgets;

import 'package:flutter/widgets.dart';

import 'view_model.dart';

part 'view_model_provider.dart';
part 'consumer.dart';
part 'selector.dart';

/// `InheritedWidget` that exposes a [ViewModel] by its concrete subtype.
///
/// Used by [BuildContext.readVm] to retrieve the view model without
/// subscribing to it.
class _VmScope<VM extends ViewModel<Object?>> extends InheritedWidget {
  const _VmScope({required this.viewModel, required super.child});

  final VM viewModel;

  @override
  bool updateShouldNotify(_VmScope<VM> oldWidget) =>
      !identical(oldWidget.viewModel, viewModel);
}

/// `InheritedWidget` that exposes a [ViewModel] keyed by its state type [S].
///
/// Looked up by [Consumer] and [Selector] without registering a dependency —
/// those widgets subscribe to the view model directly via [Listenable] so they
/// control their own rebuild semantics.
class _StateScope<S> extends InheritedWidget {
  const _StateScope({required this.viewModel, required super.child});

  final ViewModel<S> viewModel;

  @override
  bool updateShouldNotify(_StateScope<S> oldWidget) =>
      !identical(oldWidget.viewModel, viewModel);
}

/// Extensions on [BuildContext] for retrieving view models from the tree.
extension MvvmLiteContext on BuildContext {
  /// Retrieves the nearest [ViewModel] of type [VM] from the widget tree
  /// without subscribing to it. Use this to invoke methods on the view model
  /// from event handlers and effects.
  ///
  /// Throws a [FlutterError] in debug if no matching [ViewModelProvider] is
  /// found above this context.
  VM readVm<VM extends ViewModel<Object?>>() {
    final scope = getInheritedWidgetOfExactType<_VmScope<VM>>();
    assert(
      scope != null,
      'context.readVm<$VM>(): no ViewModelProvider<$VM, …> found above this '
      'BuildContext. Did you call readVm outside the provider subtree, or '
      'with the wrong view-model type?',
    );
    return scope!.viewModel;
  }
}
