import 'package:material_ui/material_ui.dart';
import 'package:mvvm_lite/mvvm_lite.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'mvvm_lite example', home: const CounterPage());
}

// ─── State ──────────────────────────────────────────────────────────────────

class CounterState {
  const CounterState({this.count = 0, this.isLoading = false, this.label = ''});

  final int count;
  final bool isLoading;
  final String label;

  CounterState copyWith({int? count, bool? isLoading, String? label}) =>
      CounterState(
        count: count ?? this.count,
        isLoading: isLoading ?? this.isLoading,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CounterState &&
          other.count == count &&
          other.isLoading == isLoading &&
          other.label == label;

  @override
  int get hashCode => Object.hash(count, isLoading, label);
}

// ─── ViewModel ──────────────────────────────────────────────────────────────

class CounterViewModel extends ViewModel<CounterState> {
  CounterViewModel() : super(const CounterState(label: 'Tap to increment'));

  void increment() => state = state.copyWith(count: state.count + 1);

  Future<void> loadLabel() async {
    state = state.copyWith(isLoading: true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    state = state.copyWith(
      isLoading: false,
      label: 'Loaded at ${DateTime.now().toIso8601String()}',
    );
  }
}

// ─── UI ─────────────────────────────────────────────────────────────────────

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<CounterViewModel>(
    create: (_) => CounterViewModel(),
    builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('mvvm_lite example')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CountText(),
            SizedBox(height: 12),
            _LabelText(),
            SizedBox(height: 24),
            _ActionsRow(),
          ],
        ),
      ),
    ),
  );
}

// Rebuilds ONLY when `count` changes — uses ViewModelSelector.
class _CountText extends StatelessWidget {
  const _CountText();

  @override
  Widget build(BuildContext context) => ViewModelSelector<CounterState, int>(
    selector: (state) => state.count,
    builder: (_, count, _) => Text(
      'Count: $count',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
  );
}

// Rebuilds ONLY when `label` changes — also ViewModelSelector.
class _LabelText extends StatelessWidget {
  const _LabelText();

  @override
  Widget build(BuildContext context) => ViewModelSelector<CounterState, String>(
    selector: (state) => state.label,
    builder: (_, label, _) => Text(label),
  );
}

// Demonstrates ViewModelBuilder — rebuilds on every state change. For this row only
// `isLoading` matters; a ViewModelSelector<CounterState, bool> would be more granular.
// ViewModelBuilder is shown here for illustration alongside the two selectors above.
class _ActionsRow extends StatelessWidget {
  const _ActionsRow();

  @override
  Widget build(BuildContext context) => ViewModelBuilder<CounterState>(
    builder: (context, state, _) => Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: state.isLoading
                ? null
                : () => context.viewModel<CounterViewModel>().increment(),
            child: const Text('Increment'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonal(
            onPressed: state.isLoading
                ? null
                : () => context.viewModel<CounterViewModel>().loadLabel(),
            child: state.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Load label'),
          ),
        ),
      ],
    ),
  );
}
