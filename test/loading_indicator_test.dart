
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/widgets/loading_indicator.dart';

void main() {
  testWidgets('shows default message and spinner',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingIndicator(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);
  });

  testWidgets('shows a custom message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingIndicator(
            message: 'Fetching bookings...',
          ),
        ),
      ),
    );

    expect(find.text('Fetching bookings...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
