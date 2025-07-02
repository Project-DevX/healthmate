import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage recent logins with email and password persistence
class RecentLoginsService {
  static const String _recentLoginsKey = 'recent_logins';
  static const int _maxRecentLogins =
      5; // Maximum number of recent logins to store

  /// Get all recent logins
  static Future<List<RecentLogin>> getRecentLogins() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_recentLoginsKey) ?? [];

    return jsonList.map((jsonString) {
      final map = json.decode(jsonString) as Map<String, dynamic>;
      return RecentLogin.fromJson(map);
    }).toList();
  }

  /// Save or update a recent login
  static Future<void> saveRecentLogin({
    required String email,
    required String password,
    required bool rememberPassword,
    String? userType,
    String? fullName,
    String? avatarUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final recentLogins = await getRecentLogins();

    // Remove existing entry with same email
    recentLogins.removeWhere((login) => login.email == email);

    // Create new login entry
    final newLogin = RecentLogin(
      email: email,
      encryptedPassword: rememberPassword ? _encryptPassword(password) : null,
      rememberPassword: rememberPassword,
      lastLoginTime: DateTime.now(),
      userType: userType,
      fullName: fullName,
      avatarUrl: avatarUrl,
    );

    // Add to beginning of list
    recentLogins.insert(0, newLogin);

    // Keep only the most recent logins
    if (recentLogins.length > _maxRecentLogins) {
      recentLogins.removeRange(_maxRecentLogins, recentLogins.length);
    }

    // Save to SharedPreferences
    final jsonList = recentLogins
        .map((login) => json.encode(login.toJson()))
        .toList();
    await prefs.setStringList(_recentLoginsKey, jsonList);
  }

  /// Remove a specific recent login
  static Future<void> removeRecentLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final recentLogins = await getRecentLogins();

    recentLogins.removeWhere((login) => login.email == email);

    final jsonList = recentLogins
        .map((login) => json.encode(login.toJson()))
        .toList();
    await prefs.setStringList(_recentLoginsKey, jsonList);
  }

  /// Clear all recent logins
  static Future<void> clearAllRecentLogins() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentLoginsKey);
  }

  /// Get password for a specific email if remembered
  static Future<String?> getRememberedPassword(String email) async {
    final recentLogins = await getRecentLogins();
    final login = recentLogins.firstWhere(
      (login) => login.email == email && login.rememberPassword,
      orElse: () => RecentLogin(
        email: '',
        lastLoginTime: DateTime.now(),
        rememberPassword: false,
      ),
    );

    if (login.email.isEmpty || login.encryptedPassword == null) {
      return null;
    }

    return _decryptPassword(login.encryptedPassword!);
  }

  /// Simple encryption for password storage (for demo purposes)
  /// In production, use more robust encryption
  static String _encryptPassword(String password) {
    // Simple base64 encoding with reversal for basic obfuscation
    return base64.encode(utf8.encode(password)).split('').reversed.join();
  }

  /// Simple decryption for password storage
  static String _decryptPassword(String encryptedPassword) {
    try {
      final reversed = encryptedPassword.split('').reversed.join();
      return utf8.decode(base64.decode(reversed));
    } catch (e) {
      return '';
    }
  }
}

/// Model class for recent login data
class RecentLogin {
  final String email;
  final String? encryptedPassword;
  final bool rememberPassword;
  final DateTime lastLoginTime;
  final String? userType;
  final String? fullName;
  final String? avatarUrl;

  RecentLogin({
    required this.email,
    this.encryptedPassword,
    required this.rememberPassword,
    required this.lastLoginTime,
    this.userType,
    this.fullName,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'encryptedPassword': encryptedPassword,
      'rememberPassword': rememberPassword,
      'lastLoginTime': lastLoginTime.toIso8601String(),
      'userType': userType,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
    };
  }

  factory RecentLogin.fromJson(Map<String, dynamic> json) {
    return RecentLogin(
      email: json['email'] ?? '',
      encryptedPassword: json['encryptedPassword'],
      rememberPassword: json['rememberPassword'] ?? false,
      lastLoginTime: DateTime.parse(
        json['lastLoginTime'] ?? DateTime.now().toIso8601String(),
      ),
      userType: json['userType'],
      fullName: json['fullName'],
      avatarUrl: json['avatarUrl'],
    );
  }

  /// Get display name for UI
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    }
    return email.split('@')[0]; // Use email prefix as fallback
  }

  /// Get avatar initials
  String get avatarInitials {
    if (fullName != null && fullName!.isNotEmpty) {
      final names = fullName!.split(' ');
      if (names.length >= 2) {
        return '${names[0][0]}${names[1][0]}'.toUpperCase();
      }
      return fullName![0].toUpperCase();
    }
    return email[0].toUpperCase();
  }

  /// Get formatted last login time
  String get formattedLastLogin {
    final now = DateTime.now();
    final difference = now.difference(lastLoginTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
