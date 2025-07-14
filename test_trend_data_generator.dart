import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

/// Test Data Generator for Trend Analysis
///
/// This script generates realistic lab report data to test trend analysis functionality.
/// It creates multiple lab report types with varying patterns and anomalies.
class TrendTestDataGenerator {
  static const String userId = 'test_user_trend_analysis';

  /// Lab report types with their normal ranges and units
  static const Map<String, Map<String, dynamic>> labTypes = {
    'Random Blood Sugar Test': {
      'tests': [
        {
          'name': 'Random Blood Sugar',
          'unit': 'mg/dl',
          'normal_min': 70.0,
          'normal_max': 140.0,
          'critical_low': 50.0,
          'critical_high': 200.0,
        },
      ],
    },
    'Hemoglobin A1c': {
      'tests': [
        {
          'name': 'Hemoglobin A1c',
          'unit': '%',
          'normal_min': 4.0,
          'normal_max': 5.6,
          'critical_low': 3.0,
          'critical_high': 10.0,
        },
      ],
    },
    'Complete Blood Count': {
      'tests': [
        {
          'name': 'Hemoglobin',
          'unit': 'g/dl',
          'normal_min': 12.0,
          'normal_max': 16.0,
          'critical_low': 8.0,
          'critical_high': 20.0,
        },
        {
          'name': 'White Blood Cell Count',
          'unit': 'cells/μl',
          'normal_min': 4000.0,
          'normal_max': 11000.0,
          'critical_low': 2000.0,
          'critical_high': 20000.0,
        },
        {
          'name': 'Platelet Count',
          'unit': 'cells/μl',
          'normal_min': 150000.0,
          'normal_max': 400000.0,
          'critical_low': 50000.0,
          'critical_high': 600000.0,
        },
      ],
    },
    'Lipid Profile': {
      'tests': [
        {
          'name': 'Total Cholesterol',
          'unit': 'mg/dl',
          'normal_min': 100.0,
          'normal_max': 200.0,
          'critical_low': 80.0,
          'critical_high': 300.0,
        },
        {
          'name': 'LDL Cholesterol',
          'unit': 'mg/dl',
          'normal_min': 50.0,
          'normal_max': 100.0,
          'critical_low': 30.0,
          'critical_high': 200.0,
        },
        {
          'name': 'HDL Cholesterol',
          'unit': 'mg/dl',
          'normal_min': 40.0,
          'normal_max': 80.0,
          'critical_low': 20.0,
          'critical_high': 100.0,
        },
        {
          'name': 'Triglycerides',
          'unit': 'mg/dl',
          'normal_min': 50.0,
          'normal_max': 150.0,
          'critical_low': 30.0,
          'critical_high': 400.0,
        },
      ],
    },
    'Liver Function Tests': {
      'tests': [
        {
          'name': 'ALT',
          'unit': 'U/L',
          'normal_min': 7.0,
          'normal_max': 40.0,
          'critical_low': 5.0,
          'critical_high': 200.0,
        },
        {
          'name': 'AST',
          'unit': 'U/L',
          'normal_min': 8.0,
          'normal_max': 45.0,
          'critical_low': 5.0,
          'critical_high': 200.0,
        },
        {
          'name': 'Total Bilirubin',
          'unit': 'mg/dl',
          'normal_min': 0.2,
          'normal_max': 1.2,
          'critical_low': 0.1,
          'critical_high': 5.0,
        },
      ],
    },
    'Kidney Function Tests': {
      'tests': [
        {
          'name': 'Creatinine',
          'unit': 'mg/dl',
          'normal_min': 0.6,
          'normal_max': 1.2,
          'critical_low': 0.3,
          'critical_high': 5.0,
        },
        {
          'name': 'Blood Urea Nitrogen',
          'unit': 'mg/dl',
          'normal_min': 7.0,
          'normal_max': 20.0,
          'critical_low': 5.0,
          'critical_high': 100.0,
        },
      ],
    },
  };

  static final Random _random = Random();

  /// Generate test data for all lab types
  static Future<void> generateAllTestData() async {
    print('🚀 Starting Test Data Generation for Trend Analysis...');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final db = FirebaseFirestore.instance;

    // Generate data for each lab type
    for (final labType in labTypes.keys) {
      print('\n📊 Generating data for: $labType');

      switch (labType) {
        case 'Random Blood Sugar Test':
          await _generateBloodSugarTrend(db, labType);
          break;
        case 'Hemoglobin A1c':
          await _generateA1cTrend(db, labType);
          break;
        case 'Complete Blood Count':
          await _generateCBCTrend(db, labType);
          break;
        case 'Lipid Profile':
          await _generateLipidTrend(db, labType);
          break;
        case 'Liver Function Tests':
          await _generateLiverTrend(db, labType);
          break;
        case 'Kidney Function Tests':
          await _generateKidneyTrend(db, labType);
          break;
      }
    }

    print('\n✅ Test data generation completed!');
    print('🔥 Now triggering trend analysis...');

    // Trigger trend analysis for each lab type
    for (final labType in labTypes.keys) {
      await _triggerTrendAnalysis(labType);
    }

    print('\n🎉 All done! You can now view trend analysis in your app.');
  }

  /// Generate Blood Sugar trend data with gradual increase over time
  static Future<void> _generateBloodSugarTrend(
    FirebaseFirestore db,
    String labType,
  ) async {
    final baseValue = 85.0; // Starting value
    final trend = 2.0; // mg/dl increase per month
    final noise = 15.0; // Random variation

    final reports = _generateTimeSeriesData(
      count: 12,
      baseValue: baseValue,
      trend: trend,
      noise: noise,
      startDate: DateTime.now().subtract(const Duration(days: 365)),
    );

    for (int i = 0; i < reports.length; i++) {
      final report = reports[i];
      await _createLabReport(
        db: db,
        labType: labType,
        testResults: [
          {
            'test_name': 'Random Blood Sugar',
            'value': report['value'],
            'unit': 'mg/dl',
            'reference_range': '70 - 140',
            'status': _getStatus(report['value'], 70.0, 140.0),
          },
        ],
        testDate: report['date'],
      );

      // Add some random variation in timing
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Generate A1c trend with seasonal variation
  static Future<void> _generateA1cTrend(
    FirebaseFirestore db,
    String labType,
  ) async {
    final baseValue = 5.2;
    final trend = 0.1; // % increase per measurement
    final noise = 0.3;

    final reports = _generateTimeSeriesData(
      count: 8,
      baseValue: baseValue,
      trend: trend,
      noise: noise,
      startDate: DateTime.now().subtract(const Duration(days: 240)),
      intervalDays: 30,
    );

    for (int i = 0; i < reports.length; i++) {
      final report = reports[i];
      await _createLabReport(
        db: db,
        labType: labType,
        testResults: [
          {
            'test_name': 'Hemoglobin A1c',
            'value': report['value'],
            'unit': '%',
            'reference_range': '4.0 - 5.6',
            'status': _getStatus(report['value'], 4.0, 5.6),
          },
        ],
        testDate: report['date'],
      );

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Generate CBC trend with some anomalies
  static Future<void> _generateCBCTrend(
    FirebaseFirestore db,
    String labType,
  ) async {
    final startDate = DateTime.now().subtract(const Duration(days: 300));

    for (int i = 0; i < 10; i++) {
      final date = startDate.add(Duration(days: i * 30));

      // Hemoglobin with slight decline trend
      final hgb = 14.0 - (i * 0.1) + (_random.nextDouble() - 0.5) * 0.8;

      // WBC with some spikes (infections)
      double wbc = 7000 + (_random.nextDouble() - 0.5) * 2000;
      if (i == 3 || i == 7) wbc *= 1.8; // Simulate infections

      // Platelets relatively stable
      final platelets = 250000 + (_random.nextDouble() - 0.5) * 50000;

      await _createLabReport(
        db: db,
        labType: labType,
        testResults: [
          {
            'test_name': 'Hemoglobin',
            'value': hgb,
            'unit': 'g/dl',
            'reference_range': '12.0 - 16.0',
            'status': _getStatus(hgb, 12.0, 16.0),
          },
          {
            'test_name': 'White Blood Cell Count',
            'value': wbc,
            'unit': 'cells/μl',
            'reference_range': '4000 - 11000',
            'status': _getStatus(wbc, 4000.0, 11000.0),
          },
          {
            'test_name': 'Platelet Count',
            'value': platelets,
            'unit': 'cells/μl',
            'reference_range': '150000 - 400000',
            'status': _getStatus(platelets, 150000.0, 400000.0),
          },
        ],
        testDate: date,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Generate Lipid Profile with improvement trend (diet/medication effect)
  static Future<void> _generateLipidTrend(
    FirebaseFirestore db,
    String labType,
  ) async {
    final startDate = DateTime.now().subtract(const Duration(days: 180));

    for (int i = 0; i < 6; i++) {
      final date = startDate.add(Duration(days: i * 30));
      final progress = i / 5.0; // 0 to 1 improvement

      // Total cholesterol decreasing
      final totalChol =
          250.0 - (progress * 70.0) + (_random.nextDouble() - 0.5) * 20.0;

      // LDL decreasing significantly
      final ldl =
          180.0 - (progress * 90.0) + (_random.nextDouble() - 0.5) * 15.0;

      // HDL slowly increasing
      final hdl = 35.0 + (progress * 15.0) + (_random.nextDouble() - 0.5) * 5.0;

      // Triglycerides decreasing
      final triglycerides =
          200.0 - (progress * 80.0) + (_random.nextDouble() - 0.5) * 30.0;

      await _createLabReport(
        db: db,
        labType: labType,
        testResults: [
          {
            'test_name': 'Total Cholesterol',
            'value': totalChol,
            'unit': 'mg/dl',
            'reference_range': '100 - 200',
            'status': _getStatus(totalChol, 100.0, 200.0),
          },
          {
            'test_name': 'LDL Cholesterol',
            'value': ldl,
            'unit': 'mg/dl',
            'reference_range': '50 - 100',
            'status': _getStatus(ldl, 50.0, 100.0),
          },
          {
            'test_name': 'HDL Cholesterol',
            'value': hdl,
            'unit': 'mg/dl',
            'reference_range': '40 - 80',
            'status': _getStatus(hdl, 40.0, 80.0),
          },
          {
            'test_name': 'Triglycerides',
            'value': triglycerides,
            'unit': 'mg/dl',
            'reference_range': '50 - 150',
            'status': _getStatus(triglycerides, 50.0, 150.0),
          },
        ],
        testDate: date,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Generate Liver Function trend with some elevation and recovery
  static Future<void> _generateLiverTrend(
    FirebaseFirestore db,
    String labType,
  ) async {
    final startDate = DateTime.now().subtract(const Duration(days: 240));

    for (int i = 0; i < 8; i++) {
      final date = startDate.add(Duration(days: i * 30));

      // Simulate liver stress peak around month 3-4, then recovery
      final stressFactor = i < 4 ? i / 3.0 : (7 - i) / 3.0;

      final alt =
          25.0 + (stressFactor * 40.0) + (_random.nextDouble() - 0.5) * 8.0;
      final ast =
          28.0 + (stressFactor * 35.0) + (_random.nextDouble() - 0.5) * 10.0;
      final bilirubin =
          0.8 + (stressFactor * 0.6) + (_random.nextDouble() - 0.5) * 0.2;

      await _createLabReport(
        db: db,
        labType: labType,
        testResults: [
          {
            'test_name': 'ALT',
            'value': alt,
            'unit': 'U/L',
            'reference_range': '7 - 40',
            'status': _getStatus(alt, 7.0, 40.0),
          },
          {
            'test_name': 'AST',
            'value': ast,
            'unit': 'U/L',
            'reference_range': '8 - 45',
            'status': _getStatus(ast, 8.0, 45.0),
          },
          {
            'test_name': 'Total Bilirubin',
            'value': bilirubin,
            'unit': 'mg/dl',
            'reference_range': '0.2 - 1.2',
            'status': _getStatus(bilirubin, 0.2, 1.2),
          },
        ],
        testDate: date,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Generate Kidney Function trend with gradual decline
  static Future<void> _generateKidneyTrend(
    FirebaseFirestore db,
    String labType,
  ) async {
    final startDate = DateTime.now().subtract(const Duration(days: 360));

    for (int i = 0; i < 12; i++) {
      final date = startDate.add(Duration(days: i * 30));
      final progression = i / 11.0;

      // Creatinine slowly increasing
      final creatinine =
          0.9 + (progression * 0.4) + (_random.nextDouble() - 0.5) * 0.1;

      // BUN increasing
      final bun =
          15.0 + (progression * 8.0) + (_random.nextDouble() - 0.5) * 3.0;

      await _createLabReport(
        db: db,
        labType: labType,
        testResults: [
          {
            'test_name': 'Creatinine',
            'value': creatinine,
            'unit': 'mg/dl',
            'reference_range': '0.6 - 1.2',
            'status': _getStatus(creatinine, 0.6, 1.2),
          },
          {
            'test_name': 'Blood Urea Nitrogen',
            'value': bun,
            'unit': 'mg/dl',
            'reference_range': '7 - 20',
            'status': _getStatus(bun, 7.0, 20.0),
          },
        ],
        testDate: date,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Generate time series data with trend and noise
  static List<Map<String, dynamic>> _generateTimeSeriesData({
    required int count,
    required double baseValue,
    required double trend,
    required double noise,
    required DateTime startDate,
    int intervalDays = 30,
  }) {
    final reports = <Map<String, dynamic>>[];

    for (int i = 0; i < count; i++) {
      final date = startDate.add(Duration(days: i * intervalDays));
      final trendValue = baseValue + (trend * i);
      final randomNoise = (_random.nextDouble() - 0.5) * noise;
      final finalValue = trendValue + randomNoise;

      reports.add({
        'date': date,
        'value': double.parse(finalValue.toStringAsFixed(1)),
      });
    }

    return reports;
  }

  /// Create a lab report document in Firestore
  static Future<void> _createLabReport({
    required FirebaseFirestore db,
    required String labType,
    required List<Map<String, dynamic>> testResults,
    required DateTime testDate,
  }) async {
    final docRef = db
        .collection('users')
        .doc(userId)
        .collection('lab_report_content')
        .doc();

    await docRef.set({
      'fileName':
          'test_${labType.replaceAll(' ', '_').toLowerCase()}_${testDate.millisecondsSinceEpoch}.pdf',
      'storagePath': 'test_data/${docRef.id}.pdf',
      'labReportType': labType,
      'extractedText': _generateExtractedText(labType, testResults, testDate),
      'testResults': testResults,
      'testDate': Timestamp.fromDate(testDate),
      'patientInfo': {'name': 'Test Patient', 'id': 'TEST123'},
      'labInfo': {'name': 'Test Laboratory', 'ordering_physician': 'Dr. Test'},
      'createdAt': FieldValue.serverTimestamp(),
      'extractionMethod': 'test_data_generator',
      'userSelectedType': false,
      'aiClassification': {
        'originalType': labType,
        'isExistingType': true,
        'reasoning': 'Generated test data',
        'confidence': 1.0,
      },
    });

    print(
      '   ✅ Created lab report: ${testResults.length} tests, date: ${testDate.toLocal().toString().split(' ')[0]}',
    );
  }

  /// Generate realistic extracted text for lab reports
  static String _generateExtractedText(
    String labType,
    List<Map<String, dynamic>> testResults,
    DateTime testDate,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('TEST LABORATORY REPORT');
    buffer.writeln('======================');
    buffer.writeln('');
    buffer.writeln('Patient Name: Test Patient');
    buffer.writeln('Patient ID: TEST123');
    buffer.writeln(
      'Date of Collection: ${testDate.toLocal().toString().split(' ')[0]}',
    );
    buffer.writeln('Report Type: $labType');
    buffer.writeln('');
    buffer.writeln('TEST RESULTS:');
    buffer.writeln('=============');

    for (final test in testResults) {
      buffer.writeln('');
      buffer.writeln('Test: ${test['test_name']}');
      buffer.writeln('Result: ${test['value']} ${test['unit']}');
      buffer.writeln('Reference Range: ${test['reference_range']}');
      buffer.writeln('Status: ${test['status']}');
    }

    buffer.writeln('');
    buffer.writeln('--- End of Report ---');
    buffer.writeln('Generated by Test Data Generator');

    return buffer.toString();
  }

  /// Determine test status based on value and normal range
  static String _getStatus(double value, double min, double max) {
    if (value < min) return 'LOW';
    if (value > max) return 'HIGH';
    return 'NORMAL';
  }

  /// Trigger trend analysis for a specific lab type
  static Future<void> _triggerTrendAnalysis(String labType) async {
    try {
      print('🔥 Triggering trend analysis for: $labType');

      // Here you would call your Firebase Cloud Function
      // For now, we'll just print a message
      print(
        '   📊 Trend analysis triggered (implement Firebase Function call here)',
      );

      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      print('   ❌ Error triggering trend analysis: $e');
    }
  }
}

/// Quick test function to generate realistic trend data
Future<void> generateQuickTestData() async {
  print('🧪 Quick Test Data Generation');
  print('============================');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final db = FirebaseFirestore.instance;
  const labType = 'Random Blood Sugar Test';

  // Generate 15 blood sugar readings over 12 months
  final startDate = DateTime.now().subtract(const Duration(days: 365));
  final random = Random();

  // Simulate pre-diabetic progression
  for (int i = 0; i < 15; i++) {
    final date = startDate.add(Duration(days: (i * 24) + random.nextInt(7)));

    // Start normal, progress to pre-diabetic with some variation
    final baseValue = 85.0 + (i * 3.5); // Gradual increase
    final noise = (random.nextDouble() - 0.5) * 25.0; // Daily variation
    final finalValue = (baseValue + noise).clamp(60.0, 180.0);

    await TrendTestDataGenerator._createLabReport(
      db: db,
      labType: labType,
      testResults: [
        {
          'test_name': 'Random Blood Sugar',
          'value': double.parse(finalValue.toStringAsFixed(1)),
          'unit': 'mg/dl',
          'reference_range': '70 - 140',
          'status': TrendTestDataGenerator._getStatus(finalValue, 70.0, 140.0),
        },
      ],
      testDate: date,
    );

    await Future.delayed(const Duration(milliseconds: 50));
  }

  print('✅ Generated 15 Random Blood Sugar Test reports');
  print('📈 Values range from ~85 to ~140 mg/dl showing gradual increase');
  print('🎯 Perfect for testing trend analysis with anomaly detection!');
  print('');
  print('🚀 Now run your app and check the Health Trends screen!');
}

/// Main function to run the test data generator
void main() async {
  print('Trend Analysis Test Data Generator');
  print('==================================');
  print('');
  print('Choose an option:');
  print('1. Generate comprehensive test data (all lab types)');
  print('2. Generate quick test data (blood sugar only)');
  print('');

  stdout.write('Enter choice (1 or 2): ');
  final choice = stdin.readLineSync();

  try {
    switch (choice) {
      case '1':
        await TrendTestDataGenerator.generateAllTestData();
        break;
      case '2':
        await generateQuickTestData();
        break;
      default:
        print('Invalid choice. Generating quick test data...');
        await generateQuickTestData();
    }
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }

  print('\n🎉 Done! Check your app to see the trend analysis graphs.');
  exit(0);
}
