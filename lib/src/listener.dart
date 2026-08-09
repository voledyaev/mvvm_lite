part of 'widgets.dart';

/// Signature of [ViewModelListener.listener] — runs a side effect for the new
/// [state].
typedef ViewModelWidgetListener<S> =
    void Function(BuildContext context, S state);

/// Signature of [ViewModelListener.listenWhen] — decides whether a state change
/// should run the effect.
///
/// Return `true` to run [ViewModelListener.listener], `false` to skip it.
typedef ViewModelListenerCondition<S> = bool Function(S previous, S next);

/// Runs a side effect — navigation, snack bars, dialogs, analytics — when the
/// surrounding view model of state type [S] changes. [child] is returned
/// untouched, so nothing below rebuilds.
///
/// {@tool snippet}
/// ```dart
/// ViewModelListener<ProfilePageState>(
///   listenWhen: (previous, next) =>
///       previous.profile is! AsyncError && next.profile is AsyncError,
///   listener: (context, state) => Navigator.of(context).pop(),
///   child: const ProfileBody(),
/// )
/// ```
/// {@end-tool}
///
/// Never fires for the state already present when this widget mounted, or when
/// a [ViewModelProvider.value] swaps in a different view model — neither is a
/// transition.
///
/// [listener] runs synchronously inside `notifyListeners()`, so navigating from
/// here is exactly as unsafe as anywhere else when a view model writes state
/// during a build. A page below the top of the navigation stack stays mounted
/// and still runs its listener; check the route before navigating.
class ViewModelListener<S> extends StatefulWidget {
  /// Creates a listener that runs [listener] on state changes accepted by
  /// [listenWhen].
  const ViewModelListener({
    super.key,
    required this.listener,
    required this.child,
    this.listenWhen,
  });

  /// The side effect to run.
  final ViewModelWidgetListener<S> listener;

  /// The subtree, returned unchanged on every state change.
  final Widget child;

  /// Filters which state changes run [listener]. Defaults to all of them.
  final ViewModelListenerCondition<S>? listenWhen;

  @override
  State<ViewModelListener<S>> createState() => _ViewModelListenerState<S>();
}

class _ViewModelListenerState<S> extends State<ViewModelListener<S>> {
  ViewModel<S>? _vm;
  late S _previous;

  void _onChange() {
    if (!mounted) return;
    final previous = _previous;
    final next = _vm!.state;
    // A view model only notifies when the state actually changed, so an equal
    // pair here means this listener already saw `next` during a re-entrant
    // notification — one raised by an effect that itself wrote state. Running
    // again would fire the effect twice for one logical change.
    if (previous == next) return;
    // Recorded before the effect runs: the effect may itself change state, and
    // the re-entrant notification must see this state as its predecessor.
    _previous = next;
    if (widget.listenWhen?.call(previous, next) ?? true) {
      widget.listener(context, next);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _dependOnViewModel<S>(context);
    if (identical(next, _vm)) return;
    _vm?.removeListener(_onChange);
    _vm = next?..addListener(_onChange);
    if (next != null) _previous = next.state;
  }

  @override
  void dispose() {
    _vm?.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _vm == null ? _missingProvider('ViewModelListener<$S>', S) : widget.child;
}
