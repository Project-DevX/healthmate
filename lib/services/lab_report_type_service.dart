import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LabReportTypeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Default lab report types
  static const List<String> defaultTypes = [
    'blood_sugar',
    'cholesterol',
    'liver_function',
    'kidney_function',
    'thyroid_function',
    'complete_blood_count',
    'cardiac_markers',
    'vitamin_levels',
    'inflammatory_markers',
    'other_lab_tests',
  ];

  // Get display names for lab report types
  static String getDisplayName(String type) {
    switch (type) {
      case 'blood_sugar':
        return 'Blood Sugar / Glucose';
      case 'cholesterol':
        return 'Cholesterol / Lipid Panel';
      case 'liver_function':
        return 'Liver Function Tests';
      case 'kidney_function':
        return 'Kidney Function Tests';
      case 'thyroid_function':
        return 'Thyroid Function Tests';
      case 'complete_blood_count':
        return 'Complete Blood Count (CBC)';
      case 'cardiac_markers':
        return 'Cardiac Markers';
      case 'vitamin_levels':
        return 'Vitamin Levels';
      case 'inflammatory_markers':
        return 'Inflammatory Markers';
      case 'other_lab_tests':
        return 'Other Lab Tests';
      default:
        // Convert snake_case to Title Case
        return type
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  // Get all available lab report types (default + custom)
  static Future<List<String>> getAvailableTypes() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return defaultTypes;

      // Get custom types from user's collection
      final customTypesDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('lab_report_types')
          .get();

      List<String> customTypes = [];
      if (customTypesDoc.exists) {
        final data = customTypesDoc.data();
        customTypes = List<String>.from(data?['custom_types'] ?? []);
      }

      // Combine default and custom types, removing duplicates
      final allTypes = [...defaultTypes, ...customTypes];
      return allTypes.toSet().toList();
    } catch (e) {
      print('Error getting available types: $e');
      return defaultTypes;
    }
  }

  // Save a new custom lab report type
  static Future<bool> saveCustomType(String customType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Convert to snake_case for consistency
      final normalizedType = customType
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_');

      // Don't save if it's already a default type
      if (defaultTypes.contains(normalizedType)) {
        return true; // Consider it successful since the type exists
      }

      // Get current custom types
      final customTypesRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('lab_report_types');

      final doc = await customTypesRef.get();
      List<String> existingTypes = [];

      if (doc.exists) {
        final data = doc.data();
        existingTypes = List<String>.from(data?['custom_types'] ?? []);
      }

      // Add the new type if it doesn't exist
      if (!existingTypes.contains(normalizedType)) {
        existingTypes.add(normalizedType);

        await customTypesRef.set({
          'custom_types': existingTypes,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (e) {
      print('Error saving custom type: $e');
      return false;
    }
  }

  // Get recently used lab report types
  static Future<List<String>> getRecentlyUsedTypes() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // Get recent lab reports to determine frequently used types
      final recentReports = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('lab_report_content')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final typeFrequency = <String, int>{};
      for (final doc in recentReports.docs) {
        final data = doc.data();
        final type = data['labReportType'] as String?;
        if (type != null) {
          typeFrequency[type] = (typeFrequency[type] ?? 0) + 1;
        }
      }

      // Sort by frequency and return top types
      final sortedTypes = typeFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTypes.take(5).map((entry) => entry.key).toList();
    } catch (e) {
      print('Error getting recently used types: $e');
      return [];
    }
  }
}
