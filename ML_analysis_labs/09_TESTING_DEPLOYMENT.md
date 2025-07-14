# Testing and Deployment Guide

## Overview

This document provides comprehensive testing strategies and deployment instructions for the trend analysis system.

## Testing Strategy

### 1. Backend Testing

#### Firebase Functions Testing

**Test the trend detection function:**

```bash
# Navigate to functions directory
cd functions

# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Start local emulator for testing
firebase emulators:start --only functions,firestore

# Test the function locally
curl -X POST http://localhost:5001/your-project-id/us-central1/detectLabTrends \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-test-token" \
  -d '{
    "data": {
      "userId": "test-user-id",
      "labReportType": "Blood Sugar"
    }
  }'
```

**Create test data script:**

**File:** `functions/test-data.js`

```javascript
const admin = require('firebase-admin');
const { initializeApp } = require('firebase-admin/app');

// Initialize admin (for testing only)
if (!admin.apps.length) {
  initializeApp();
}

const db = admin.firestore();

async function createTestLabReports(userId, labReportType, count = 5) {
  const testReports = [];
  
  for (let i = 0; i < count; i++) {
    const testDate = new Date();
    testDate.setMonth(testDate.getMonth() - i);
    
    const report = {
      labReportType: labReportType,
      testDate: testDate.toISOString(),
      testResults: [
        {
          testName: 'Glucose',
          value: 90 + (Math.random() * 40), // Random value between 90-130
          unit: 'mg/dL',
          status: 'normal'
        }
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    const docRef = await db
      .collection('users')
      .doc(userId)
      .collection('lab_report_content')
      .add(report);
    
    testReports.push({ id: docRef.id, ...report });
  }
  
  console.log(`Created ${count} test lab reports for ${labReportType}`);
  return testReports;
}

async function testTrendDetection() {
  const testUserId = 'test-user-123';
  const labReportType = 'Blood Sugar';
  
  try {
    // Create test data
    await createTestLabReports(testUserId, labReportType, 6);
    
    // Import and test trend functions
    const { analyzeLabTrends, generateTrendData, storeTrendAnalysis } = require('./index');
    
    // Test trend analysis
    const trendAnalysis = await analyzeLabTrends(testUserId, labReportType);
    console.log('Trend Analysis:', trendAnalysis);
    
    if (trendAnalysis.shouldGenerateGraphs) {
      const trendData = await generateTrendData(testUserId, labReportType, trendAnalysis);
      console.log('Generated Trend Data:', JSON.stringify(trendData, null, 2));
      
      await storeTrendAnalysis(testUserId, labReportType, trendData);
      console.log('✅ Trend analysis stored successfully');
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

// Run tests
if (require.main === module) {
  testTrendDetection();
}

module.exports = { createTestLabReports, testTrendDetection };
```

**Run backend tests:**

```bash
# Run the test script
node test-data.js

# Run Jest tests if configured
npm test

# Deploy functions to staging
firebase use staging  # Switch to staging project
firebase deploy --only functions
```

### 2. Frontend Testing

#### Unit Tests

**File:** `test/models/trend_data_models_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/models/trend_data_models.dart';

void main() {
  group('TrendAnalysisData', () {
    test('should parse from Firestore data correctly', () {
      final firestoreData = {
        'labReportType': 'Blood Sugar',
        'reportCount': 5,
        'timespan': {
          'days': 150,
          'months': 5,
          'startDate': '2024-01-01T00:00:00.000Z',
          'endDate': '2024-06-01T00:00:00.000Z'
        },
        'vitals': {
          'glucose': {
            'vitalName': 'glucose',
            'dataCount': 5,
            'currentValue': 110.0,
            'meanValue': 105.0,
            'standardDeviation': 8.5,
            'trendDirection': 'increasing',
            'trendSlope': 0.5,
            'trendSignificance': 0.75,
            'anomalies': [],
            'dataPoints': [],
            'unit': 'mg/dL',
            'dateRange': {
              'start': '2024-01-01T00:00:00.000Z',
              'end': '2024-06-01T00:00:00.000Z'
            }
          }
        },
        'predictions': {},
        'generatedAt': '2024-06-01T12:00:00.000Z'
      };

      final trendData = TrendAnalysisData.fromFirestore(firestoreData);

      expect(trendData.labReportType, equals('Blood Sugar'));
      expect(trendData.reportCount, equals(5));
      expect(trendData.vitals.length, equals(1));
      expect(trendData.vitals['glucose']?.currentValue, equals(110.0));
      expect(trendData.hasSignificantTrends, isTrue);
    });

    test('should calculate health summary correctly', () {
      final trendData = _createSampleTrendData();
      final summary = trendData.summary;

      expect(summary.totalVitals, equals(1));
      expect(summary.healthScore, greaterThan(0));
      expect(summary.healthScore, lessThanOrEqualTo(100));
    });
  });

  group('VitalTrendData', () {
    test('should identify concerning trends', () {
      final vitalData = VitalTrendData(
        vitalName: 'glucose',
        dataCount: 5,
        currentValue: 110.0,
        meanValue: 105.0,
        standardDeviation: 8.5,
        trendDirection: 'increasing',
        trendSlope: 2.0,
        trendSignificance: 0.85, // High significance
        anomalies: [],
        dataPoints: [],
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 6, 1),
        ),
      );

      expect(vitalData.isConcerning, isTrue);
      expect(vitalData.trendStrength, equals(TrendStrength.strong));
    });
  });
}

TrendAnalysisData _createSampleTrendData() {
  return TrendAnalysisData(
    labReportType: 'Blood Sugar',
    reportCount: 5,
    timespan: TimeSpanData(
      days: 150,
      months: 5,
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 6, 1),
    ),
    vitals: {
      'glucose': VitalTrendData(
        vitalName: 'glucose',
        dataCount: 5,
        currentValue: 110.0,
        meanValue: 105.0,
        standardDeviation: 8.5,
        trendDirection: 'stable',
        trendSlope: 0.1,
        trendSignificance: 0.3,
        anomalies: [],
        dataPoints: [],
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 6, 1),
        ),
      ),
    },
    predictions: {},
    generatedAt: DateTime.now(),
  );
}
```

**File:** `test/services/trend_analysis_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthmate/services/trend_analysis_service.dart';

// Generate mocks
@GenerateMocks([FirebaseFirestore, CollectionReference, DocumentReference, DocumentSnapshot])
void main() {
  group('TrendAnalysisService', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockCollection;
    late MockDocumentReference mockDocument;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference();
      mockDocument = MockDocumentReference();
    });

    test('should return null when no trend analysis exists', () async {
      // Mock Firestore calls
      when(mockDocument.get()).thenAnswer((_) async {
        final mockSnapshot = MockDocumentSnapshot();
        when(mockSnapshot.exists).thenReturn(false);
        return mockSnapshot;
      });

      // Test would need proper mocking setup
      // This is a simplified example
    });
  });
}
```

#### Widget Tests

**File:** `test/widgets/trend_chart_widget_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/widgets/trend_chart_widget.dart';
import 'package:healthmate/models/trend_data_models.dart';

void main() {
  group('TrendChartWidget', () {
    testWidgets('should display chart with vital data', (WidgetTester tester) async {
      final vitalData = _createSampleVitalData();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrendChartWidget(
              vitalData: vitalData,
              predictions: [],
            ),
          ),
        ),
      );

      // Verify chart is displayed
      expect(find.byType(TrendChartWidget), findsOneWidget);
      
      // Verify vital name is displayed
      expect(find.text('Glucose'), findsOneWidget);
      
      // Verify current value is displayed
      expect(find.textContaining('110.0'), findsOneWidget);
    });

    testWidgets('should show predictions when available', (WidgetTester tester) async {
      final vitalData = _createSampleVitalData();
      final predictions = [
        PredictionData(
          date: DateTime.now().add(const Duration(days: 90)),
          predictedValue: 115.0,
          confidenceInterval: ConfidenceIntervalData(lower: 110.0, upper: 120.0),
          confidence: 0.8,
          monthsAhead: 3,
        ),
      ];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrendChartWidget(
              vitalData: vitalData,
              predictions: predictions,
            ),
          ),
        ),
      );

      // Verify predictions checkbox is shown
      expect(find.text('Show Predictions'), findsOneWidget);
      expect(find.byType(Checkbox), findsWidgets);
    });
  });
}

VitalTrendData _createSampleVitalData() {
  return VitalTrendData(
    vitalName: 'glucose',
    dataCount: 5,
    currentValue: 110.0,
    meanValue: 105.0,
    standardDeviation: 8.5,
    trendDirection: 'stable',
    trendSlope: 0.1,
    trendSignificance: 0.3,
    anomalies: [],
    dataPoints: [
      DataPointData(
        date: DateTime(2024, 1, 1),
        value: 100.0,
        unit: 'mg/dL',
        status: 'normal',
        reportId: 'report1',
      ),
      DataPointData(
        date: DateTime(2024, 2, 1),
        value: 105.0,
        unit: 'mg/dL',
        status: 'normal',
        reportId: 'report2',
      ),
    ],
    unit: 'mg/dL',
    dateRange: DateRangeData(
      start: DateTime(2024, 1, 1),
      end: DateTime(2024, 6, 1),
    ),
  );
}
```

#### Integration Tests

**File:** `integration_test/trend_analysis_flow_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:healthmate/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Trend Analysis Integration Tests', () {
    testWidgets('should navigate to trend analysis and display data', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login flow (adapt to your auth flow)
      await _performLogin(tester);

      // Navigate to trend analysis
      await tester.tap(find.text('Health Trends'));
      await tester.pumpAndSettle();

      // Verify trend analysis screen is displayed
      expect(find.text('Health Trends'), findsOneWidget);
      
      // If no data, should show empty state
      // If data exists, should show charts and analysis
    });

    testWidgets('should trigger manual trend analysis', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await _performLogin(tester);
      
      // Navigate to trend analysis
      await tester.tap(find.text('Health Trends'));
      await tester.pumpAndSettle();

      // Tap refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // Should show loading or success message
    });
  });
}

Future<void> _performLogin(WidgetTester tester) async {
  // Implement your login flow here
  // This depends on your authentication setup
}
```

### 3. Performance Testing

#### Load Testing Script

**File:** `scripts/load_test.js`

```javascript
const admin = require('firebase-admin');
const { performance } = require('perf_hooks');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function performanceTest() {
  const db = admin.firestore();
  const testUserId = 'performance-test-user';
  const labReportType = 'Blood Sugar';
  
  console.log('🚀 Starting performance test...');
  
  // Test 1: Create large dataset
  console.log('📊 Creating test dataset...');
  const startCreate = performance.now();
  
  for (let i = 0; i < 50; i++) {
    const testDate = new Date();
    testDate.setMonth(testDate.getMonth() - i);
    
    await db
      .collection('users')
      .doc(testUserId)
      .collection('lab_report_content')
      .add({
        labReportType: labReportType,
        testDate: testDate.toISOString(),
        testResults: [
          {
            testName: 'Glucose',
            value: 90 + (Math.random() * 40),
            unit: 'mg/dL',
            status: 'normal'
          }
        ],
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
  }
  
  const createTime = performance.now() - startCreate;
  console.log(`✅ Created 50 reports in ${createTime.toFixed(2)}ms`);
  
  // Test 2: Trend analysis performance
  console.log('📈 Testing trend analysis performance...');
  const startAnalysis = performance.now();
  
  // Import trend functions (adjust path as needed)
  const { analyzeLabTrends, generateTrendData } = require('../functions/index');
  
  const trendAnalysis = await analyzeLabTrends(testUserId, labReportType);
  const trendData = await generateTrendData(testUserId, labReportType, trendAnalysis);
  
  const analysisTime = performance.now() - startAnalysis;
  console.log(`✅ Trend analysis completed in ${analysisTime.toFixed(2)}ms`);
  
  // Test 3: Multiple concurrent requests
  console.log('🔄 Testing concurrent requests...');
  const startConcurrent = performance.now();
  
  const promises = [];
  for (let i = 0; i < 5; i++) {
    promises.push(analyzeLabTrends(`user-${i}`, labReportType));
  }
  
  await Promise.all(promises);
  const concurrentTime = performance.now() - startConcurrent;
  console.log(`✅ 5 concurrent analyses completed in ${concurrentTime.toFixed(2)}ms`);
  
  // Cleanup
  console.log('🧹 Cleaning up test data...');
  const batch = db.batch();
  const snapshot = await db
    .collection('users')
    .doc(testUserId)
    .collection('lab_report_content')
    .get();
  
  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  
  await batch.commit();
  console.log('✅ Test data cleaned up');
  
  console.log('\n📊 Performance Test Results:');
  console.log(`- Data Creation: ${createTime.toFixed(2)}ms`);
  console.log(`- Trend Analysis: ${analysisTime.toFixed(2)}ms`);
  console.log(`- Concurrent Requests: ${concurrentTime.toFixed(2)}ms`);
}

// Run performance test
performanceTest().catch(console.error);
```

## Deployment

### 1. Environment Setup

**Production Environment Variables:**

```bash
# Firebase project configuration
export FIREBASE_PROJECT_ID="your-prod-project-id"
export FIREBASE_API_KEY="your-prod-api-key"

# Set Firebase project
firebase use production
```

**Staging Environment:**

```bash
# Use staging project for testing
firebase use staging

# Deploy to staging first
firebase deploy
```

### 2. Backend Deployment

**Deploy Firebase Functions:**

```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Run linting
npm run lint

# Run tests
npm test

# Deploy to staging
firebase use staging
firebase deploy --only functions

# Test staging deployment
npm run test:staging

# Deploy to production
firebase use production
firebase deploy --only functions
```

**Firestore Security Rules:**

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Trend analysis data
    match /users/{userId}/trend_analysis/{trendId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /users/{userId}/latest_trends/{labType} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /users/{userId}/notifications/{notificationId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Existing lab report rules
    match /users/{userId}/lab_report_content/{reportId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

**Deploy Firestore Rules:**

```bash
firebase deploy --only firestore:rules
```

### 3. Frontend Deployment

#### Build Configuration

**Android Release Build:**

```bash
# Clean previous builds
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release

# Verify build
flutter analyze
```

**iOS Release Build:**

```bash
# Clean and get dependencies
flutter clean
flutter pub get

# Build for iOS
flutter build ios --release

# Open in Xcode for signing and uploading
open ios/Runner.xcworkspace
```

#### App Store Deployment

**Google Play Store:**

1. **Prepare release:**
   ```bash
   flutter build appbundle --release --build-number=1
   ```

2. **Upload to Play Console:**
   - Go to Google Play Console
   - Create new release
   - Upload the `.aab` file from `build/app/outputs/bundle/release/`
   - Add release notes mentioning trend analysis feature

3. **Test internal release:**
   - Create internal testing track
   - Add test users
   - Verify trend analysis functionality

**Apple App Store:**

1. **Prepare release:**
   ```bash
   flutter build ios --release --build-number=1
   ```

2. **Upload via Xcode:**
   - Open `ios/Runner.xcworkspace`
   - Archive the app
   - Upload to App Store Connect

3. **App Store Connect:**
   - Add app information
   - Include screenshots of trend analysis
   - Submit for review

### 4. Monitoring and Analytics

#### Firebase Performance Monitoring

```dart
// Add to main.dart
import 'package:firebase_performance/firebase_performance.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Enable performance monitoring
  FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
  
  runApp(const MyApp());
}

// Add custom traces for trend analysis
class TrendAnalysisService {
  static Future<TrendAnalysisData?> getTrendAnalysis(String labReportType) async {
    final trace = FirebasePerformance.instance.newTrace('trend_analysis_fetch');
    trace.start();
    
    try {
      final result = await _fetchTrendAnalysis(labReportType);
      trace.putAttribute('lab_type', labReportType);
      trace.putAttribute('success', 'true');
      return result;
    } catch (e) {
      trace.putAttribute('success', 'false');
      trace.putAttribute('error', e.toString());
      rethrow;
    } finally {
      trace.stop();
    }
  }
}
```

#### Cloud Function Monitoring

```javascript
// In functions/index.js
const { logger } = require('firebase-functions');

exports.detectLabTrends = onCall(async (request) => {
  const startTime = Date.now();
  
  try {
    // ... existing logic ...
    
    logger.info('Trend analysis completed', {
      userId: request.auth.uid,
      labReportType: data.labReportType,
      duration: Date.now() - startTime,
      vitalsAnalyzed: Object.keys(trendData.vitals).length
    });
    
    return result;
  } catch (error) {
    logger.error('Trend analysis failed', {
      userId: request.auth.uid,
      error: error.message,
      duration: Date.now() - startTime
    });
    throw error;
  }
});
```

### 5. Rollback Strategy

**Function Rollback:**

```bash
# List previous deployments
firebase functions:log

# Rollback to previous version
firebase rollback functions

# Or rollback specific function
firebase rollback functions:detectLabTrends
```

**App Rollback:**

1. **Google Play:**
   - Use Play Console to rollback to previous version
   - Create hotfix release if needed

2. **App Store:**
   - Remove current version from sale
   - Re-submit previous version

**Data Rollback:**

```javascript
// Backup script before deployment
const admin = require('firebase-admin');

async function backupTrendData() {
  const db = admin.firestore();
  const backup = {};
  
  const usersSnapshot = await db.collection('users').get();
  
  for (const userDoc of usersSnapshot.docs) {
    const trendsSnapshot = await userDoc.ref
      .collection('latest_trends')
      .get();
    
    backup[userDoc.id] = trendsSnapshot.docs.map(doc => ({
      id: doc.id,
      data: doc.data()
    }));
  }
  
  // Save backup to Cloud Storage
  const bucket = admin.storage().bucket();
  const file = bucket.file(`backups/trends-${Date.now()}.json`);
  await file.save(JSON.stringify(backup));
  
  console.log('Backup completed');
}
```

## Monitoring and Maintenance

### Health Checks

**Function Health Check:**

```javascript
exports.healthCheck = onRequest((req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.FUNCTIONS_VERSION || '1.0.0'
  });
});
```

**App Health Check:**

```dart
// In app
class HealthCheckService {
  static Future<bool> checkSystemHealth() async {
    try {
      // Check Firebase connectivity
      await FirebaseFirestore.instance
          .collection('health_check')
          .doc('test')
          .get();
      
      // Check trend analysis service
      await TrendAnalysisService.getAllTrendAnalyses();
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
```

## Next Steps

Continue to **10_ENHANCEMENT_ROADMAP.md** for future improvements and advanced features that can be added to the trend analysis system.
