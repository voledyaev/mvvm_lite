import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_lite/mvvm_lite.dart';

class _CounterVm extends ViewModel<int> {
  _CounterVm() : super(0);
  void increment() => state = state + 1;

  // Exposes the protected `hasListeners` flag for leak/subscription tests.
  bool get hasAnyListeners => hasListeners;
}

void main() {
  group('Consumer', () {
    testWidgets('builds with the current state', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_CounterVm, int>(
            create: (_) => _CounterVm(),
            child: Consumer<int>(
              builder: (_, state, __) => Text('value=$state'),
            ),
          ),
        ),
      );

      expect(find.text('value=0'), findsOneWidget);
    });

    testWidgets('rebuilds on every state change', (tester) async {
      late _CounterVm vm;
      var buildCount = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_CounterVm, int>(
            create: (_) {
              vm = _CounterVm();
              return vm;
            },
            child: Consumer<int>(
              builder: (_, state, __) {
                buildCount++;
                return Text('value=$state');
              },
            ),
          ),
        ),
      );
      expect(buildCount, 1);

      vm.increment();
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('value=1'), findsOneWidget);

      vm.increment();
      await tester.pump();
      expect(buildCount, 3);
      expect(find.text('value=2'), findsOneWidget);
    });

    testWidgets('static child is reused across rebuilds', (tester) async {
      late _CounterVm vm;
      const childKey = ValueKey('static-child');
      Widget? capturedFirst;
      Widget? capturedSecond;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_CounterVm, int>(
            create: (_) {
              vm = _CounterVm();
              return vm;
            },
            child: Consumer<int>(
              child: const SizedBox(key: childKey),
              builder: (_, state, child) {
                if (state == 0) capturedFirst = child;
                if (state == 1) capturedSecond = child;
                return child!;
              },
            ),
          ),
        ),
      );
      vm.increment();
      await tester.pump();

      expect(identical(capturedFirst, capturedSecond), isTrue);
    });

    testWidgets('throws a FlutterError when no provider is in scope',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer<int>(
            builder: (_, state, __) => Text('value=$state'),
          ),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('re-subscribes when moved to a different provider',
        (tester) async {
      final consumerKey = GlobalKey();
      late _CounterVm vmA;
      late _CounterVm vmB;

      Widget consumer() => Consumer<int>(
            key: consumerKey,
            builder: (_, state, __) => Text('value=$state'),
          );
      Widget build({required bool underA}) => Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                ViewModelProvider<_CounterVm, int>(
                  create: (_) => vmA = (_CounterVm()..increment()),
                  child: underA ? consumer() : const SizedBox(),
                ),
                ViewModelProvider<_CounterVm, int>(
                  create: (_) => vmB = (_CounterVm()
                    ..increment()
                    ..increment()),
                  child: underA ? const SizedBox() : consumer(),
                ),
              ],
            ),
          );

      await tester.pumpWidget(build(underA: true));
      expect(find.text('value=1'), findsOneWidget);
      expect(vmA.hasAnyListeners, isTrue);
      expect(vmB.hasAnyListeners, isFalse);

      await tester.pumpWidget(build(underA: false));
      expect(find.text('value=2'), findsOneWidget);
      expect(vmA.hasAnyListeners, isFalse);
      expect(vmB.hasAnyListeners, isTrue);
    });

    testWidgets('removes its listener when removed while the provider lives',
        (tester) async {
      late _CounterVm vm;
      Widget build({required bool showConsumer}) => Directionality(
            textDirection: TextDirection.ltr,
            child: ViewModelProvider<_CounterVm, int>(
              create: (_) => vm = _CounterVm(),
              builder: (context) => showConsumer
                  ? Consumer<int>(
                      builder: (_, state, __) => Text('value=$state'),
                    )
                  : const SizedBox(),
            ),
          );

      await tester.pumpWidget(build(showConsumer: true));
      expect(vm.hasAnyListeners, isTrue);

      await tester.pumpWidget(build(showConsumer: false));
      expect(vm.hasAnyListeners, isFalse);
    });

    testWidgets('binds to the nearest provider when state types collide',
        (tester) async {
      late _CounterVm outer;
      late _CounterVm inner;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_CounterVm, int>(
            create: (_) => outer = (_CounterVm()..increment()),
            child: ViewModelProvider<_CounterVm, int>(
              create: (_) => inner = (_CounterVm()
                ..increment()
                ..increment()),
              child: Consumer<int>(
                builder: (_, state, __) => Text('value=$state'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('value=2'), findsOneWidget);
      expect(inner.hasAnyListeners, isTrue);
      expect(outer.hasAnyListeners, isFalse);
    });
  });
}
