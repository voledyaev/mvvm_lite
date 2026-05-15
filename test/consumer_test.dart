import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_lite/mvvm_lite.dart';

class _CounterVm extends ViewModel<int> {
  _CounterVm() : super(0);
  void increment() => state = state + 1;
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
  });
}
