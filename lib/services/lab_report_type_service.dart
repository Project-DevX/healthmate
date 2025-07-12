import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class LabReportTypeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get display name for lab report type (now uses displayName from dynamic structure)
  static String getDisplayName(String type) {
    // For dynamic types, the type already contains the display name
    // For legacy types, convert them
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
        // For dynamic types, return as-is (they're already display names)
        // For legacy snake_case, convert to Title Case
        if (type.contains('_')) {
          return type
              .replaceAll('_', ' ')
              .split(' ')
              .map((word) => word[0].toUpperCase() + word.substring(1))
              .join(' ');
        }
        return type;
    }
  }

  // Get all available lab report types from the new dynamic structure
  static Future<List<LabReportTypeData>> getAvailableTypes() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // Get dynamic lab types from the new structure
      final typesSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('lab_classifications')
          .doc('discovered_types')
          .collection('types')
          .orderBy('frequency', descending: true)
          .get();

      List<LabReportTypeData> types = [];
      for (final doc in typesSnapshot.docs) {
        final data = doc.data();
        types.add(LabReportTypeData.fromFirestore(data, doc.id));
      }

      // If no dynamic types exist, check for old format and migrate
      if (types.isEmpty) {
        final oldTypesDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('lab_report_types')
            .get();

        if (oldTypesDoc.exists) {
          final oldData = oldTypesDoc.data();
          final oldTypes = List<String>.from(oldData?['custom_types'] ?? []);

          // Convert old types to new format (basic migration)
          for (final oldType in oldTypes) {
            types.add(
              LabReportTypeData(
                id: oldType,
                displayName: getDisplayName(oldType),
                name: oldType,
                frequency: 1,
                category: _inferCategoryFromType(oldType),
                createdAt: DateTime.now(),
                firstSeen: DateTime.now(),
                lastSeen: DateTime.now(),
              ),
            );
          }
        }
      }

      return types;
    } catch (e) {
      print('Error getting available types: $e');
      return [];
    }
  }

  // Helper method to infer category from type name
  static String _inferCategoryFromType(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('blood') ||
        lowerType.contains('hematology') ||
        lowerType.contains('cbc')) {
      return 'hematology';
    } else if (lowerType.contains('cardiac') ||
        lowerType.contains('heart') ||
        lowerType.contains('cholesterol')) {
      return 'cardiovascular';
    } else if (lowerType.contains('liver') || lowerType.contains('hepatic')) {
      return 'hepatology';
    } else if (lowerType.contains('kidney') || lowerType.contains('renal')) {
      return 'nephrology';
    } else if (lowerType.contains('thyroid') ||
        lowerType.contains('endocrine')) {
      return 'endocrinology';
    } else if (lowerType.contains('vitamin') ||
        lowerType.contains('nutrient')) {
      return 'nutrition';
    } else if (lowerType.contains('inflammatory') ||
        lowerType.contains('immune')) {
      return 'immunology';
    }
    return 'general';
  }

  // Save a new custom lab report type (legacy method - now uses backend)
  static Future<bool> saveCustomType(String customType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Use the backend function to save the type
      final callable = FirebaseFunctions.instance.httpsCallable(
        'saveLabReportType',
      );
      await callable.call({'userId': user.uid, 'type': customType});

      return true;
    } catch (e) {
      print('Error saving custom type: $e');
      return false;
    }
  }

  // Get recently used lab report types from the new dynamic structure
  static Future<List<LabReportTypeData>> getRecentlyUsedTypes() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // Get recent lab types ordered by lastSeen (most recent first)
      final recentTypesSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('lab_classifications')
          .doc('discovered_types')
          .collection('types')
          .orderBy('lastSeen', descending: true)
          .limit(5)
          .get();

      List<LabReportTypeData> types = [];
      for (final doc in recentTypesSnapshot.docs) {
        final data = doc.data();
        types.add(LabReportTypeData.fromFirestore(data, doc.id));
      }

      return types;
    } catch (e) {
      print('Error getting recently used types: $e');
      return [];
    }
  }

  // Get lab report types by category
  static Future<Map<String, List<LabReportTypeData>>>
  getTypesByCategory() async {
    try {
      final types = await getAvailableTypes();
      final Map<String, List<LabReportTypeData>> categorizedTypes = {};

      for (final type in types) {
        final category = type.category;
        if (!categorizedTypes.containsKey(category)) {
          categorizedTypes[category] = [];
        }
        categorizedTypes[category]!.add(type);
      }

      return categorizedTypes;
    } catch (e) {
      print('Error getting types by category: $e');
      return {};
    }
  }

  // Search lab report types
  static Future<List<LabReportTypeData>> searchTypes(String query) async {
    try {
      final types = await getAvailableTypes();
      final lowercaseQuery = query.toLowerCase();

      return types.where((type) {
        return type.displayName.toLowerCase().contains(lowercaseQuery) ||
            type.category.toLowerCase().contains(lowercaseQuery) ||
            (type.sampleTests?.any(
                  (test) => test.toLowerCase().contains(lowercaseQuery),
                ) ??
                false);
      }).toList();
    } catch (e) {
      print('Error searching types: $e');
      return [];
    }
  }
}

/// Data model for dynamic lab report types
class LabReportTypeData {
  final String id;
  final String displayName;
  final String name; // Legacy compatibility
  final int frequency;
  final String category;
  final DateTime createdAt;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final List<String>? relatedTypes;
  final List<String>? sampleTests;
  final List<String>? examples;

  LabReportTypeData({
    required this.id,
    required this.displayName,
    required this.name,
    required this.frequency,
    required this.category,
    required this.createdAt,
    required this.firstSeen,
    required this.lastSeen,
    this.relatedTypes,
    this.sampleTests,
    this.examples,
  });

  factory LabReportTypeData.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return LabReportTypeData(
      id: id,
      displayName: data['displayName'] ?? data['name'] ?? '',
      name: data['name'] ?? data['displayName'] ?? '',
      frequency: data['frequency'] ?? 0,
      category: data['category'] ?? 'general',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      firstSeen: (data['firstSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      relatedTypes: data['relatedTypes'] != null
          ? List<String>.from(data['relatedTypes'])
          : null,
      sampleTests: data['sampleTests'] != null
          ? List<String>.from(data['sampleTests'])
          : null,
      examples: data['examples'] != null
          ? List<String>.from(data['examples'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'name': name,
      'frequency': frequency,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'firstSeen': Timestamp.fromDate(firstSeen),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'relatedTypes': relatedTypes,
      'sampleTests': sampleTests,
      'examples': examples,
    };
  }

  String get formattedFrequency {
    if (frequency == 1) return '1 time';
    return '$frequency times';
  }

  String get formattedCategory {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
