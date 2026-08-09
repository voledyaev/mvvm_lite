/// Widget primitives that scope a [ViewModel] to a subtree and expose its
/// state for granular consumption.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'view_model.dart';

part 'view_model_provider.dart';
part 'builder.dart';
part 'selector.dart';
part 'listener.dart';

/// `InheritedWidget` that exposes a [ViewModel] below a [ViewModelProvider].
///
/// Not generic on purpose: lookups match by assignability rather than exact
/// generic type, so a fake subclass injected through [ViewModelProvider.value]
/// still answers to the real view-model type.
class _ViewModelScope extends InheritedWidget {
  const _ViewModelScope({required this.viewModel, required super.child});

  final ViewModel<Object?> viewModel;

  @override
  bool updateShouldNotify(_ViewModelScope oldWidget) =>
      !identical(oldWidget.viewModel, viewModel);
}

/// Nearest [_ViewModelScope] above [context] whose view model satisfies
/// [test], or `null`. Registers no dependency.
InheritedElement? _findScope(
  BuildContext context,
  bool Function(ViewModel<Object?> viewModel) test,
) {
  InheritedElement? found;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is _ViewModelScope && test(widget.viewModel)) {
      found = element as InheritedElement;
      return false;
    }
    return true;
  });
  return found;
}

/// Subscribes [context] to the nearest provider whose view model has state
/// type [S], or returns `null` when there is none.
///
/// Returning rather than throwing matters: this runs from
/// `didChangeDependencies`, which is outside the framework's build-error
/// recovery. A throw from there leaves the element permanently unbuilt instead
/// of showing an error widget, so callers report the failure from `build`.
ViewModel<S>? _dependOnViewModel<S>(BuildContext context) {
  final element = _findScope(context, (viewModel) => viewModel is ViewModel<S>);
  if (element == null) return null;
  context.dependOnInheritedElement(element);
  return (element.widget as _ViewModelScope).viewModel as ViewModel<S>;
}

/// The error every consumer widget raises from `build` when it found no
/// provider to bind to.
Never _missingProvider(String widgetDescription, Type stateType) =>
    throw FlutterError(
      '$widgetDescription: no ViewModelProvider with state type $stateType '
      'found above this BuildContext.',
    );

/// Extensions on [BuildContext] for retrieving view models from the tree.
extension MvvmLiteContext on BuildContext {
  /// Retrieves the nearest [ViewModel] assignable to [VM] from the widget tree
  /// without subscribing to it. Use this to invoke methods on the view model
  /// from event handlers and effects.
  ///
  /// Matching is by assignability, so a subclass — a fake handed to
  /// [ViewModelProvider.value] in a test — is found by its base type.
  ///
  /// Rebuilds are driven exclusively by [ViewModelBuilder],
  /// [ViewModelSelector] and [ViewModelListener], so there is no `watch`
  /// counterpart to confuse this with.
  ///
  /// Throws a [FlutterError] if no matching [ViewModelProvider] is found above
  /// this context — in both debug and release builds.
  VM viewModel<VM extends ViewModel<Object?>>() {
    final element = _findScope(this, (viewModel) => viewModel is VM);
    if (element == null) {
      throw FlutterError(
        'context.viewModel<$VM>(): no ViewModelProvider exposing a $VM found '
        'above this BuildContext. Did you call it outside the provider '
        'subtree, or with the wrong view-model type?',
      );
    }
    return (element.widget as _ViewModelScope).viewModel as VM;
  }
}
