import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_lite_example/main.dart';

void main() {
  testWidgets('counter increments when the button is tapped', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Count: 0'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Increment'));
    await tester.pump();

    expect(find.text('Count: 1'), findsOneWidget);
    expect(find.text('Count: 0'), findsNothing);
  });

  testWidgets('load button shows progress then updates the label',
      (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Tap to increment'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Load label'));
    await tester.pump();

    // While loading, the spinner is visible and both buttons are disabled.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Loaded at '), findsOneWidget);
  });
}
