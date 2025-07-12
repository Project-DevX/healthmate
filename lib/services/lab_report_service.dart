import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LabReportService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Get lab report content for the current user
  static Future<Map<String, dynamic>> getLabReportContent({
    String? labReportType,
    int limit = 50,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final callable = _functions.httpsCallable('getLabReportContent');
      final result = await callable.call({
        'labReportType': labReportType ?? 'all',
        'limit': limit,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to get lab report content: $e');
    }
  }

  /// Get available lab report types for the current user from dynamic structure
  static Future<List<String>> getAvailableLabReportTypes() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // Use the backend function to get lab report types
      final callable = _functions.httpsCallable('getLabReportTypesForUser');
      final result = await callable.call({'userId': user.uid});

      final types = List<String>.from(result.data ?? []);
      return types;
    } catch (e) {
      throw Exception('Failed to get available lab report types: $e');
    }
  }
}

/// Data models for lab reports
class LabReportContent {
  final String id;
  final String fileName;
  final String labReportType;
  final String extractedText;
  final List<TestResult> testResults;
  final String? testDate;
  final PatientInfo patientInfo;
  final LabInfo labInfo;
  final DateTime? createdAt;
  final String extractionMethod;

  LabReportContent({
    required this.id,
    required this.fileName,
    required this.labReportType,
    required this.extractedText,
    required this.testResults,
    this.testDate,
    required this.patientInfo,
    required this.labInfo,
    this.createdAt,
    required this.extractionMethod,
  });

  factory LabReportContent.fromMap(Map<String, dynamic> map) {
    return LabReportContent(
      id: map['id'] ?? '',
      fileName: map['fileName'] ?? '',
      labReportType: map['labReportType'] ?? '',
      extractedText: map['extractedText'] ?? '',
      testResults: (map['testResults'] as List<dynamic>? ?? [])
          .map((item) => TestResult.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      testDate: map['testDate'],
      patientInfo: PatientInfo.fromMap(
        Map<String, dynamic>.from(map['patientInfo'] ?? {}),
      ),
      labInfo: LabInfo.fromMap(Map<String, dynamic>.from(map['labInfo'] ?? {})),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
      extractionMethod: map['extractionMethod'] ?? '',
    );
  }

  String get formattedLabReportType {
    switch (labReportType) {
      case 'blood_sugar':
        return 'Blood Sugar';
      case 'cholesterol':
        return 'Cholesterol';
      case 'liver_function':
        return 'Liver Function';
      case 'kidney_function':
        return 'Kidney Function';
      case 'thyroid_function':
        return 'Thyroid Function';
      case 'complete_blood_count':
        return 'Complete Blood Count';
      case 'cardiac_markers':
        return 'Cardiac Markers';
      case 'vitamin_levels':
        return 'Vitamin Levels';
      case 'inflammatory_markers':
        return 'Inflammatory Markers';
      case 'other_lab_tests':
        return 'Other Lab Tests';
      default:
        return labReportType
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }
}

class TestResult {
  final String testName;
  final String value;
  final String unit;
  final String referenceRange;
  final String status;

  TestResult({
    required this.testName,
    required this.value,
    required this.unit,
    required this.referenceRange,
    required this.status,
  });

  factory TestResult.fromMap(Map<String, dynamic> map) {
    return TestResult(
      testName: map['test_name'] ?? '',
      value: map['value'] ?? '',
      unit: map['unit'] ?? '',
      referenceRange: map['reference_range'] ?? '',
      status: map['status'] ?? '',
    );
  }

  bool get isAbnormal =>
      status.toLowerCase() == 'high' || status.toLowerCase() == 'low';
}

class PatientInfo {
  final String? name;
  final String? id;

  PatientInfo({this.name, this.id});

  factory PatientInfo.fromMap(Map<String, dynamic> map) {
    return PatientInfo(name: map['name'], id: map['id']);
  }
}

class LabInfo {
  final String? name;
  final String? orderingPhysician;

  LabInfo({this.name, this.orderingPhysician});

  factory LabInfo.fromMap(Map<String, dynamic> map) {
    return LabInfo(
      name: map['name'],
      orderingPhysician: map['ordering_physician'],
    );
  }
}
