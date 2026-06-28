import 'dart:async';

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

  void bindTo(Stream<int> stream) => bindStream(stream, (value) {
        state = value;
      });

  // Expose protected `mounted` for tests.
  bool get isMounted => mounted;
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
      expect(vm.isMounted, isTrue);
      vm.dispose();
      expect(vm.isMounted, isFalse);
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

    test('toString includes the identity and current state', () {
      final vm = _CounterVm()..setTo(7);
      expect(vm.toString(), contains('_CounterVm'));
      expect(vm.toString(), contains('(7)'));
    });
  });
}
