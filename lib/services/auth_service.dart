import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Check if user is already logged in
  static Future<Map<String, String?>> getLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      return {
        'userId': prefs.getString('userId'),
        'userEmail': prefs.getString('userEmail'),
        'userType': prefs.getString('userType'),
      };
    }
    return {};
  }

  // Clear login state from SharedPreferences
  static Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('userId');
    await prefs.remove('userEmail');
    await prefs.remove('userType');
    print('Login state cleared');
  }

  // Save login state to SharedPreferences
  static Future<void> saveLoginState(
    String userId,
    String email,
    String userType,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', userId);
    await prefs.setString('userEmail', email);
    await prefs.setString('userType', userType);
    print('Login state saved');
  }
}
