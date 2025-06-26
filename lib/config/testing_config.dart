// Global testing configuration for HealthMate app
// Set this to true during development/testing to bypass certain requirements
// Set to false for production builds

import 'package:flutter/material.dart';

class TestingConfig {
  /// Global testing mode flag
  /// When true:
  /// - Document upload requirements are bypassed
  /// - Sample data buttons are more prominent
  /// - Additional debug features are enabled
  /// - Registration redirects to login with pre-filled credentials
  static const bool isTestingMode = true;

  /// Whether to skip document upload requirements during registration
  static bool get skipDocumentUploads => isTestingMode;

  /// Whether to show enhanced debug UI
  static bool get showDebugUI => isTestingMode;

  /// Whether to enable auto-fill sample data
  static bool get enableSampleData => isTestingMode;

  /// Debug method to log current testing status
  static void logTestingStatus() {
    print('🧪 Testing Mode: $isTestingMode');
    print('📁 Skip Document Uploads: $skipDocumentUploads');
    print('🎨 Show Debug UI: $showDebugUI');
  }

  /// Easy way to check current testing status
  static String get statusMessage => isTestingMode
      ? "🧪 TESTING MODE: Document uploads bypassed"
      : "🔒 PRODUCTION MODE: All validations active";

  /// Get appropriate button color based on testing mode
  static Color get debugButtonColor =>
      isTestingMode ? Colors.orange : Colors.grey;

  /// Whether credentials should be auto-filled in login
  static bool get autoFillCredentials => isTestingMode;
}
