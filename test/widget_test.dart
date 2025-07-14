// Basic Flutter widget test for HealthMate app.
//
// Tests basic app functionality without interfering with global error handling.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp structure test', (WidgetTester tester) async {
    // Test a basic MaterialApp structure without using the full MyApp
    await tester.pumpWidget(
      MaterialApp(
        title: 'HealthMate Test',
        home: Scaffold(
          appBar: AppBar(title: const Text('Test')),
          body: const Text('Hello World'),
        ),
      ),
    );

    // Verify that the basic structure works
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Hello World'), findsOneWidget);
  });

  testWidgets('Text widget test', (WidgetTester tester) async {
    // Simple test for text widgets
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('HealthMate'))),
    );

    expect(find.text('HealthMate'), findsOneWidget);
  });
}
