import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_lite/mvvm_lite.dart';

class _CounterVm extends ViewModel<int> {
  _CounterVm() : super(0);

  var disposed = false;
  void increment() => state = state + 1;

  // Exposes the protected `hasListeners` flag for subscription tests.
  bool get hasAnyListeners => hasListeners;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _FakeCounterVm extends _CounterVm {
  _FakeCounterVm() {
    state = 7;
  }
}

class _ChildVm extends ViewModel<String> {
  _ChildVm(int parentCount) : super('parent=$parentCount');
}

void main() {
  group('ViewModelProvider', () {
    testWidgets('creates the VM eagerly and exposes it via context.viewModel', (
      tester,
    ) async {
      _CounterVm? captured;
      await tester.pumpWidget(
        ViewModelProvider<_CounterVm>(
          create: (_) => _CounterVm(),
          builder: (context) {
            captured = context.viewModel<_CounterVm>();
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
        ViewModelProvider<_CounterVm>(
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

    testWidgets('viewModel throws when no provider is in scope', (
      tester,
    ) async {
      BuildContext? captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      );
      expect(
        () => captured!.viewModel<_CounterVm>(),
        throwsA(isA<FlutterError>()),
      );
    });

    testWidgets('child and builder are mutually exclusive', (tester) async {
      expect(
        () => ViewModelProvider<_CounterVm>(create: (_) => _CounterVm()),
        throwsAssertionError,
      );
    });

    testWidgets('passing both child and builder throws', (tester) async {
      expect(
        () => ViewModelProvider<_CounterVm>(
          create: (_) => _CounterVm(),
          child: const SizedBox(),
          builder: (_) => const SizedBox(),
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'create runs once and is not re-invoked on teardown when it throws',
      (tester) async {
        var createCount = 0;
        await tester.pumpWidget(
          ViewModelProvider<_CounterVm>(
            create: (_) {
              createCount++;
              throw StateError('boom');
            },
            child: const SizedBox(),
          ),
        );
        expect(createCount, 1);
        expect(tester.takeException(), isStateError);

        // Removing the failed provider must not re-read `_vm` and call `create`
        // a second time during dispose (the old `late final` initializer did,
        // masking the original error).
        await tester.pumpWidget(const SizedBox());
        expect(createCount, 1);
      },
    );

    testWidgets('create can resolve a parent view model via context.viewModel', (
      tester,
    ) async {
      late _ChildVm child;
      await tester.pumpWidget(
        ViewModelProvider<_CounterVm>(
          create: (_) => _CounterVm()..increment(),
          child: ViewModelProvider<_ChildVm>(
            create: (context) =>
                child = _ChildVm(context.viewModel<_CounterVm>().state),
            child: const SizedBox(),
          ),
        ),
      );

      // `create` runs in initState, so only non-dependency lookups work there —
      // context.viewModel is one of them.
      expect(child.state, 'parent=1');
    });

    testWidgets('viewModel does not subscribe to state changes', (
      tester,
    ) async {
      late _CounterVm vm;
      var buildCount = 0;
      await tester.pumpWidget(
        ViewModelProvider<_CounterVm>(
          create: (_) {
            vm = _CounterVm();
            return vm;
          },
          builder: (context) {
            buildCount++;
            context.viewModel<_CounterVm>();
            return const SizedBox();
          },
        ),
      );
      expect(buildCount, 1);

      vm.increment();
      await tester.pump();
      // viewModel reads without registering a dependency — no rebuild.
      expect(buildCount, 1);
    });

    testWidgets('resolves without explicit type arguments', (tester) async {
      // The form real code uses. The state type is not a type argument, so the
      // widgets below resolve through the runtime type of the view model —
      // there is nothing left for inference to get wrong.
      _CounterVm? captured;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider(
            create: (_) => _CounterVm()..increment(),
            builder: (context) {
              captured = context.viewModel<_CounterVm>();
              return ViewModelBuilder<int>(
                builder: (_, state, _) => Text('value=$state'),
              );
            },
          ),
        ),
      );

      expect(captured, isNotNull);
      expect(find.text('value=1'), findsOneWidget);
    });
  });

  group('ViewModelProvider.value', () {
    testWidgets('exposes an external view model without owning it', (
      tester,
    ) async {
      final vm = _CounterVm()..increment();
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider.value(
            value: vm,
            child: ViewModelBuilder<int>(
              builder: (_, state, _) => Text('value=$state'),
            ),
          ),
        ),
      );
      expect(find.text('value=1'), findsOneWidget);

      // Removing the provider must not dispose a view model it doesn't own.
      await tester.pumpWidget(const SizedBox());
      expect(vm.disposed, isFalse);
      expect(vm.mounted, isTrue);
    });

    testWidgets('rebinds consumers when the value is swapped', (tester) async {
      final first = _CounterVm()..increment();
      final second = _CounterVm()
        ..increment()
        ..increment();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Widget build(_CounterVm vm) => Directionality(
        textDirection: TextDirection.ltr,
        child: ViewModelProvider.value(
          value: vm,
          child: ViewModelBuilder<int>(
            builder: (_, state, _) => Text('value=$state'),
          ),
        ),
      );

      await tester.pumpWidget(build(first));
      expect(find.text('value=1'), findsOneWidget);

      await tester.pumpWidget(build(second));
      expect(find.text('value=2'), findsOneWidget);
      expect(first.hasAnyListeners, isFalse);
      expect(second.hasAnyListeners, isTrue);
      expect(first.disposed, isFalse);
    });

    testWidgets('a fake subclass answers to the real view-model type', (
      tester,
    ) async {
      // The documented testing recipe: a page looks its view model up by the
      // real type while the test injects a subclass. Lookup is by
      // assignability, so this resolves.
      final fake = _FakeCounterVm();
      addTearDown(fake.dispose);
      _CounterVm? captured;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ViewModelProvider.value(
            value: fake,
            builder: (context) {
              captured = context.viewModel<_CounterVm>();
              return ViewModelBuilder<int>(
                builder: (_, state, _) => Text('value=$state'),
              );
            },
          ),
        ),
      );

      expect(identical(captured, fake), isTrue);
      expect(find.text('value=7'), findsOneWidget);
    });

    testWidgets('switching from create to .value hands ownership over', (
      tester,
    ) async {
      final external = _CounterVm()..increment();
      addTearDown(external.dispose);
      late _CounterVm created;

      Widget build({required bool owned}) => Directionality(
        textDirection: TextDirection.ltr,
        child: owned
            ? ViewModelProvider(
                create: (_) => created = _CounterVm(),
                child: ViewModelBuilder<int>(
                  builder: (_, state, _) => Text('value=$state'),
                ),
              )
            : ViewModelProvider.value(
                value: external,
                child: ViewModelBuilder<int>(
                  builder: (_, state, _) => Text('value=$state'),
                ),
              ),
      );

      await tester.pumpWidget(build(owned: true));
      expect(find.text('value=0'), findsOneWidget);

      await tester.pumpWidget(build(owned: false));
      expect(find.text('value=1'), findsOneWidget);
      // The view model this widget created is its own to dispose; the incoming
      // one is not.
      expect(created.disposed, isTrue);
      expect(external.disposed, isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(external.disposed, isFalse);
      expect(external.mounted, isTrue);
    });

    testWidgets(
      'switching from .value to create leaves the caller\'s vm alone',
      (tester) async {
        final external = _CounterVm();
        addTearDown(external.dispose);
        late _CounterVm created;

        Widget build({required bool owned}) => owned
            ? ViewModelProvider(
                create: (_) => created = _CounterVm(),
                child: const SizedBox(),
              )
            : ViewModelProvider.value(value: external, child: const SizedBox());

        await tester.pumpWidget(build(owned: false));
        await tester.pumpWidget(build(owned: true));
        expect(external.disposed, isFalse);

        await tester.pumpWidget(const SizedBox());
        expect(created.disposed, isTrue);
        expect(external.disposed, isFalse);
      },
    );
  });
}
