part of 'widgets.dart';

/// Signature of [Selector.selector] — projects state [S] to a value [T].
typedef StateSelector<S, T> = T Function(S state);

/// Signature of [Selector.builder] — receives the selected [value] and the
/// optional pre-built [child].
typedef SelectorBuilder<T> = Widget Function(
  BuildContext context,
  T value,
  Widget? child,
);

/// Signature of [Selector.shouldRebuild] — decides whether the builder should
/// run after the projected value changed by reference or by `==`.
///
/// Return `true` to trigger a rebuild, `false` to skip it. Defaults to `==`
/// equality (used when this callback is omitted).
typedef SelectorShouldRebuild<T> = bool Function(T previous, T next);

/// Rebuilds the [builder] only when [selector] produces a value distinct from
/// the previous one.
///
/// Use [Selector] to extract a single derived value from a larger state
/// object and avoid rebuilding the subtree on unrelated state changes.
///
/// Equality is checked with `==` by default. For collections without value
/// equality, pass [shouldRebuild] (e.g.
/// `shouldRebuild: (a, b) => !const ListEquality().equals(a, b)`).
///
/// {@tool snippet}
/// ```dart
/// Selector<ProfilePageState, String>(
///   selector: (state) => state.userName,
///   builder: (context, name, _) => Text(name),
/// )
/// ```
/// {@end-tool}
class Selector<S, T> extends StatefulWidget {
  /// Creates a selector that rebuilds only when the projected value changes.
  const Selector({
    super.key,
    required this.selector,
    required this.builder,
    this.shouldRebuild,
    this.child,
  });

  /// Projects the full state to the value that drives rebuilds.
  ///
  /// Should be a pure, cheap function — it runs on every state change.
  final StateSelector<S, T> selector;

  /// Builds the widget tree from the selected value.
  final SelectorBuilder<T> builder;

  /// Custom equality check for the projected value. Defaults to `==`.
  final SelectorShouldRebuild<T>? shouldRebuild;

  /// An optional pre-built subtree passed through to [builder] on every
  /// rebuild.
  final Widget? child;

  @override
  State<Selector<S, T>> createState() => _SelectorState<S, T>();
}

class _SelectorState<S, T> extends State<Selector<S, T>> {
  ViewModel<S>? _vm;
  late T _value;
  var _initialized = false;

  void _onChange() {
    final next = widget.selector(_vm!.state);
    final unchanged = widget.shouldRebuild != null
        ? !widget.shouldRebuild!(_value, next)
        : _value == next;
    if (unchanged) return;
    setState(() => _value = next);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.dependOnInheritedWidgetOfExactType<_StateScope<S>>();
    assert(
      scope != null,
      'Selector<$S, $T>: no ViewModelProvider with state type $S found above '
      'this BuildContext.',
    );
    final next = scope!.viewModel;
    if (!identical(next, _vm)) {
      _vm?.removeListener(_onChange);
      _vm = next..addListener(_onChange);
      _value = widget.selector(next.state);
      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(covariant Selector<S, T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initialized && !identical(widget.selector, oldWidget.selector)) {
      _value = widget.selector(_vm!.state);
    }
  }

  @override
  void dispose() {
    _vm?.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _value, widget.child);
}
