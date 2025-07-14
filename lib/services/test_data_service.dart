import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simple test function to generate trend analysis data from within your Flutter app
class TrendAnalysisTestData {
  static final Random _random = Random();

  /// Generate test data for trend analysis - call this from your Flutter app
  static Future<void> generateTestData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to generate test data');
    }

    print('🚀 Generating test data for trend analysis...');

    // Generate Random Blood Sugar Test data (15 reports over 12 months)
    await _generateBloodSugarTestData(user.uid);

    // Generate Hemoglobin A1c data (6 reports over 6 months)
    await _generateA1cTestData(user.uid);

    // Generate Complete Blood Count data (8 reports over 8 months)
    await _generateCBCTestData(user.uid);

    print('✅ Test data generation completed!');
    print('📊 Generated data for 3 lab types with realistic trends');
    print('🎯 Go to Health Trends screen to see the analysis!');
  }

  /// Generate Blood Sugar test data with gradual increase (pre-diabetic progression)
  static Future<void> _generateBloodSugarTestData(String userId) async {
    print('📈 Generating Random Blood Sugar Test data...');

    final startDate = DateTime.now().subtract(const Duration(days: 365));

    for (int i = 0; i < 15; i++) {
      // Spread reports over 12 months with some randomness
      final date = startDate.add(Duration(days: (i * 24) + _random.nextInt(7)));

      // Simulate progression from normal to pre-diabetic
      final baseValue = 85.0 + (i * 3.2); // Gradual increase
      final dailyVariation = (_random.nextDouble() - 0.5) * 25.0;
      final finalValue = (baseValue + dailyVariation).clamp(60.0, 180.0);

      // Add some anomalies (high spikes)
      double testValue = finalValue;
      if (i == 7 || i == 12) {
        testValue += 40.0; // Simulate stress or illness spikes
      }

      await _createLabReport(
        userId: userId,
        labType: 'Random Blood Sugar Test',
        testResults: [
          {
            'test_name': 'Random Blood Sugar',
            'value': double.parse(testValue.toStringAsFixed(1)),
            'unit': 'mg/dl',
            'reference_range': '70 - 140',
            'status': _getStatus(testValue, 70.0, 140.0),
          },
        ],
        testDate: date,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    }

    print('   ✅ Created 15 Random Blood Sugar reports');
  }

  /// Generate A1c test data showing improvement then plateau
  static Future<void> _generateA1cTestData(String userId) async {
    print('📉 Generating Hemoglobin A1c data...');

    final startDate = DateTime.now().subtract(const Duration(days: 180));

    for (int i = 0; i < 6; i++) {
      final date = startDate.add(Duration(days: i * 30));

      // Start high, improve, then plateau
      double a1cValue;
      if (i < 3) {
        a1cValue = 6.8 - (i * 0.4); // Improvement phase
      } else {
        a1cValue = 5.6 + (_random.nextDouble() - 0.5) * 0.3; // Plateau phase
      }

      await _createLabReport(
        userId: userId,
        labType: 'Hemoglobin A1c',
        testResults: [
          {
            'test_name': 'Hemoglobin A1c',
            'value': double.parse(a1cValue.toStringAsFixed(1)),
            'unit': '%',
            'reference_range': '4.0 - 5.6',
            'status': _getStatus(a1cValue, 4.0, 5.6),
          },
        ],
        testDate: date,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    }

    print('   ✅ Created 6 Hemoglobin A1c reports');
  }

  /// Generate CBC data with some interesting patterns
  static Future<void> _generateCBCTestData(String userId) async {
    print('🩸 Generating Complete Blood Count data...');

    final startDate = DateTime.now().subtract(const Duration(days: 240));

    for (int i = 0; i < 8; i++) {
      final date = startDate.add(Duration(days: i * 30));

      // Hemoglobin with slight decline trend
      final hgb = 14.5 - (i * 0.15) + (_random.nextDouble() - 0.5) * 0.8;

      // WBC with infection spikes
      double wbc = 6500 + (_random.nextDouble() - 0.5) * 1500;
      if (i == 2 || i == 6) {
        wbc *= 1.6; // Simulate infections
      }

      // Platelets relatively stable with one low point
      double platelets = 280000 + (_random.nextDouble() - 0.5) * 40000;
      if (i == 4) {
        platelets *= 0.6; // Simulate temporary drop
      }

      await _createLabReport(
        userId: userId,
        labType: 'Complete Blood Count',
        testResults: [
          {
            'test_name': 'Hemoglobin',
            'value': double.parse(hgb.toStringAsFixed(1)),
            'unit': 'g/dl',
            'reference_range': '12.0 - 16.0',
            'status': _getStatus(hgb, 12.0, 16.0),
          },
          {
            'test_name': 'White Blood Cell Count',
            'value': double.parse(wbc.toStringAsFixed(0)),
            'unit': 'cells/μl',
            'reference_range': '4000 - 11000',
            'status': _getStatus(wbc, 4000.0, 11000.0),
          },
          {
            'test_name': 'Platelet Count',
            'value': double.parse(platelets.toStringAsFixed(0)),
            'unit': 'cells/μl',
            'reference_range': '150000 - 400000',
            'status': _getStatus(platelets, 150000.0, 400000.0),
          },
        ],
        testDate: date,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    }

    print('   ✅ Created 8 Complete Blood Count reports');
  }

  /// Create a lab report document in Firestore
  static Future<void> _createLabReport({
    required String userId,
    required String labType,
    required List<Map<String, dynamic>> testResults,
    required DateTime testDate,
  }) async {
    final db = FirebaseFirestore.instance;
    final docRef = db
        .collection('users')
        .doc(userId)
        .collection('lab_report_content')
        .doc();

    final timestamp = Timestamp.fromDate(testDate);

    await docRef.set({
      'fileName':
          'test_${labType.replaceAll(' ', '_').toLowerCase()}_${testDate.millisecondsSinceEpoch}.pdf',
      'storagePath': 'test_data/${docRef.id}.pdf',
      'labReportType': labType,
      'extractedText': _generateExtractedText(labType, testResults, testDate),
      'testResults': testResults,
      'testDate': timestamp,
      'patientInfo': {'name': 'Test Patient', 'id': 'TEST123'},
      'labInfo': {
        'name': 'HealthMate Test Lab',
        'ordering_physician': 'Dr. Test Physician',
      },
      'createdAt': FieldValue.serverTimestamp(),
      'extractionMethod': 'test_data_generator',
      'userSelectedType': false,
      'aiClassification': {
        'originalType': labType,
        'isExistingType': true,
        'reasoning': 'Generated test data for trend analysis',
        'confidence': 1.0,
      },
    });
  }

  /// Generate realistic extracted text for lab reports
  static String _generateExtractedText(
    String labType,
    List<Map<String, dynamic>> testResults,
    DateTime testDate,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('HEALTHMATE TEST LABORATORY');
    buffer.writeln('==========================');
    buffer.writeln('');
    buffer.writeln('Patient Name: Test Patient');
    buffer.writeln('Patient ID: TEST123');
    buffer.writeln(
      'Date of Collection: ${testDate.toLocal().toString().split(' ')[0]}',
    );
    buffer.writeln('Report Type: $labType');
    buffer.writeln('Ordering Physician: Dr. Test Physician');
    buffer.writeln('');
    buffer.writeln('LABORATORY RESULTS:');
    buffer.writeln('==================');

    for (final test in testResults) {
      buffer.writeln('');
      buffer.writeln('${test['test_name']}:');
      buffer.writeln('  Result: ${test['value']} ${test['unit']}');
      buffer.writeln('  Reference: ${test['reference_range']}');
      buffer.writeln('  Status: ${test['status']}');
      if (test['status'] != 'NORMAL') {
        buffer.writeln('  Flag: ${test['status'] == 'HIGH' ? 'H' : 'L'}');
      }
    }

    buffer.writeln('');
    buffer.writeln('NOTES:');
    buffer.writeln('======');
    buffer.writeln(
      'This is test data generated for trend analysis demonstration.',
    );
    buffer.writeln(
      'Values are simulated and should not be used for medical decisions.',
    );
    buffer.writeln('');
    buffer.writeln('--- End of Report ---');
    buffer.writeln('Generated: ${DateTime.now().toLocal()}');

    return buffer.toString();
  }

  /// Determine test status based on value and normal range
  static String _getStatus(double value, double min, double max) {
    if (value < min) return 'LOW';
    if (value > max) return 'HIGH';
    return 'NORMAL';
  }

  /// Generate quick blood sugar data only (for fastest testing)
  static Future<void> generateQuickBloodSugarData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to generate test data');
    }

    print('⚡ Generating quick blood sugar test data...');
    await _generateBloodSugarTestData(user.uid);
    print('🚀 Done! Check your Health Trends screen now!');
  }

  /// Clear all test data (cleanup function)
  static Future<void> clearTestData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to clear test data');
    }

    print('🧹 Clearing test data...');

    final db = FirebaseFirestore.instance;
    final snapshot = await db
        .collection('users')
        .doc(user.uid)
        .collection('lab_report_content')
        .where('extractionMethod', isEqualTo: 'test_data_generator')
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }

    print('✅ Test data cleared!');
  }
}
