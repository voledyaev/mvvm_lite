import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_lite/mvvm_lite.dart';

class _FormState {
  const _FormState({required this.name, required this.age});

  final String name;
  final int age;

  _FormState copyWith({String? name, int? age}) =>
      _FormState(name: name ?? this.name, age: age ?? this.age);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FormState && other.name == name && other.age == age;

  @override
  int get hashCode => Object.hash(name, age);
}

class _FormVm extends ViewModel<_FormState> {
  _FormVm() : super(const _FormState(name: 'Alice', age: 30));

  void setName(String value) => state = state.copyWith(name: value);
  void setAge(int value) => state = state.copyWith(age: value);

  // Exposes the protected `hasListeners` flag for leak/subscription tests.
  bool get hasAnyListeners => hasListeners;
}

void main() {
  group('Selector', () {
    testWidgets('builds with the selected value', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_FormVm, _FormState>(
            create: (_) => _FormVm(),
            child: Selector<_FormState, String>(
              selector: (state) => state.name,
              builder: (_, name, __) => Text('name=$name'),
            ),
          ),
        ),
      );
      expect(find.text('name=Alice'), findsOneWidget);
    });

    testWidgets('does NOT rebuild when an unrelated field changes',
        (tester) async {
      late _FormVm vm;
      var buildCount = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_FormVm, _FormState>(
            create: (_) {
              vm = _FormVm();
              return vm;
            },
            child: Selector<_FormState, String>(
              selector: (state) => state.name,
              builder: (_, name, __) {
                buildCount++;
                return Text('name=$name');
              },
            ),
          ),
        ),
      );
      expect(buildCount, 1);

      // Change a field that the selector doesn't watch — no rebuild expected.
      vm.setAge(31);
      await tester.pump();
      expect(buildCount, 1);

      // Now change the watched field — rebuild expected.
      vm.setName('Bob');
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('name=Bob'), findsOneWidget);
    });

    testWidgets('shouldRebuild override controls rebuilds for collections',
        (tester) async {
      late _ListVm vm;
      var buildCount = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_ListVm, List<int>>(
            create: (_) {
              vm = _ListVm();
              return vm;
            },
            child: Selector<List<int>, List<int>>(
              selector: (state) => state,
              shouldRebuild: (a, b) {
                if (a.length != b.length) return true;
                for (var i = 0; i < a.length; i++) {
                  if (a[i] != b[i]) return true;
                }
                return false;
              },
              builder: (_, list, __) {
                buildCount++;
                return Text('len=${list.length}');
              },
            ),
          ),
        ),
      );
      expect(buildCount, 1);

      // Replace with structurally equal list — should NOT rebuild.
      vm.replace([1, 2, 3]);
      await tester.pump();
      expect(buildCount, 1);

      // Now structurally different — should rebuild.
      vm.replace([1, 2, 3, 4]);
      await tester.pump();
      expect(buildCount, 2);
    });

    testWidgets('throws a FlutterError when no provider is in scope',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Selector<_FormState, String>(
            selector: (state) => state.name,
            builder: (_, name, __) => Text('name=$name'),
          ),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('recomputes the value when the selector callback changes',
        (tester) async {
      Widget build(StateSelector<_FormState, String> selector) =>
          Directionality(
            textDirection: TextDirection.ltr,
            child: ViewModelProvider<_FormVm, _FormState>(
              create: (_) => _FormVm(),
              child: Selector<_FormState, String>(
                selector: selector,
                builder: (_, value, __) => Text('value=$value'),
              ),
            ),
          );

      await tester.pumpWidget(build((state) => state.name));
      expect(find.text('value=Alice'), findsOneWidget);

      // New selector closure, same view model, no state change — the displayed
      // value must update via didUpdateWidget.
      await tester.pumpWidget(build((state) => 'age=${state.age}'));
      expect(find.text('value=age=30'), findsOneWidget);
    });

    testWidgets('static child is reused across rebuilds', (tester) async {
      late _FormVm vm;
      const childKey = ValueKey('static-child');
      Widget? first;
      Widget? second;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_FormVm, _FormState>(
            create: (_) {
              vm = _FormVm();
              return vm;
            },
            child: Selector<_FormState, String>(
              selector: (state) => state.name,
              child: const SizedBox(key: childKey),
              builder: (_, name, child) {
                if (name == 'Alice') first = child;
                if (name == 'Bob') second = child;
                return child!;
              },
            ),
          ),
        ),
      );
      vm.setName('Bob');
      await tester.pump();

      expect(identical(first, second), isTrue);
    });

    testWidgets('re-subscribes when moved to a different provider',
        (tester) async {
      final selectorKey = GlobalKey();
      late _FormVm vmA;
      late _FormVm vmB;

      Widget selector() => Selector<_FormState, String>(
            key: selectorKey,
            selector: (state) => state.name,
            builder: (_, name, __) => Text('name=$name'),
          );
      Widget build({required bool underA}) => Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                ViewModelProvider<_FormVm, _FormState>(
                  create: (_) => vmA = _FormVm(),
                  child: underA ? selector() : const SizedBox(),
                ),
                ViewModelProvider<_FormVm, _FormState>(
                  create: (_) => vmB = (_FormVm()..setName('Bob')),
                  child: underA ? const SizedBox() : selector(),
                ),
              ],
            ),
          );

      await tester.pumpWidget(build(underA: true));
      expect(find.text('name=Alice'), findsOneWidget);
      expect(vmA.hasAnyListeners, isTrue);
      expect(vmB.hasAnyListeners, isFalse);

      await tester.pumpWidget(build(underA: false));
      expect(find.text('name=Bob'), findsOneWidget);
      expect(vmA.hasAnyListeners, isFalse);
      expect(vmB.hasAnyListeners, isTrue);
    });
  });
}

class _ListVm extends ViewModel<List<int>> {
  _ListVm() : super(const [1, 2, 3]);
  void replace(List<int> next) => state = List.unmodifiable(next);
}
