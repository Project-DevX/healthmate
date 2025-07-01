/// Utility functions for user data handling across the HealthMate app
class UserDataUtils {
  /// Extract display name from user data with proper fallback logic
  /// This handles the different naming conventions used by different user types
  static String getDisplayName(Map<String, dynamic>? userData) {
    if (userData == null) {
      return 'User';
    }

    // Check for different name field combinations based on user type
    final userType = userData['userType'] as String?;

    switch (userType?.toLowerCase()) {
      case 'patient':
        // Patients store firstName and lastName separately
        final firstName = userData['firstName'] as String?;
        final lastName = userData['lastName'] as String?;
        if (firstName != null && lastName != null) {
          return '$firstName $lastName';
        } else if (firstName != null) {
          return firstName;
        } else if (lastName != null) {
          return lastName;
        }
        break;

      case 'doctor':
      case 'caregiver':
        // Doctors and caregivers store fullName
        final fullName = userData['fullName'] as String?;
        if (fullName != null && fullName.isNotEmpty) {
          return fullName;
        }
        break;

      case 'hospital':
      case 'institution':
        // Hospitals/institutions store institutionName
        final institutionName = userData['institutionName'] as String?;
        final hospitalName = userData['hospitalName'] as String?;
        if (institutionName != null && institutionName.isNotEmpty) {
          return institutionName;
        } else if (hospitalName != null && hospitalName.isNotEmpty) {
          return hospitalName;
        }
        break;
    }

    // Fallback: try common name fields
    final displayName =
        userData['displayName'] as String? ??
        userData['name'] as String? ??
        userData['fullName'] as String?;

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    // Final fallback: use email prefix
    final email = userData['email'] as String?;
    if (email != null && email.isNotEmpty) {
      return email.split('@')[0].replaceAll('.', ' ').toUpperCase();
    }

    return 'User';
  }

  /// Get user's phone number with proper field fallbacks
  static String getPhoneNumber(Map<String, dynamic>? userData) {
    if (userData == null) return 'Not provided';

    return userData['phone'] as String? ??
        userData['phoneNumber'] as String? ??
        userData['mobile'] as String? ??
        'Not provided';
  }

  /// Get user's email address
  static String getEmail(Map<String, dynamic>? userData) {
    return userData?['email'] as String? ?? 'No email';
  }

  /// Get user type with fallback
  static String getUserType(Map<String, dynamic>? userData) {
    return userData?['userType'] as String? ?? 'unknown';
  }

  /// Get user's profile initials for avatars
  static String getInitials(Map<String, dynamic>? userData) {
    final displayName = getDisplayName(userData);

    if (displayName == 'User') {
      final email = getEmail(userData);
      if (email != 'No email') {
        return email[0].toUpperCase();
      }
      return 'U';
    }

    final words = displayName.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    }

    return 'U';
  }

  /// Format user type for display
  static String formatUserType(String? userType) {
    if (userType == null || userType.isEmpty) return 'User';

    switch (userType.toLowerCase()) {
      case 'patient':
        return 'Patient';
      case 'doctor':
        return 'Doctor';
      case 'caregiver':
        return 'Caregiver';
      case 'hospital':
      case 'institution':
        return 'Healthcare Institution';
      default:
        return userType.substring(0, 1).toUpperCase() +
            userType.substring(1).toLowerCase();
    }
  }
}
