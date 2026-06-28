part of 'widgets.dart';

/// Creates and owns a [ViewModel] for a subtree.
///
/// On insertion, calls [create] to instantiate the view model. On removal,
/// calls [ViewModel.dispose] automatically.
///
/// Within the subtree:
///
/// * `context.readVm<VM>()` returns the view model (no subscription).
/// * [Consumer] rebuilds on every state change.
/// * [Selector] rebuilds only when its projection changes.
///
/// {@tool snippet}
/// ```dart
/// ViewModelProvider<CounterViewModel, int>(
///   create: (_) => CounterViewModel(),
///   child: const CounterPage(),
/// )
/// ```
/// {@end-tool}
///
/// You can use either [child] (recommended for static subtrees) or [builder]
/// (when the immediate child needs access to the just-created view model via
/// `context`). Pass exactly one.
class ViewModelProvider<VM extends ViewModel<S>, S> extends StatefulWidget {
  /// Creates a provider that instantiates [VM] via [create] and exposes it to
  /// the subtree. Pass either [child] or [builder].
  const ViewModelProvider({
    super.key,
    required this.create,
    this.builder,
    this.child,
  }) : assert(
          (child == null) != (builder == null),
          'Pass exactly one of `child` or `builder`.',
        );

  /// Factory invoked once when this widget is mounted. Use the provided
  /// [BuildContext] to resolve dependencies (e.g. from a service locator).
  final VM Function(BuildContext context) create;

  /// Builds the subtree with access to the [BuildContext] that sees the new
  /// view model. Useful when the subtree calls `context.readVm<VM>()`
  /// directly.
  final Widget Function(BuildContext context)? builder;

  /// The static subtree placed below this provider.
  final Widget? child;

  @override
  State<ViewModelProvider<VM, S>> createState() =>
      _ViewModelProviderState<VM, S>();
}

class _ViewModelProviderState<VM extends ViewModel<S>, S>
    extends State<ViewModelProvider<VM, S>> {
  VM? _vm;

  @override
  void initState() {
    super.initState();
    _vm = widget.create(context);
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _VmScope<VM>(
        viewModel: _vm!,
        child: _StateScope<S>(
          viewModel: _vm!,
          child: widget.child ?? Builder(builder: widget.builder!),
        ),
      );
}
