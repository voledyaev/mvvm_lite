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
  group('ViewModelSelector', () {
    testWidgets('builds with the selected value', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_FormVm>(
            create: (_) => _FormVm(),
            child: ViewModelSelector<_FormState, String>(
              selector: (state) => state.name,
              builder: (_, name, _) => Text('name=$name'),
            ),
          ),
        ),
      );
      expect(find.text('name=Alice'), findsOneWidget);
    });

    testWidgets('does NOT rebuild when an unrelated field changes', (
      tester,
    ) async {
      late _FormVm vm;
      var buildCount = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_FormVm>(
            create: (_) {
              vm = _FormVm();
              return vm;
            },
            child: ViewModelSelector<_FormState, String>(
              selector: (state) => state.name,
              builder: (_, name, _) {
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

    testWidgets('buildWhen override controls rebuilds for collections', (
      tester,
    ) async {
      late _ListVm vm;
      var buildCount = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider<_ListVm>(
            create: (_) {
              vm = _ListVm();
              return vm;
            },
            child: ViewModelSelector<List<int>, List<int>>(
              selector: (state) => state,
              buildWhen: (a, b) {
                if (a.length != b.length) return true;
                for (var i = 0; i < a.length; i++) {
                  if (a[i] != b[i]) return true;
                }
                return false;
              },
              builder: (_, list, _) {
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

    testWidgets('buildWhen also gates values arriving from a parent rebuild', (
      tester,
    ) async {
      // An inline selector closure is never identical across rebuilds, so a
      // parent rebuild used to slip a new value past buildWhen entirely.
      late _FormVm vm;
      final rendered = <String>[];

      Widget build() => Directionality(
        textDirection: TextDirection.ltr,
        child: ViewModelProvider<_FormVm>(
          create: (_) => vm = _FormVm(),
          child: ViewModelSelector<_FormState, String>(
            selector: (state) => state.name,
            buildWhen: (previous, next) => false,
            builder: (_, name, _) {
              rendered.add(name);
              return Text(name);
            },
          ),
        ),
      );

      await tester.pumpWidget(build());
      expect(rendered, ['Alice']);

      vm.setName('Bob');
      await tester.pump();
      expect(rendered, ['Alice']);

      // Same tree, fresh closures. The parent rebuild reaches the builder, but
      // it must carry the frozen value — before, the new closure's result was
      // adopted without consulting buildWhen at all.
      await tester.pumpWidget(build());
      expect(rendered, isNot(contains('Bob')));
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('throws a FlutterError when no provider is in scope', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelSelector<_FormState, String>(
            selector: (state) => state.name,
            builder: (_, name, _) => Text('name=$name'),
          ),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('recomputes the value when the selector callback changes', (
      tester,
    ) async {
      Widget build(StateProjection<_FormState, String> selector) =>
          Directionality(
            textDirection: TextDirection.ltr,
            child: ViewModelProvider<_FormVm>(
              create: (_) => _FormVm(),
              child: ViewModelSelector<_FormState, String>(
                selector: selector,
                builder: (_, value, _) => Text('value=$value'),
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
          child: ViewModelProvider<_FormVm>(
            create: (_) {
              vm = _FormVm();
              return vm;
            },
            child: ViewModelSelector<_FormState, String>(
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

    testWidgets('re-subscribes when moved to a different provider', (
      tester,
    ) async {
      final selectorKey = GlobalKey();
      late _FormVm vmA;
      late _FormVm vmB;

      Widget selector() => ViewModelSelector<_FormState, String>(
        key: selectorKey,
        selector: (state) => state.name,
        builder: (_, name, _) => Text('name=$name'),
      );
      Widget build({required bool underA}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            ViewModelProvider<_FormVm>(
              create: (_) => vmA = _FormVm(),
              child: underA ? selector() : const SizedBox(),
            ),
            ViewModelProvider<_FormVm>(
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
