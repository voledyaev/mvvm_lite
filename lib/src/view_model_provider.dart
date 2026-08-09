part of 'widgets.dart';

/// Creates and owns a [ViewModel] for a subtree.
///
/// On insertion, calls [create] to instantiate the view model. On removal,
/// calls [ViewModel.dispose] automatically.
///
/// Within the subtree:
///
/// * `context.viewModel<VM>()` returns the view model (no subscription).
/// * [ViewModelBuilder] rebuilds on every state change.
/// * [ViewModelSelector] rebuilds only when its projection changes.
/// * [ViewModelListener] runs a side effect and rebuilds nothing.
///
/// {@tool snippet}
/// ```dart
/// ViewModelProvider(
///   create: (_) => CounterViewModel(),
///   child: const CounterPage(),
/// )
/// ```
/// {@end-tool}
///
/// The single type argument is inferred from [create], so it is rarely written
/// out; `ViewModelProvider<CounterViewModel>(...)` is the explicit form. The
/// state type is not a type argument at all — the widgets below resolve a
/// provider through the runtime type of the view model it exposes.
///
/// You can use either [child] (recommended for static subtrees) or [builder]
/// (when the immediate child needs access to the just-created view model via
/// `context`). Pass exactly one.
///
/// Use [ViewModelProvider.value] to expose a view model this widget must not
/// own — most commonly a fake or pre-seeded one in a widget test.
class ViewModelProvider<VM extends ViewModel<Object?>> extends StatefulWidget {
  /// Creates a provider that instantiates [VM] via [create], owns it, and
  /// disposes it when removed. Pass either [child] or [builder].
  const ViewModelProvider({
    super.key,
    required VM Function(BuildContext context) this.create,
    this.builder,
    this.child,
  }) : value = null,
       assert(
         (child == null) != (builder == null),
         'Pass exactly one of `child` or `builder`.',
       );

  /// Exposes an existing [value] to the subtree **without** taking ownership of
  /// it: [ViewModel.dispose] is never called for it.
  ///
  /// This is the constructor for widget tests — pump a page with a fake or
  /// pre-seeded view model, drive it directly, and dispose it from the test
  /// (`addTearDown(vm.dispose)`). A fake that subclasses the real view model is
  /// found by `context.viewModel<RealViewModel>()`, because lookups match by
  /// assignability.
  ///
  /// Do not pass a freshly constructed view model here — nothing would ever
  /// dispose it. Use the default constructor whenever this widget should own
  /// the view model's lifecycle.
  const ViewModelProvider.value({
    super.key,
    required VM this.value,
    this.builder,
    this.child,
  }) : create = null,
       assert(
         (child == null) != (builder == null),
         'Pass exactly one of `child` or `builder`.',
       );

  /// The externally owned view model passed to [ViewModelProvider.value], or
  /// `null` when this provider creates and owns its own.
  final VM? value;

  /// Factory invoked exactly once, from [State.initState].
  ///
  /// Running in `initState` allows lookups that register no inherited-widget
  /// dependency — `context.viewModel<VM>()`, `GetIt`,
  /// `Provider.of(context, listen: false)` — but not `Theme.of`,
  /// `MediaQuery.of` or `context.watch`, which throw there. Read those above
  /// this widget and pass them in.
  ///
  /// `null` when the provider was built with [ViewModelProvider.value].
  final VM Function(BuildContext context)? create;

  /// Builds the subtree with access to the [BuildContext] that sees the new
  /// view model. Useful when the subtree calls `context.viewModel<VM>()`
  /// directly.
  final Widget Function(BuildContext context)? builder;

  /// The static subtree placed below this provider.
  final Widget? child;

  @override
  State<ViewModelProvider<VM>> createState() => _ViewModelProviderState<VM>();
}

class _ViewModelProviderState<VM extends ViewModel<Object?>>
    extends State<ViewModelProvider<VM>> {
  VM? _vm;

  /// The view model this widget built itself, and the only one it may dispose.
  ///
  /// Tracked separately from [_vm] because the two diverge: a `.value` provider
  /// exposes something it must never dispose, and a provider reconfigured from
  /// `create` to `.value` may be handed back the very instance it created.
  VM? _created;

  @override
  void initState() {
    super.initState();
    final create = widget.create;
    _vm = _created = create == null ? null : create(context);
    _vm ??= widget.value;
  }

  @override
  void didUpdateWidget(covariant ViewModelProvider<VM> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final create = widget.create;
    if (create == null) {
      final value = widget.value;
      if (identical(value, _vm)) return;
      // What this widget created is no longer on display, so it is disposed —
      // unless the caller handed it straight back, which the check above
      // already excluded.
      if (!identical(_created, value)) _created?.dispose();
      _created = null;
      _vm = value;
    } else if (oldWidget.create == null) {
      // Was externally owned, now owns its own: leave the caller's view model
      // alone and build a fresh one.
      _vm = _created = create(context);
    }
  }

  @override
  void dispose() {
    _created?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ViewModelScope(viewModel: _vm!, child: _resolveChild());

  /// Mirrors the constructor assertion for release builds, where asserts are
  /// stripped and the missing argument would otherwise surface as an opaque
  /// null-check error.
  Widget _resolveChild() {
    final child = widget.child;
    final builder = widget.builder;
    if ((child == null) == (builder == null)) {
      throw FlutterError(
        'ViewModelProvider<$VM>: pass exactly one of `child` or `builder`.',
      );
    }
    return child ?? Builder(builder: builder!);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<VM>('viewModel', _vm, defaultValue: null))
      ..add(DiagnosticsProperty<Object?>('state', _vm?.state))
      ..add(
        FlagProperty(
          'owned',
          value: _created != null,
          ifTrue: 'owns the view model',
          ifFalse: 'external view model (.value)',
        ),
      );
  }
}
