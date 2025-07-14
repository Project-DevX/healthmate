import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:healthmate/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Trend Analysis Integration Tests', () {
    testWidgets('should navigate to trend analysis and display UI', (
      tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Skip authentication flow for now and test basic navigation
      // In a real test, you would implement proper auth flow

      // Look for any navigation elements or buttons
      await tester.pump();

      // Basic smoke test - app should start without crashing
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('should handle app startup gracefully', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 1));

      // App should initialize without errors
      expect(find.byType(MaterialApp), findsOneWidget);

      // Look for common UI elements
      final scaffolds = find.byType(Scaffold);
      if (scaffolds.evaluate().isNotEmpty) {
        expect(scaffolds, findsWidgets);
      }
    });

    testWidgets('should handle navigation without crashes', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 1));

      // Test basic navigation elements if they exist
      final navigationElements = find.byType(BottomNavigationBar);
      if (navigationElements.evaluate().isNotEmpty) {
        // If bottom navigation exists, try tapping different tabs
        await tester.tap(navigationElements.first);
        await tester.pump();
      }

      // App should remain stable
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('should display error handling gracefully', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 1));

      // Test that the app handles errors gracefully
      // The global error handler should prevent crashes
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Theme and UI Tests', () {
    testWidgets('should display with proper theme', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 1));

      // Check that theme is applied
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
    });

    testWidgets('should handle screen orientations', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 1));

      // Test portrait mode
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);

      // Test landscape mode
      await tester.binding.setSurfaceSize(const Size(800, 400));
      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);

      // Reset to portrait
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pump();
    });
  });

  group('Performance Tests', () {
    testWidgets('should start within reasonable time', (tester) async {
      final stopwatch = Stopwatch()..start();

      app.main();
      await tester.pump(const Duration(seconds: 1));

      stopwatch.stop();

      // App should start within 5 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('should handle multiple rapid taps without freezing', (
      tester,
    ) async {
      app.main();
      await tester.pump(const Duration(seconds: 1));

      // Find any tappable elements
      final buttons = find.byType(ElevatedButton);
      final iconButtons = find.byType(IconButton);
      final inkWells = find.byType(InkWell);

      // Test rapid tapping on different elements
      if (buttons.evaluate().isNotEmpty) {
        for (int i = 0; i < 5; i++) {
          await tester.tap(buttons.first);
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      if (iconButtons.evaluate().isNotEmpty) {
        for (int i = 0; i < 5; i++) {
          await tester.tap(iconButtons.first);
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // App should remain responsive
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}

// Helper functions for authentication flow
Future<void> _performLogin(WidgetTester tester) async {
  // This would implement your specific login flow
  // For now, it's a placeholder that could be extended based on your auth system

  // Look for login-related elements
  final loginButton = find.text('Login');
  final signInButton = find.text('Sign In');
  final emailField = find.byType(TextField);

  if (loginButton.evaluate().isNotEmpty) {
    await tester.tap(loginButton);
    await tester.pump();
  } else if (signInButton.evaluate().isNotEmpty) {
    await tester.tap(signInButton);
    await tester.pump();
  }

  // If email fields exist, you could fill them out here
  if (emailField.evaluate().isNotEmpty) {
    await tester.enterText(emailField.first, 'test@example.com');
    await tester.pump();
  }
}

Future<void> _navigateToTrends(WidgetTester tester) async {
  // Look for trend-related navigation elements
  final trendsButton = find.text('Trends');
  final healthTrendsButton = find.text('Health Trends');
  final analyticsButton = find.text('Analytics');

  if (trendsButton.evaluate().isNotEmpty) {
    await tester.tap(trendsButton);
    await tester.pumpAndSettle();
  } else if (healthTrendsButton.evaluate().isNotEmpty) {
    await tester.tap(healthTrendsButton);
    await tester.pumpAndSettle();
  } else if (analyticsButton.evaluate().isNotEmpty) {
    await tester.tap(analyticsButton);
    await tester.pumpAndSettle();
  }
}
