import 'dart:async';

import 'package:flutter/foundation.dart';

/// Base class for view models holding an immutable state of type [S].
///
/// Extends [ChangeNotifier] and adds:
///
/// * [state] — the current immutable state, replaced (not mutated) via the
///   protected setter; assignment triggers [notifyListeners] only when the new
///   state is not equal to the previous one, and throws once the view model is
///   disposed.
/// * [mounted] — `true` until [dispose] is called. Always check `if (!mounted)
///   return;` after any `await` to avoid mutating state on a disposed view
///   model.
/// * [ValueListenable] conformance — a view model can be handed to
///   `ValueListenableBuilder`, `ListenableBuilder` or anything else in the
///   framework that accepts one.
/// * [bindStream] — convenience helper that subscribes to a stream for the
///   lifetime of the view model and cancels the subscription in [dispose]. The
///   callbacks are skipped automatically once the view model is disposed.
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
abstract class ViewModel<S> extends ChangeNotifier
    implements ValueListenable<S> {
  /// Creates a view model with the given initial [state].
  ViewModel(this._state);

  S _state;
  var _mounted = true;
  final _subscriptions = <StreamSubscription<void>>[];

  /// The current immutable state.
  S get state => _state;

  /// The current state, as required by [ValueListenable].
  ///
  /// Exists so a view model can be passed to `ValueListenableBuilder` and
  /// friends. Prefer [state] everywhere else — it is the name the rest of this
  /// package uses.
  @override
  S get value => _state;

  /// Replaces the current state. Triggers [notifyListeners] only if
  /// `newState != state` (uses `==`).
  ///
  /// Throws a [FlutterError] — in both debug and release builds — when called
  /// after [dispose]; the state is left untouched. Guard async work with
  /// `if (!mounted) return;` after every `await`.
  ///
  /// Protected; only subclasses can write state.
  @protected
  set state(S newState) {
    if (!_mounted) {
      throw FlutterError(
        '${describeIdentity(this)}: state was written after dispose().\n'
        'Add `if (!mounted) return;` after every await in this view model, or '
        'cancel the work that produced this write before disposing.',
      );
    }
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  /// `true` until [dispose] is called.
  ///
  /// Check `if (!mounted) return;` after every `await` before writing [state].
  bool get mounted => _mounted;

  /// Subscribes to [stream] for the lifetime of this view model.
  ///
  /// All three callbacks are skipped once disposed, and the subscription is
  /// cancelled in [dispose]. The returned subscription can be cancelled
  /// earlier; cancelling twice is a no-op.
  ///
  /// Without [onError] a stream error follows Dart's default and reaches the
  /// surrounding [Zone] instead of this view model.
  ///
  /// Throws a [FlutterError] after [dispose] — such a subscription would never
  /// be cancelled.
  @protected
  StreamSubscription<E> bindStream<E>(
    Stream<E> stream,
    void Function(E event) onData, {
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) {
    if (!_mounted) {
      throw FlutterError(
        '${describeIdentity(this)}: bindStream was called after dispose(). '
        'The subscription would never be cancelled.',
      );
    }
    final subscription = stream.listen(
      (event) {
        if (!_mounted) return;
        onData(event);
      },
      onError: onError == null
          ? null
          : (Object error, StackTrace stackTrace) {
              if (!_mounted) return;
              onError(error, stackTrace);
            },
      cancelOnError: cancelOnError,
    );
    final tracked = _TrackedSubscription<E>(subscription, _subscriptions);
    subscription.onDone(() {
      _subscriptions.remove(tracked);
      if (!_mounted) return;
      onDone?.call();
    });
    _subscriptions.add(tracked);
    return tracked;
  }

  @override
  String toString() => '${describeIdentity(this)}($state)';

  @override
  void dispose() {
    _mounted = false;
    // Cleared first: cancelling a tracked subscription asks this list to forget
    // it, which would otherwise mutate it mid-iteration.
    final subscriptions = List.of(_subscriptions);
    _subscriptions.clear();
    for (final subscription in subscriptions) {
      // A stream whose onCancel throws must not skip the remaining
      // cancellations or super.dispose(), and must not surface as an uncaught
      // asynchronous error either — dispose has no caller to catch it.
      try {
        subscription.cancel().ignore();
      } on Object {
        continue;
      }
    }
    super.dispose();
  }
}

/// The [StreamSubscription] handed back by [ViewModel.bindStream].
///
/// Delegates everything to the real subscription and tells the view model to
/// forget it once cancelled, so a view model that binds and cancels repeatedly
/// does not accumulate dead subscriptions until it is disposed.
class _TrackedSubscription<E> implements StreamSubscription<E> {
  _TrackedSubscription(this._inner, this._owner);

  final StreamSubscription<E> _inner;
  final List<StreamSubscription<void>> _owner;

  @override
  Future<void> cancel() {
    _owner.remove(this);
    return _inner.cancel();
  }

  @override
  void onData(void Function(E data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(() {
    _owner.remove(this);
    handleDone?.call();
  });

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<X> asFuture<X>([X? futureValue]) =>
      // asFuture replaces the inner done and error handlers, taking the
      // bookkeeping with them; whenComplete puts it back.
      _inner.asFuture<X>(futureValue).whenComplete(() => _owner.remove(this));
}
