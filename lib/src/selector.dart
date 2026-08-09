part of 'widgets.dart';

/// Signature of [ViewModelSelector.selector] — projects state [S] to a value
/// [T].
typedef StateProjection<S, T> = T Function(S state);

/// Signature of [ViewModelSelector.builder] — receives the selected [value] and
/// the optional pre-built [child].
typedef SelectorWidgetBuilder<T> =
    Widget Function(BuildContext context, T value, Widget? child);

/// Signature of [ViewModelSelector.buildWhen] — decides whether the builder
/// should run for a newly projected value.
///
/// Return `true` to rebuild, `false` to skip. When omitted, the projected
/// values are compared with `==`.
typedef ViewModelBuilderCondition<T> = bool Function(T previous, T next);

/// Rebuilds the [builder] only when [selector] produces a value distinct from
/// the previous one.
///
/// Use [ViewModelSelector] to extract a single derived value from a larger
/// state object and avoid rebuilding the subtree on unrelated state changes.
///
/// Resolves the view model by **state type [S]** — the nearest enclosing
/// [ViewModelProvider] whose view model is a `ViewModel<S>`. Give each provider
/// a dedicated state class; never key a [ViewModelSelector] on a primitive
/// (`int`, `String`) or on a state type shared by nested providers, or the
/// nearest — possibly wrong — view model is bound silently.
///
/// Equality is checked with `==` by default. For collections without value
/// equality, pass [buildWhen] (e.g.
/// `buildWhen: (a, b) => !const ListEquality().equals(a, b)` — `ListEquality`
/// comes from `package:collection`).
///
/// {@tool snippet}
/// ```dart
/// ViewModelSelector<ProfilePageState, String>(
///   selector: (state) => state.userName,
///   builder: (context, name, _) => Text(name),
/// )
/// ```
/// {@end-tool}
class ViewModelSelector<S, T> extends StatefulWidget {
  /// Creates a selector that rebuilds only when the projected value changes.
  const ViewModelSelector({
    super.key,
    required this.selector,
    required this.builder,
    this.buildWhen,
    this.child,
  });

  /// Projects the full state to the value that drives rebuilds.
  ///
  /// Should be a pure, cheap function — it runs on every state change.
  final StateProjection<S, T> selector;

  /// Builds the widget tree from the selected value.
  final SelectorWidgetBuilder<T> builder;

  /// Custom comparison for the projected value. Defaults to `==`.
  ///
  /// Not consulted for the first build: the initial projection is always
  /// rendered, and the gate applies to later changes.
  final ViewModelBuilderCondition<T>? buildWhen;

  /// An optional pre-built subtree passed through to [builder] on every
  /// rebuild.
  final Widget? child;

  @override
  State<ViewModelSelector<S, T>> createState() =>
      _ViewModelSelectorState<S, T>();
}

class _ViewModelSelectorState<S, T> extends State<ViewModelSelector<S, T>> {
  ViewModel<S>? _vm;
  late T _value;

  bool _shouldRebuild(T previous, T next) =>
      widget.buildWhen?.call(previous, next) ?? previous != next;

  void _onChange() {
    if (!mounted) return;
    final next = widget.selector(_vm!.state);
    if (!_shouldRebuild(_value, next)) return;
    setState(() => _value = next);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _dependOnViewModel<S>(context);
    if (identical(next, _vm)) return;
    _vm?.removeListener(_onChange);
    _vm = next?..addListener(_onChange);
    if (next != null) _value = widget.selector(next.state);
  }

  @override
  void didUpdateWidget(covariant ViewModelSelector<S, T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new selector closure — which an inline lambda is on every parent
    // rebuild — goes through the same [buildWhen] gate as a state change, so a
    // selector used to freeze a subtree keeps freezing it.
    if (_vm == null || identical(widget.selector, oldWidget.selector)) return;
    final next = widget.selector(_vm!.state);
    if (_shouldRebuild(_value, next)) _value = next;
  }

  @override
  void dispose() {
    _vm?.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _vm == null
      ? _missingProvider('ViewModelSelector<$S, $T>', S)
      : widget.builder(context, _value, widget.child);
}
