part of 'widgets.dart';

/// Signature of [ViewModelBuilder.builder].
///
/// Receives the [BuildContext], the current [state], and the optional
/// pre-built [child] passed through unchanged on every rebuild for
/// optimization.
typedef ViewModelWidgetBuilder<S> =
    Widget Function(BuildContext context, S state, Widget? child);

/// Rebuilds whenever the surrounding [ViewModel] of state type [S] notifies a
/// change.
///
/// Resolves the view model by **state type [S]** — the nearest enclosing
/// [ViewModelProvider] whose view model is a `ViewModel<S>`. Give each provider
/// a dedicated state class; never key a [ViewModelBuilder] on a primitive
/// (`int`, `String`) or on a state type shared by nested providers, or the
/// nearest — possibly wrong — view model is bound silently.
///
/// Use [ViewModelBuilder] when the widget genuinely depends on the full state
/// object (or on multiple fields with cross-dependencies). For a single derived
/// value, prefer [ViewModelSelector] — it only rebuilds when the selected
/// projection changes.
///
/// Optionally pass a [child] that is built once and forwarded into [builder]
/// on every rebuild — useful for expensive static subtrees that don't depend
/// on state.
///
/// {@tool snippet}
/// ```dart
/// ViewModelBuilder<ProfilePageState>(
///   builder: (context, state, _) => Text('Hello, ${state.userName}'),
/// )
/// ```
/// {@end-tool}
class ViewModelBuilder<S> extends StatefulWidget {
  /// Creates a builder that rebuilds on state changes accepted by [buildWhen].
  const ViewModelBuilder({
    super.key,
    required this.builder,
    this.buildWhen,
    this.child,
  });

  /// Builds the widget tree from the current state.
  final ViewModelWidgetBuilder<S> builder;

  /// Filters which state changes rebuild. Receives the state this widget was
  /// last built with and the incoming one; defaults to all of them.
  ///
  /// Not consulted for the first build — the widget has to render something —
  /// so a condition that always returns `false` renders once, then freezes.
  final ViewModelBuilderCondition<S>? buildWhen;

  /// An optional pre-built subtree passed through to [builder] on every
  /// rebuild. Use for static parts of the UI that should not be rebuilt.
  final Widget? child;

  @override
  State<ViewModelBuilder<S>> createState() => _ViewModelBuilderState<S>();
}

class _ViewModelBuilderState<S> extends State<ViewModelBuilder<S>> {
  ViewModel<S>? _vm;
  late S _state;

  void _onChange() {
    if (!mounted) return;
    final next = _vm!.state;
    // `_state` is the state on screen, not the last one seen: a change this
    // widget declined to build stays declined, so a later comparison is made
    // against what the user can actually see.
    if (widget.buildWhen?.call(_state, next) ?? true) {
      setState(() => _state = next);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _dependOnViewModel<S>(context);
    if (identical(next, _vm)) return;
    _vm?.removeListener(_onChange);
    _vm = next?..addListener(_onChange);
    if (next != null) _state = next.state;
  }

  @override
  void didUpdateWidget(covariant ViewModelBuilder<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A gate that stopped declining changes has to let the current state
    // through, or the widget stays frozen until the next notification.
    final vm = _vm;
    if (vm == null || identical(widget.buildWhen, oldWidget.buildWhen)) return;
    final next = vm.state;
    if (widget.buildWhen?.call(_state, next) ?? true) _state = next;
  }

  @override
  void dispose() {
    _vm?.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _vm == null
      ? _missingProvider('ViewModelBuilder<$S>', S)
      : widget.builder(context, _state, widget.child);
}
