import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_lite/mvvm_lite.dart';

class _CounterVm extends ViewModel<int> {
  _CounterVm() : super(0);

  void increment() => state = state + 1;
  void setTo(int value) => state = value;

  Future<void> doAsync(Completer<int> completer) async {
    final result = await completer.future;
    if (!mounted) return;
    state = result;
  }

  StreamSubscription<int> bindTo(
    Stream<int> stream, {
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
    bool cancelOnError = false,
  }) => bindStream(
    stream,
    (value) => state = value,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

void main() {
  group('ViewModel', () {
    test('starts with the initial state', () {
      final vm = _CounterVm();
      expect(vm.state, 0);
    });

    test('state setter notifies listeners on change', () {
      final vm = _CounterVm();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.increment();
      expect(vm.state, 1);
      expect(notifications, 1);

      vm.increment();
      expect(vm.state, 2);
      expect(notifications, 2);
    });

    test('state setter does NOT notify when value is equal', () {
      final vm = _CounterVm();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setTo(0); // same as initial
      expect(notifications, 0);

      vm.setTo(5);
      expect(notifications, 1);

      vm.setTo(5); // same again
      expect(notifications, 1);
    });

    test('mounted flips to false after dispose', () {
      final vm = _CounterVm();
      expect(vm.mounted, isTrue);
      vm.dispose();
      expect(vm.mounted, isFalse);
    });

    test('async writes after dispose are skipped via mounted check', () async {
      final vm = _CounterVm();
      final completer = Completer<int>();
      final future = vm.doAsync(completer);

      vm.dispose();
      completer.complete(42);
      await future;

      // state must remain 0 — write was skipped because !mounted.
      expect(vm.state, 0);
    });

    test('bindStream forwards events while mounted', () async {
      final vm = _CounterVm();
      final controller = StreamController<int>();
      vm.bindTo(controller.stream);

      controller.add(7);
      await Future<void>.delayed(Duration.zero);
      expect(vm.state, 7);

      controller.add(11);
      await Future<void>.delayed(Duration.zero);
      expect(vm.state, 11);

      await controller.close();
    });

    test('bindStream subscription is cancelled on dispose', () async {
      final vm = _CounterVm();
      final controller = StreamController<int>();
      vm.bindTo(controller.stream);

      vm.dispose();
      controller.add(99);
      await Future<void>.delayed(Duration.zero);

      // Disposed vm should not have updated state.
      expect(vm.state, 0);
      await controller.close();
    });

    test('writing state after dispose throws and leaves the state intact', () {
      final vm = _CounterVm()..setTo(3);
      var notifications = 0;
      vm.addListener(() => notifications++);
      vm.dispose();

      expect(() => vm.increment(), throwsA(isA<FlutterError>()));
      expect(vm.state, 3);
      expect(notifications, 0);
    });

    test('bindStream after dispose throws', () {
      final vm = _CounterVm()..dispose();

      expect(
        () => vm.bindTo(const Stream<int>.empty()),
        throwsA(isA<FlutterError>()),
      );
    });

    test('bindStream forwards errors to onError', () async {
      final vm = _CounterVm();
      final controller = StreamController<int>();
      Object? captured;
      vm.bindTo(controller.stream, onError: (error, _) => captured = error);

      controller.addError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(captured, isStateError);
      await controller.close();
    });

    test('bindStream skips onError and onDone after dispose', () async {
      final vm = _CounterVm();
      final controller = StreamController<int>();
      var errors = 0;
      var dones = 0;
      vm.bindTo(
        controller.stream,
        onError: (_, _) => errors++,
        onDone: () => dones++,
      );

      vm.dispose();
      controller.addError(StateError('boom'));
      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(errors, 0);
      expect(dones, 0);
    });

    test('bindStream calls onDone when the stream closes', () async {
      final vm = _CounterVm();
      final controller = StreamController<int>();
      var dones = 0;
      vm.bindTo(controller.stream, onDone: () => dones++);

      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(dones, 1);
    });

    test(
      'bindStream returns a subscription that can be cancelled early',
      () async {
        final vm = _CounterVm();
        final controller = StreamController<int>();
        final subscription = vm.bindTo(controller.stream);

        await subscription.cancel();
        controller.add(5);
        await Future<void>.delayed(Duration.zero);
        expect(vm.state, 0);

        // dispose cancels a second time — must not throw.
        vm.dispose();
        await controller.close();
      },
    );

    testWidgets('works as a ValueListenable', (tester) async {
      final vm = _CounterVm();
      addTearDown(vm.dispose);
      expect(vm.value, vm.state);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<int>(
            valueListenable: vm,
            builder: (_, value, _) => Text('value=$value'),
          ),
        ),
      );
      expect(find.text('value=0'), findsOneWidget);

      vm.increment();
      await tester.pump();
      expect(find.text('value=1'), findsOneWidget);
    });

    test('dispose cancels the source subscription, not just the callbacks', () {
      final vm = _CounterVm();
      final controller = StreamController<int>();
      vm.bindTo(controller.stream);
      expect(controller.hasListener, isTrue);

      vm.dispose();

      // The guards inside bindStream would make a "state did not change" check
      // pass even if nothing were cancelled; this asserts on the source.
      expect(controller.hasListener, isFalse);
    });

    test('dispose survives a subscription whose cancel throws', () async {
      final vm = _CounterVm();
      final throwing = StreamController<int>(
        onCancel: () => throw StateError('boom'),
      );
      final healthy = StreamController<int>();
      vm.bindTo(throwing.stream);
      vm.bindTo(healthy.stream);

      expect(vm.dispose, returnsNormally);
      expect(healthy.hasListener, isFalse);
      expect(vm.mounted, isFalse);
      await healthy.close();
    });

    test('toString includes the identity and current state', () {
      final vm = _CounterVm()..setTo(7);
      expect(vm.toString(), contains('_CounterVm'));
      expect(vm.toString(), contains('(7)'));
    });
  });
}
