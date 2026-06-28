part of 'widgets.dart';

/// Signature of [Consumer.builder].
///
/// Receives the [BuildContext], the current [state], and the optional
/// pre-built [child] passed through unchanged on every rebuild for
/// optimization.
typedef ConsumerBuilder<S> = Widget Function(
  BuildContext context,
  S state,
  Widget? child,
);

/// Rebuilds whenever the surrounding [ViewModel] of state type [S] notifies a
/// change.
///
/// Resolves the view model by **state type [S]** — the nearest enclosing
/// [ViewModelProvider] whose state type is [S]. Give each provider a dedicated
/// state class; never key a [Consumer] on a primitive (`int`, `String`) or on
/// a state type shared by nested providers, or the nearest — possibly wrong —
/// view model is bound silently.
///
/// Use [Consumer] when the widget genuinely depends on the full state object
/// (or on multiple fields with cross-dependencies). For a single derived
/// value, prefer [Selector] — it only rebuilds when the selected projection
/// changes.
///
/// Optionally pass a [child] that is built once and forwarded into [builder]
/// on every rebuild — useful for expensive static subtrees that don't depend
/// on state.
///
/// {@tool snippet}
/// ```dart
/// Consumer<ProfilePageState>(
///   builder: (context, state, _) => Text('Hello, ${state.userName}'),
/// )
/// ```
/// {@end-tool}
class Consumer<S> extends StatefulWidget {
  /// Creates a consumer that rebuilds on every state change.
  const Consumer({super.key, required this.builder, this.child});

  /// Builds the widget tree from the current state.
  final ConsumerBuilder<S> builder;

  /// An optional pre-built subtree passed through to [builder] on every
  /// rebuild. Use for static parts of the UI that should not be rebuilt.
  final Widget? child;

  @override
  State<Consumer<S>> createState() => _ConsumerState<S>();
}

class _ConsumerState<S> extends State<Consumer<S>> {
  ViewModel<S>? _vm;

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.dependOnInheritedWidgetOfExactType<_StateScope<S>>();
    if (scope == null) {
      throw FlutterError(
        'Consumer<$S>: no ViewModelProvider with state type $S found above '
        'this BuildContext.',
      );
    }
    final next = scope.viewModel;
    if (!identical(next, _vm)) {
      _vm?.removeListener(_onChange);
      _vm = next..addListener(_onChange);
    }
  }

  @override
  void dispose() {
    _vm?.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _vm!.state, widget.child);
}
