import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_lite/mvvm_lite.dart';

class _CounterVm extends ViewModel<int> {
  _CounterVm() : super(0);

  var disposed = false;
  void increment() => state = state + 1;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  group('ViewModelProvider', () {
    testWidgets('creates the VM eagerly and exposes it via readVm',
        (tester) async {
      _CounterVm? captured;
      await tester.pumpWidget(
        ViewModelProvider<_CounterVm, int>(
          create: (_) => _CounterVm(),
          builder: (context) {
            captured = context.readVm<_CounterVm>();
            return const SizedBox();
          },
        ),
      );
      expect(captured, isNotNull);
      expect(captured!.state, 0);
    });

    testWidgets('disposes the VM when removed from the tree', (tester) async {
      late _CounterVm vm;
      await tester.pumpWidget(
        ViewModelProvider<_CounterVm, int>(
          create: (_) {
            vm = _CounterVm();
            return vm;
          },
          child: const SizedBox(),
        ),
      );

      expect(vm.disposed, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(vm.disposed, isTrue);
    });

    testWidgets('readVm throws when no provider is in scope', (tester) async {
      BuildContext? captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      );
      expect(() => captured!.readVm<_CounterVm>(), throwsAssertionError);
    });

    testWidgets('child and builder are mutually exclusive', (tester) async {
      expect(
        () => ViewModelProvider<_CounterVm, int>(
          create: (_) => _CounterVm(),
        ),
        throwsAssertionError,
      );
    });
  });
}
