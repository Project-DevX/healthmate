import 'package:flutter/material.dart';

/// Shared theme and styling configuration for HealthMate app
class AppTheme {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);

  // Secondary Colors
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentPurple = Color(0xFF9C27B0);
  static const Color accentRed = Color(0xFFE53935);

  // Status Colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFE53935);
  static const Color infoBlue = Color(0xFF2196F3);

  // Neutral Colors
  static const Color backgroundGrey = Color(0xFFF5F5F5);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF212121);
  static const Color textMedium = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);
  static const Color dividerGrey = Color(0xFFE0E0E0);

  // User Type Colors
  static const Color patientColor = primaryBlue;
  static const Color doctorColor = accentGreen;
  static const Color caregiverColor = accentOrange;
  static const Color hospitalColor = accentPurple;
  static const Color pharmacyColor = accentOrange; // Orange for pharmacy
  static const Color labColor = accentRed; // Red for lab

  /// Get color based on user type
  static Color getUserTypeColor(String? userType) {
    switch (userType?.toLowerCase()) {
      case 'patient':
        return patientColor;
      case 'doctor':
        return doctorColor;
      case 'caregiver':
        return caregiverColor;
      case 'hospital':
      case 'institution':
        return hospitalColor;
      case 'pharmacy':
        return pharmacyColor;
      case 'lab':
      case 'laboratory':
        return labColor;
      default:
        return primaryBlue;
    }
  }

  /// Main app theme
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundGrey,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: cardWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryBlue,
        unselectedItemColor: textMedium,
        type: BottomNavigationBarType.fixed,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: Color(0xFF64B5F6),
      scaffoldBackgroundColor: Color(0xFF121212),
      brightness: Brightness.dark,

      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      cardTheme: CardThemeData(
        elevation: 2,
        color: Color(0xFF1F1F1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  // Chart colors for different trend types
  static const Map<String, Color> trendColors = {
    'increasing': Colors.red,
    'decreasing': Colors.orange,
    'stable': Colors.green,
    'prediction': Colors.blue,
    'anomaly': Colors.deepOrange,
  };

  // Health status colors
  static const Map<String, Color> healthStatusColors = {
    'excellent': Colors.green,
    'good': Colors.lightGreen,
    'fair': Colors.orange,
    'concerning': Colors.red,
  };

  /// Card decoration with shadow
  static BoxDecoration get cardDecoration {
    return BoxDecoration(
      color: cardWhite,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Quick access button decoration
  static BoxDecoration quickAccessDecoration(Color color) {
    return BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    );
  }

  /// Text styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textDark,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textDark,
  );

  static const TextStyle bodyMedium = TextStyle(fontSize: 16, color: textDark);

  static const TextStyle bodySmall = TextStyle(fontSize: 14, color: textMedium);

  static const TextStyle captionSmall = TextStyle(
    fontSize: 12,
    color: textLight,
  );
}

/// Common widget styles and components
class AppWidgets {
  /// Standard app bar with user type styling
  static AppBar buildAppBar({
    required String title,
    String? userType,
    List<Widget>? actions,
  }) {
    return AppBar(
      title: Text(title),
      backgroundColor: AppTheme.getUserTypeColor(userType),
      foregroundColor: Colors.white,
      actions: actions,
    );
  }

  /// Quick access button widget
  static Widget buildQuickAccessButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Info card widget
  static Widget buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final cardColor = color ?? AppTheme.primaryBlue;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: cardColor),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  /// Health stat card widget
  static Widget buildHealthStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  /// Emergency option widget
  static Widget buildEmergencyOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 24,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textLight),
          ],
        ),
      ),
    );
  }
}
