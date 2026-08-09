import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_lite/mvvm_lite.dart';

class _FormState {
  const _FormState({this.name = 'Alice', this.done = false});

  final String name;
  final bool done;

  _FormState copyWith({String? name, bool? done}) =>
      _FormState(name: name ?? this.name, done: done ?? this.done);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FormState && other.name == name && other.done == done;

  @override
  int get hashCode => Object.hash(name, done);
}

class _FormVm extends ViewModel<_FormState> {
  _FormVm() : super(const _FormState());

  void setName(String value) => state = state.copyWith(name: value);
  void finish() => state = state.copyWith(done: true);

  // Exposes the protected `hasListeners` flag for subscription tests.
  bool get hasAnyListeners => hasListeners;
}

void main() {
  group('ViewModelListener', () {
    testWidgets('does not fire for the state present at mount', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        ViewModelProvider<_FormVm>(
          create: (_) => _FormVm(),
          child: ViewModelListener<_FormState>(
            listener: (_, _) => calls++,
            child: const SizedBox(),
          ),
        ),
      );

      expect(calls, 0);
    });

    testWidgets('fires on every state change with the new state', (
      tester,
    ) async {
      late _FormVm vm;
      final seen = <String>[];
      await tester.pumpWidget(
        ViewModelProvider<_FormVm>(
          create: (_) => vm = _FormVm(),
          child: ViewModelListener<_FormState>(
            listener: (_, state) => seen.add(state.name),
            child: const SizedBox(),
          ),
        ),
      );

      vm.setName('Bob');
      vm.setName('Carol');
      await tester.pump();

      expect(seen, ['Bob', 'Carol']);
    });

    testWidgets('listenWhen sees the correct previous and next states', (
      tester,
    ) async {
      late _FormVm vm;
      final transitions = <String>[];
      await tester.pumpWidget(
        ViewModelProvider<_FormVm>(
          create: (_) => vm = _FormVm(),
          child: ViewModelListener<_FormState>(
            listenWhen: (previous, next) {
              transitions.add('${previous.name}->${next.name}');
              return true;
            },
            listener: (_, _) {},
            child: const SizedBox(),
          ),
        ),
      );

      vm.setName('Bob');
      vm.setName('Carol');
      await tester.pump();

      expect(transitions, ['Alice->Bob', 'Bob->Carol']);
    });

    testWidgets('edge-triggered effect fires once, level check would not', (
      tester,
    ) async {
      late _FormVm vm;
      var edgeCalls = 0;
      var levelCalls = 0;
      await tester.pumpWidget(
        ViewModelProvider<_FormVm>(
          create: (_) => vm = _FormVm(),
          child: ViewModelListener<_FormState>(
            listenWhen: (previous, next) => !previous.done && next.done,
            listener: (_, _) => edgeCalls++,
            child: ViewModelListener<_FormState>(
              listener: (_, state) {
                if (state.done) levelCalls++;
              },
              child: const SizedBox(),
            ),
          ),
        ),
      );

      vm.finish();
      await tester.pump();
      expect(edgeCalls, 1);
      expect(levelCalls, 1);

      // An unrelated change while `done` stays true: the level check fires
      // again, the edge does not. This is the bug class listenWhen prevents.
      vm.setName('Bob');
      await tester.pump();
      expect(edgeCalls, 1);
      expect(levelCalls, 2);
    });

    testWidgets('skipped effects still advance the previous state', (
      tester,
    ) async {
      late _FormVm vm;
      final transitions = <String>[];
      await tester.pumpWidget(
        ViewModelProvider<_FormVm>(
          create: (_) => vm = _FormVm(),
          child: ViewModelListener<_FormState>(
            listenWhen: (previous, next) {
              transitions.add('${previous.name}->${next.name}');
              return false;
            },
            listener: (_, _) {},
            child: const SizedBox(),
          ),
        ),
      );

      vm.setName('Bob');
      vm.setName('Carol');
      await tester.pump();

      expect(transitions, ['Alice->Bob', 'Bob->Carol']);
    });

    testWidgets('does not rebuild its child', (tester) async {
      late _FormVm vm;
      var childBuilds = 0;
      await tester.pumpWidget(
        ViewModelProvider<_FormVm>(
          create: (_) => vm = _FormVm(),
          child: ViewModelListener<_FormState>(
            listener: (_, _) {},
            child: Builder(
              builder: (_) {
                childBuilds++;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(childBuilds, 1);

      vm.setName('Bob');
      await tester.pump();

      expect(childBuilds, 1);
    });

    testWidgets('a state change made by the effect is seen as a transition', (
      tester,
    ) async {
      late _FormVm vm;
      final transitions = <String>[];
      await tester.pumpWidget(
        ViewModelProvider<_FormVm>(
          create: (_) => vm = _FormVm(),
          child: ViewModelListener<_FormState>(
            listener: (_, state) {
              transitions.add(state.name);
              // Mirrors clearing a one-shot navigation event from the effect.
              if (state.name == 'Bob') vm.setName('cleared');
            },
            child: const SizedBox(),
          ),
        ),
      );

      vm.setName('Bob');
      await tester.pump();

      expect(transitions, ['Bob', 'cleared']);
    });

    testWidgets('a sibling listener fires once per logical change', (
      tester,
    ) async {
      // The README recipe: one effect clears a one-shot event, another watches
      // a state transition. ChangeNotifier re-enters its listener list, so the
      // sibling used to be invoked twice for a single change — the second time
      // with previous == next.
      late _FormVm vm;
      final sibling = <String>[];

      await tester.pumpWidget(
        ViewModelProvider<_FormVm>(
          create: (_) => vm = _FormVm(),
          child: ViewModelListener<_FormState>(
            listener: (_, state) {
              if (state.name == 'Bob') vm.setName('cleared');
            },
            child: ViewModelListener<_FormState>(
              listener: (_, state) => sibling.add(state.name),
              child: const SizedBox(),
            ),
          ),
        ),
      );

      vm.setName('Bob');
      await tester.pump();

      expect(sibling, ['cleared']);
    });

    testWidgets('throws a FlutterError when no provider is in scope', (
      tester,
    ) async {
      await tester.pumpWidget(
        ViewModelListener<_FormState>(
          listener: (_, _) {},
          child: const SizedBox(),
        ),
      );

      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('unsubscribes when removed while the provider lives', (
      tester,
    ) async {
      late _FormVm vm;
      Widget build({required bool showListener}) => ViewModelProvider<_FormVm>(
        create: (_) => vm = _FormVm(),
        builder: (context) => showListener
            ? ViewModelListener<_FormState>(
                listener: (_, _) {},
                child: const SizedBox(),
              )
            : const SizedBox(),
      );

      await tester.pumpWidget(build(showListener: true));
      expect(vm.hasAnyListeners, isTrue);

      await tester.pumpWidget(build(showListener: false));
      expect(vm.hasAnyListeners, isFalse);
    });

    testWidgets('re-subscribes when moved to a different provider', (
      tester,
    ) async {
      final listenerKey = GlobalKey();
      late _FormVm vmA;
      late _FormVm vmB;
      final seen = <String>[];

      Widget listener() => ViewModelListener<_FormState>(
        key: listenerKey,
        listener: (_, state) => seen.add(state.name),
        child: const SizedBox(),
      );
      Widget build({required bool underA}) => Column(
        children: [
          ViewModelProvider<_FormVm>(
            create: (_) => vmA = _FormVm(),
            child: underA ? listener() : const SizedBox(),
          ),
          ViewModelProvider<_FormVm>(
            create: (_) => vmB = _FormVm(),
            child: underA ? const SizedBox() : listener(),
          ),
        ],
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: build(underA: true),
        ),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: build(underA: false),
        ),
      );

      // Swapping providers is not a state transition — nothing fires yet.
      expect(seen, isEmpty);
      expect(vmA.hasAnyListeners, isFalse);
      expect(vmB.hasAnyListeners, isTrue);

      vmB.setName('Bob');
      await tester.pump();
      expect(seen, ['Bob']);
    });
  });
}
