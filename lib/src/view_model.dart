import 'dart:async';

import 'package:flutter/foundation.dart';

/// Base class for view models holding an immutable state of type [S].
///
/// Extends [ChangeNotifier] and adds:
///
/// * [state] — the current immutable state, replaced (not mutated) via the
///   protected setter; assignment triggers [notifyListeners] only when the new
///   state is not equal to the previous one.
/// * [mounted] — `true` until [dispose] is called. Always check `if (!mounted)
///   return;` after any `await` to avoid mutating state on a disposed view
///   model.
/// * [bindStream] — convenience helper that subscribes to a stream for the
///   lifetime of the view model and cancels the subscription in [dispose]. The
///   handler is skipped automatically once the view model is disposed.
///
/// {@tool snippet}
/// ```dart
/// class CounterViewModel extends ViewModel<int> {
///   CounterViewModel() : super(0);
///
///   void increment() => state = state + 1;
///
///   Future<void> loadInitial() async {
///     final value = await _repo.fetch();
///     if (!mounted) return;
///     state = value;
///   }
/// }
/// ```
/// {@end-tool}
abstract class ViewModel<S> extends ChangeNotifier {
  /// Creates a view model with the given initial [state].
  ViewModel(this._state);

  S _state;
  var _mounted = true;
  final _subscriptions = <StreamSubscription<void>>[];

  /// The current immutable state.
  S get state => _state;

  /// Replaces the current state. Triggers [notifyListeners] only if
  /// `newState != state` (uses `==`).
  ///
  /// Protected; only subclasses can write state.
  @protected
  set state(S newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  /// `true` until [dispose] is called.
  ///
  /// Always check `if (!mounted) return;` after any `await` before writing to
  /// [state] — the surrounding widget may have been removed mid-flight.
  @protected
  bool get mounted => _mounted;

  /// Subscribes to [stream] for the lifetime of this view model.
  ///
  /// The [onData] callback is skipped once the view model is disposed; the
  /// subscription is cancelled automatically in [dispose]. Use this for the
  /// common "subscribe once, listen forever" pattern. If you need manual
  /// control (cancel mid-life, replace on event), keep your own
  /// [StreamSubscription] field instead.
  @protected
  void bindStream<E>(Stream<E> stream, void Function(E event) onData) {
    _subscriptions.add(
      stream.listen((event) {
        if (!_mounted) return;
        onData(event);
      }),
    );
  }

  @override
  String toString() => '${describeIdentity(this)}($state)';

  @override
  void dispose() {
    _mounted = false;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
