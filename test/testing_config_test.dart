import 'package:flutter_test/flutter_test.dart';
import '../lib/config/testing_config.dart';

void main() {
  group('Testing Configuration Tests', () {
    test('Testing mode should be enabled', () {
      expect(TestingConfig.isTestingMode, true);
    });

    test(
      'Skip document uploads should be true when testing mode is enabled',
      () {
        expect(TestingConfig.skipDocumentUploads, true);
      },
    );

    test('Show debug UI should be true when testing mode is enabled', () {
      expect(TestingConfig.showDebugUI, true);
    });

    test('Status message should indicate testing mode', () {
      expect(TestingConfig.statusMessage, contains('TESTING MODE'));
      expect(
        TestingConfig.statusMessage,
        contains('Document uploads bypassed'),
      );
    });

    test('Log testing status should work without errors', () {
      expect(() => TestingConfig.logTestingStatus(), returnsNormally);
    });
  });
}
