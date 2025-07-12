import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../config/testing_config.dart';

/// Service for managing developer mode role switching
/// Allows developers to quickly switch between different user roles during development
class DevModeService {
  static const String _keyDevModeEnabled = 'dev_mode_enabled';
  static const String _keySelectedRole = 'dev_selected_role';
  static const String _keyDevCredentials = 'dev_credentials_';

  /// Available user roles for development testing
  static const List<String> availableRoles = [
    'patient',
    'doctor',
    'hospital',
    'caregiver',
    'lab',
    'pharmacy',
  ];

  /// Sample credentials for each role type
  /// These match the sample data used in registration forms for easy testing
  ///
  /// NOTE: These accounts must be registered first using the "Fill Sample Data"
  /// buttons in the respective registration forms before they can be used for login.
  /// The credentials correspond to the first sample user in each registration form.
  static const Map<String, Map<String, String>> sampleCredentials = {
    'patient': {
      'email': 'john.doe.patient@gmail.com',
      'password': 'password123',
      'displayName': 'John Doe',
    },
    'doctor': {
      'email': 'dr.sarah.wilson@gmail.com',
      'password': 'password123',
      'displayName': 'Dr. Sarah Wilson',
    },
    'hospital': {
      'email': 'admin.citygeneral@gmail.com',
      'password': 'password123',
      'displayName': 'City General Hospital',
    },
    'caregiver': {
      'email': 'mary.johnson.care@gmail.com',
      'password': 'password123',
      'displayName': 'Mary Johnson',
    },
    'lab': {
      'email': 'info.metrolab@gmail.com',
      'password': 'password123',
      'displayName': 'Metro Medical Laboratory',
    },
    'pharmacy': {
      'email': 'contact.healthcarepharm@gmail.com',
      'password': 'password123',
      'displayName': 'HealthCare Pharmacy',
    },
  };

  /// Check if developer mode is enabled
  static Future<bool> isDevModeEnabled() async {
    if (!TestingConfig.isTestingMode) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDevModeEnabled) ?? false;
  }

  /// Enable or disable developer mode
  static Future<void> setDevModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDevModeEnabled, enabled);
    if (kDebugMode) {
      print('🔧 DevMode ${enabled ? 'ENABLED' : 'DISABLED'}');
    }
  }

  /// Get the currently selected developer role
  static Future<String?> getSelectedRole() async {
    if (!await isDevModeEnabled()) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedRole);
  }

  /// Set the selected developer role
  static Future<void> setSelectedRole(String role) async {
    if (!availableRoles.contains(role)) {
      throw ArgumentError('Invalid role: $role');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedRole, role);

    if (kDebugMode) {
      print('🎭 DevMode role switched to: $role');
    }
  }

  /// Clear the selected role
  static Future<void> clearSelectedRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySelectedRole);
  }

  /// Get sample credentials for a role
  static Map<String, String>? getCredentialsForRole(String role) {
    return sampleCredentials[role];
  }

  /// Save custom credentials for a role (for development)
  static Future<void> saveCustomCredentials(
    String role,
    String email,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyDevCredentials}${role}_email', email);
    await prefs.setString('${_keyDevCredentials}${role}_password', password);
  }

  /// Get custom credentials for a role
  static Future<Map<String, String>?> getCustomCredentials(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('${_keyDevCredentials}${role}_email');
    final password = prefs.getString('${_keyDevCredentials}${role}_password');

    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  /// Get the best available credentials for a role (custom or sample)
  static Future<Map<String, String>?> getBestCredentials(String role) async {
    // First try custom credentials
    final custom = await getCustomCredentials(role);
    if (custom != null) return custom;

    // Fallback to sample credentials
    return getCredentialsForRole(role);
  }

  /// Reset all developer mode settings
  static Future<void> resetDevMode() async {
    final prefs = await SharedPreferences.getInstance();

    // Remove all dev mode keys
    await prefs.remove(_keyDevModeEnabled);
    await prefs.remove(_keySelectedRole);

    // Remove custom credentials
    for (final role in availableRoles) {
      await prefs.remove('${_keyDevCredentials}${role}_email');
      await prefs.remove('${_keyDevCredentials}${role}_password');
    }

    if (kDebugMode) {
      print('🔧 DevMode settings reset');
    }
  }

  /// Get route name for a user type
  static String getRouteForUserType(String userType) {
    switch (userType) {
      case 'patient':
        return '/patientDashboard';
      case 'doctor':
        return '/doctorDashboard';
      case 'hospital':
        return '/hospitalDashboard';
      case 'caregiver':
        return '/caregiverDashboard';
      case 'lab':
        return '/labDashboard';
      case 'pharmacy':
        return '/pharmacyDashboard';
      default:
        return '/patientDashboard';
    }
  }

  /// Get display name for a user type
  static String getDisplayNameForRole(String role) {
    switch (role) {
      case 'patient':
        return 'Patient';
      case 'doctor':
        return 'Doctor';
      case 'hospital':
        return 'Hospital/Institute';
      case 'caregiver':
        return 'Caregiver';
      case 'lab':
        return 'Laboratory';
      case 'pharmacy':
        return 'Pharmacy';
      default:
        return role.toUpperCase();
    }
  }

  /// Get icon for a user type
  static String getIconForRole(String role) {
    switch (role) {
      case 'patient':
        return '🏥';
      case 'doctor':
        return '👨‍⚕️';
      case 'hospital':
        return '🏥';
      case 'caregiver':
        return '🧑‍🦳';
      case 'lab':
        return '🧪';
      case 'pharmacy':
        return '💊';
      default:
        return '👤';
    }
  }

  /// Get setup instructions for sample accounts
  static String getSetupInstructions() {
    return '''
🚀 QUICK SETUP GUIDE FOR SAMPLE LOGINS:

To use the sample login buttons, you need to register the accounts first:

1. 👨‍⚕️ For DOCTOR login:
   • Go to Register → Doctor Registration
   • Click "Fill Sample Data" button
   • Complete registration

2. 🏥 For HOSPITAL login:
   • Go to Register → Hospital Registration
   • Click "Fill Sample Data" button
   • Complete registration

3. 💊 For PHARMACY login:
   • Go to Register → Hospital Registration
   • Click "Fill Sample Data" button (select Pharmacy type)
   • Complete registration

4. 🧪 For LAB login:
   • Go to Register → Hospital Registration
   • Click "Fill Sample Data" button (select Laboratory type)
   • Complete registration

5. 🧑‍🦳 For CAREGIVER login:
   • Go to Register → Caregiver Registration
   • Click "Fill Sample Data" button
   • Complete registration

6. 🏥 For PATIENT login:
   • Go to Register → Patient Registration
   • Click "Fill Sample Data" button
   • Complete registration

After registering, you can use the sample login buttons for quick testing!
    ''';
  }

  /// Check if sample credentials should work (basic validation)
  static bool areSampleCredentialsValid() {
    // This is a simple check - in a real app you might want to
    // ping Firebase Auth to see if these accounts exist
    return sampleCredentials.isNotEmpty &&
        sampleCredentials.values.every(
          (creds) =>
              creds['email']?.isNotEmpty == true &&
              creds['password']?.isNotEmpty == true,
        );
  }
}
