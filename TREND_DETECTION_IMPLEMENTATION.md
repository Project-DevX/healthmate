# Automatic Lab Report Trend Detection and Graph Generation

## Overview

This document outlines the implementation of an intelligent trend detection system that automatically identifies patterns in lab reports after 5 reports in the same category and generates predictive graphs for vital parameters.

## 🎯 Goal

When a user accumulates 5 or more lab reports of the same type (e.g., "Complete Blood Count", "Lipid Panel", "Blood Sugar"), the system should:

1. **Auto-detect trends** in key vital parameters
2. **Generate interactive graphs** showing historical values
3. **Predict future variations** using AI/ML algorithms
4. **Provide health insights** and recommendations
5. **Alert for concerning trends** (rising, falling, or anomalous values)

## 🏗️ System Architecture

### Components to Implement:

1. **Trend Detection Engine** (Backend - Firebase Functions)
2. **Data Analysis Service** (AI-powered pattern recognition)
3. **Graph Generation Service** (Chart data preparation)
4. **Prediction Algorithm** (Future value forecasting)
5. **Frontend Visualization** (Interactive charts using Flutter)
6. **Alert System** (Notifications for concerning trends)

## 📊 Implementation Plan

### Phase 1: Backend Trend Detection Engine

#### **1.1 Trend Detection Function**

**File:** `/functions/index.js`

Add a new Cloud Function to detect trends when lab reports reach threshold:

```javascript
/**
 * Detect trends and generate analytics when lab report count threshold is reached
 */
exports.detectLabTrends = onCall(
  {cors: true, secrets: [geminiApiKey]},
  async (request) => {
    const {auth, data} = request;
    const {userId, labReportType} = data;
    
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }
    
    try {
      // Check if user has enough reports for trend analysis
      const trendAnalysis = await analyzeLabTrends(userId, labReportType);
      
      if (trendAnalysis.shouldGenerateGraphs) {
        // Generate trend data and predictions
        const trendData = await generateTrendData(userId, labReportType, trendAnalysis);
        
        // Store trend analysis results
        await storeTrendAnalysis(userId, labReportType, trendData);
        
        return {
          success: true,
          trendsDetected: true,
          trendData: trendData,
          message: `Trend analysis generated for ${labReportType}`
        };
      }
      
      return {
        success: true,
        trendsDetected: false,
        reportCount: trendAnalysis.reportCount,
        requiredCount: 5
      };
      
    } catch (error) {
      console.error('Error in detectLabTrends:', error);
      throw new HttpsError("internal", "Failed to detect lab trends");
    }
  }
);
```

#### **1.2 Trend Analysis Helper Functions**

```javascript
/**
 * Analyze lab reports to determine if trend detection should be triggered
 */
async function analyzeLabTrends(userId, labReportType) {
  const db = admin.firestore();
  
  // Get all lab reports of this type for the user
  const reportsSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('lab_report_content')
    .where('labReportType', '==', labReportType)
    .orderBy('createdAt', 'desc')
    .get();
  
  const reports = reportsSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  }));
  
  console.log(`📊 Found ${reports.length} reports of type: ${labReportType}`);
  
  const shouldGenerate = reports.length >= 5;
  
  if (shouldGenerate) {
    // Extract vital parameters from reports
    const vitalParameters = extractVitalParameters(reports, labReportType);
    
    return {
      shouldGenerateGraphs: true,
      reportCount: reports.length,
      reports: reports,
      vitalParameters: vitalParameters,
      timespan: calculateTimespan(reports)
    };
  }
  
  return {
    shouldGenerateGraphs: false,
    reportCount: reports.length,
    reports: reports
  };
}

/**
 * Extract vital parameters based on lab report type
 */
function extractVitalParameters(reports, labReportType) {
  const vitalMappings = {
    // Blood Sugar / Glucose
    'blood_sugar': ['glucose', 'blood_glucose', 'fasting_glucose', 'random_glucose'],
    'Blood Sugar': ['glucose', 'blood_glucose', 'fasting_glucose', 'random_glucose'],
    
    // Cholesterol / Lipid Panel
    'cholesterol': ['total_cholesterol', 'ldl', 'hdl', 'triglycerides'],
    'Cholesterol Panel': ['total_cholesterol', 'ldl', 'hdl', 'triglycerides'],
    'Lipid Panel': ['total_cholesterol', 'ldl', 'hdl', 'triglycerides'],
    
    // Complete Blood Count
    'complete_blood_count': ['hemoglobin', 'hematocrit', 'white_blood_cell', 'platelet_count'],
    'Complete Blood Count': ['hemoglobin', 'hematocrit', 'white_blood_cell', 'platelet_count'],
    
    // Liver Function Tests
    'liver_function': ['alt', 'ast', 'bilirubin', 'alkaline_phosphatase'],
    'Liver Function Tests': ['alt', 'ast', 'bilirubin', 'alkaline_phosphatase'],
    
    // Kidney Function Tests
    'kidney_function': ['creatinine', 'blood_urea_nitrogen', 'gfr'],
    'Kidney Function Tests': ['creatinine', 'blood_urea_nitrogen', 'gfr'],
    
    // Thyroid Function Tests
    'thyroid_function': ['tsh', 't3', 't4', 'free_t4'],
    'Thyroid Function Tests': ['tsh', 't3', 't4', 'free_t4'],
  };
  
  const relevantVitals = vitalMappings[labReportType] || [];
  const extractedData = {};
  
  // Initialize arrays for each vital parameter
  relevantVitals.forEach(vital => {
    extractedData[vital] = [];
  });
  
  // Extract values from each report
  reports.forEach(report => {
    const testDate = report.testDate || report.createdAt;
    const testResults = report.testResults || [];
    
    testResults.forEach(test => {
      const testName = test.testName || test.test_name || '';
      const value = parseFloat(test.value);
      const unit = test.unit || '';
      
      // Find matching vital parameter
      relevantVitals.forEach(vital => {
        if (isMatchingTest(testName, vital) && !isNaN(value)) {
          extractedData[vital].push({
            date: testDate,
            value: value,
            unit: unit,
            status: test.status || 'normal',
            reportId: report.id
          });
        }
      });
    });
  });
  
  // Filter out vitals with no data
  Object.keys(extractedData).forEach(vital => {
    if (extractedData[vital].length === 0) {
      delete extractedData[vital];
    } else {
      // Sort by date
      extractedData[vital].sort((a, b) => new Date(a.date) - new Date(b.date));
    }
  });
  
  return extractedData;
}

/**
 * Check if test name matches vital parameter
 */
function isMatchingTest(testName, vitalParameter) {
  const normalized = testName.toLowerCase().replace(/[^a-z0-9]/g, '');
  const vitalNormalized = vitalParameter.toLowerCase().replace(/_/g, '');
  
  const mappings = {
    'glucose': ['glucose', 'bloodglucose', 'fastingglucose', 'randomglucose'],
    'totalcholesterol': ['totalcholesterol', 'cholesterol'],
    'ldl': ['ldl', 'ldlcholesterol', 'lowdensity'],
    'hdl': ['hdl', 'hdlcholesterol', 'highdensity'],
    'triglycerides': ['triglycerides', 'triglyceride'],
    'hemoglobin': ['hemoglobin', 'hgb', 'hb'],
    'hematocrit': ['hematocrit', 'hct'],
    'whitebloodcell': ['wbc', 'whitebloodcell', 'leukocyte'],
    'plateletcount': ['platelet', 'plt'],
    'alt': ['alt', 'alanineaminotransferase'],
    'ast': ['ast', 'aspartateaminotransferase'],
    'bilirubin': ['bilirubin', 'totalbilirubin'],
    'alkalinephosphatase': ['alkalinephosphatase', 'alp'],
    'creatinine': ['creatinine', 'serumcreatinine'],
    'bloodureanitrogen': ['bun', 'bloodureanitrogen', 'urea'],
    'gfr': ['gfr', 'egfr', 'glomerularfiltration'],
    'tsh': ['tsh', 'thyroidstimulating'],
    't3': ['t3', 'triiodothyronine'],
    't4': ['t4', 'thyroxine'],
    'freet4': ['ft4', 'freet4', 'freethyroxine']
  };
  
  const possibleMatches = mappings[vitalNormalized] || [vitalNormalized];
  return possibleMatches.some(match => normalized.includes(match));
}

/**
 * Generate trend data with predictions
 */
async function generateTrendData(userId, labReportType, trendAnalysis) {
  const vitalParameters = trendAnalysis.vitalParameters;
  const trendData = {
    labReportType: labReportType,
    reportCount: trendAnalysis.reportCount,
    timespan: trendAnalysis.timespan,
    vitals: {},
    generatedAt: new Date().toISOString(),
    predictions: {}
  };
  
  // Analyze each vital parameter
  for (const [vitalName, dataPoints] of Object.entries(vitalParameters)) {
    if (dataPoints.length >= 3) { // Need at least 3 points for trend
      const analysis = analyzeVitalTrend(vitalName, dataPoints);
      trendData.vitals[vitalName] = analysis;
      
      // Generate predictions if trend is significant
      if (analysis.trendSignificance > 0.6) {
        const predictions = generatePredictions(vitalName, dataPoints, analysis);
        trendData.predictions[vitalName] = predictions;
      }
    }
  }
  
  return trendData;
}

/**
 * Analyze trend for a specific vital parameter
 */
function analyzeVitalTrend(vitalName, dataPoints) {
  const values = dataPoints.map(point => point.value);
  const dates = dataPoints.map(point => new Date(point.date));
  
  // Calculate basic statistics
  const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
  const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
  const stdDev = Math.sqrt(variance);
  
  // Calculate linear trend
  const trend = calculateLinearTrend(dates, values);
  
  // Determine trend direction and significance
  const trendDirection = trend.slope > 0.1 ? 'increasing' : 
                        trend.slope < -0.1 ? 'decreasing' : 'stable';
  
  const trendSignificance = Math.abs(trend.correlation);
  
  // Detect anomalies
  const anomalies = detectAnomalies(values, mean, stdDev);
  
  return {
    vitalName: vitalName,
    dataCount: dataPoints.length,
    currentValue: values[values.length - 1],
    meanValue: mean,
    standardDeviation: stdDev,
    trendDirection: trendDirection,
    trendSlope: trend.slope,
    trendSignificance: trendSignificance,
    correlation: trend.correlation,
    anomalies: anomalies,
    dataPoints: dataPoints,
    unit: dataPoints[0].unit,
    dateRange: {
      start: dates[0].toISOString(),
      end: dates[dates.length - 1].toISOString()
    }
  };
}

/**
 * Calculate linear trend using least squares regression
 */
function calculateLinearTrend(dates, values) {
  const n = dates.length;
  const x = dates.map((date, i) => i); // Use index as x-axis for simplicity
  const y = values;
  
  const sumX = x.reduce((sum, val) => sum + val, 0);
  const sumY = y.reduce((sum, val) => sum + val, 0);
  const sumXY = x.reduce((sum, val, i) => sum + val * y[i], 0);
  const sumXX = x.reduce((sum, val) => sum + val * val, 0);
  const sumYY = y.reduce((sum, val) => sum + val * val, 0);
  
  const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
  const intercept = (sumY - slope * sumX) / n;
  
  // Calculate correlation coefficient
  const correlation = (n * sumXY - sumX * sumY) / 
    Math.sqrt((n * sumXX - sumX * sumX) * (n * sumYY - sumY * sumY));
  
  return {
    slope: slope,
    intercept: intercept,
    correlation: correlation
  };
}

/**
 * Generate future predictions based on trend analysis
 */
function generatePredictions(vitalName, dataPoints, analysis) {
  const lastDate = new Date(dataPoints[dataPoints.length - 1].date);
  const predictions = [];
  
  // Generate predictions for next 3, 6, and 12 months
  const intervals = [3, 6, 12];
  
  intervals.forEach(months => {
    const futureDate = new Date(lastDate);
    futureDate.setMonth(futureDate.getMonth() + months);
    
    // Simple linear extrapolation (can be enhanced with ML models)
    const timeStep = months * 30; // Approximate days
    const predictedValue = analysis.currentValue + (analysis.trendSlope * timeStep);
    
    // Add confidence intervals based on standard deviation
    const confidenceInterval = analysis.standardDeviation * 1.96; // 95% confidence
    
    predictions.push({
      date: futureDate.toISOString(),
      predictedValue: predictedValue,
      confidenceInterval: {
        lower: predictedValue - confidenceInterval,
        upper: predictedValue + confidenceInterval
      },
      confidence: Math.max(0.3, 1 - (months / 12) * 0.7), // Decreasing confidence over time
      monthsAhead: months
    });
  });
  
  return predictions;
}

/**
 * Store trend analysis results in Firestore
 */
async function storeTrendAnalysis(userId, labReportType, trendData) {
  const db = admin.firestore();
  
  // Store in user's trend analysis collection
  const trendRef = db
    .collection('users')
    .doc(userId)
    .collection('trend_analysis')
    .doc(`${labReportType}_${Date.now()}`);
  
  await trendRef.set(trendData);
  
  // Update latest trend for quick access
  const latestTrendRef = db
    .collection('users')
    .doc(userId)
    .collection('latest_trends')
    .doc(labReportType);
  
  await latestTrendRef.set({
    ...trendData,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log(`📈 Trend analysis stored for ${userId} - ${labReportType}`);
}

/**
 * Detect anomalies in vital values
 */
function detectAnomalies(values, mean, stdDev) {
  const threshold = 2; // Number of standard deviations for anomaly detection
  const anomalies = [];
  
  values.forEach((value, index) => {
    const zScore = Math.abs((value - mean) / stdDev);
    if (zScore > threshold) {
      anomalies.push({
        index: index,
        value: value,
        zScore: zScore,
        severity: zScore > 3 ? 'high' : 'moderate'
      });
    }
  });
  
  return anomalies;
}

/**
 * Calculate timespan of reports
 */
function calculateTimespan(reports) {
  if (reports.length < 2) return { days: 0, months: 0 };
  
  const dates = reports
    .map(r => new Date(r.testDate || r.createdAt))
    .sort((a, b) => a - b);
  
  const startDate = dates[0];
  const endDate = dates[dates.length - 1];
  const diffTime = Math.abs(endDate - startDate);
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  const diffMonths = Math.round(diffDays / 30.44); // Average days per month
  
  return {
    days: diffDays,
    months: diffMonths,
    startDate: startDate.toISOString(),
    endDate: endDate.toISOString()
  };
}
```

### Phase 2: Backend Integration Points

#### **2.1 Trigger Trend Detection Automatically**

Modify the existing lab report classification function to trigger trend detection:

```javascript
// In extractLabReportContent function, after storing the lab report:
exports.extractLabReportContent = onCall(
  {cors: true, secrets: [geminiApiKey]},
  async (request) => {
    // ... existing extraction logic ...
    
    // After successful classification and storage:
    if (labReportType && labReportType !== 'other_lab_tests') {
      try {
        // Check if this triggers trend analysis threshold
        await checkTrendAnalysisTrigger(auth.uid, labReportType);
      } catch (error) {
        console.log('Trend analysis check failed:', error);
        // Don't fail the main operation
      }
    }
    
    return result;
  }
);

async function checkTrendAnalysisTrigger(userId, labReportType) {
  const db = admin.firestore();
  
  // Count reports of this type
  const countSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('lab_report_content')
    .where('labReportType', '==', labReportType)
    .get();
  
  const reportCount = countSnapshot.size;
  
  console.log(`📊 User ${userId} has ${reportCount} reports of type ${labReportType}`);
  
  // Trigger trend analysis if threshold reached
  if (reportCount >= 5) {
    // Check if trend analysis was already done recently
    const lastTrendRef = db
      .collection('users')
      .doc(userId)
      .collection('latest_trends')
      .doc(labReportType);
    
    const lastTrend = await lastTrendRef.get();
    const shouldUpdate = !lastTrend.exists || 
      (lastTrend.data()?.reportCount || 0) < reportCount;
    
    if (shouldUpdate) {
      console.log(`🎯 Triggering trend analysis for ${labReportType}`);
      
      // Call trend detection function
      const trendAnalysis = await analyzeLabTrends(userId, labReportType);
      if (trendAnalysis.shouldGenerateGraphs) {
        const trendData = await generateTrendData(userId, labReportType, trendAnalysis);
        await storeTrendAnalysis(userId, labReportType, trendData);
        
        // Send notification about new trends
        await sendTrendNotification(userId, labReportType, trendData);
      }
    }
  }
}

async function sendTrendNotification(userId, labReportType, trendData) {
  // Store notification for user
  const db = admin.firestore();
  
  const notification = {
    type: 'trend_analysis',
    title: 'New Health Trends Detected',
    message: `We've analyzed your ${labReportType} reports and found interesting trends.`,
    labReportType: labReportType,
    vitalsAnalyzed: Object.keys(trendData.vitals).length,
    hasAnomalies: Object.values(trendData.vitals).some(v => v.anomalies.length > 0),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    read: false
  };
  
  await db
    .collection('users')
    .doc(userId)
    .collection('notifications')
    .add(notification);
  
  console.log(`🔔 Trend notification sent to user ${userId}`);
}
```

### Phase 3: Frontend Services

#### **3.1 Trend Analysis Service**

**File:** `lib/services/trend_analysis_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrendAnalysisService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Get trend analysis for a specific lab report type
  static Future<TrendAnalysisData?> getTrendAnalysis(String labReportType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final trendDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('latest_trends')
          .doc(labReportType)
          .get();

      if (trendDoc.exists) {
        return TrendAnalysisData.fromFirestore(trendDoc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get trend analysis: $e');
    }
  }

  /// Get all available trend analyses for user
  static Future<List<TrendAnalysisData>> getAllTrendAnalyses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final trendsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('latest_trends')
          .get();

      return trendsSnapshot.docs
          .map((doc) => TrendAnalysisData.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get trend analyses: $e');
    }
  }

  /// Manually trigger trend detection for a lab report type
  static Future<bool> triggerTrendDetection(String labReportType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final callable = _functions.httpsCallable('detectLabTrends');
      final result = await callable.call({
        'userId': user.uid,
        'labReportType': labReportType,
      });

      return result.data['success'] ?? false;
    } catch (e) {
      throw Exception('Failed to trigger trend detection: $e');
    }
  }

  /// Check if trend analysis is available for a lab report type
  static Future<bool> isTrendAnalysisAvailable(String labReportType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Count reports of this type
      final countSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('lab_report_content')
          .where('labReportType', '==', labReportType)
          .get();

      return countSnapshot.size >= 5;
    } catch (e) {
      return false;
    }
  }
}

/// Data models for trend analysis
class TrendAnalysisData {
  final String labReportType;
  final int reportCount;
  final TimeSpanData timespan;
  final Map<String, VitalTrendData> vitals;
  final Map<String, List<PredictionData>> predictions;
  final DateTime generatedAt;

  TrendAnalysisData({
    required this.labReportType,
    required this.reportCount,
    required this.timespan,
    required this.vitals,
    required this.predictions,
    required this.generatedAt,
  });

  factory TrendAnalysisData.fromFirestore(Map<String, dynamic> data) {
    final vitalsMap = <String, VitalTrendData>{};
    final vitalsData = data['vitals'] as Map<String, dynamic>? ?? {};
    
    vitalsData.forEach((key, value) {
      vitalsMap[key] = VitalTrendData.fromMap(Map<String, dynamic>.from(value));
    });

    final predictionsMap = <String, List<PredictionData>>{};
    final predictionsData = data['predictions'] as Map<String, dynamic>? ?? {};
    
    predictionsData.forEach((key, value) {
      final predictionsList = (value as List<dynamic>)
          .map((item) => PredictionData.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      predictionsMap[key] = predictionsList;
    });

    return TrendAnalysisData(
      labReportType: data['labReportType'] ?? '',
      reportCount: data['reportCount'] ?? 0,
      timespan: TimeSpanData.fromMap(Map<String, dynamic>.from(data['timespan'] ?? {})),
      vitals: vitalsMap,
      predictions: predictionsMap,
      generatedAt: DateTime.parse(data['generatedAt'] ?? DateTime.now().toISOString()),
    );
  }

  bool get hasSignificantTrends {
    return vitals.values.any((vital) => vital.trendSignificance > 0.6);
  }

  bool get hasAnomalies {
    return vitals.values.any((vital) => vital.anomalies.isNotEmpty);
  }

  List<String> get concerningTrends {
    return vitals.entries
        .where((entry) => entry.value.isConcerrning)
        .map((entry) => entry.key)
        .toList();
  }
}

class VitalTrendData {
  final String vitalName;
  final int dataCount;
  final double currentValue;
  final double meanValue;
  final double standardDeviation;
  final String trendDirection;
  final double trendSlope;
  final double trendSignificance;
  final List<AnomalyData> anomalies;
  final List<DataPointData> dataPoints;
  final String unit;
  final DateRangeData dateRange;

  VitalTrendData({
    required this.vitalName,
    required this.dataCount,
    required this.currentValue,
    required this.meanValue,
    required this.standardDeviation,
    required this.trendDirection,
    required this.trendSlope,
    required this.trendSignificance,
    required this.anomalies,
    required this.dataPoints,
    required this.unit,
    required this.dateRange,
  });

  factory VitalTrendData.fromMap(Map<String, dynamic> data) {
    return VitalTrendData(
      vitalName: data['vitalName'] ?? '',
      dataCount: data['dataCount'] ?? 0,
      currentValue: (data['currentValue'] ?? 0).toDouble(),
      meanValue: (data['meanValue'] ?? 0).toDouble(),
      standardDeviation: (data['standardDeviation'] ?? 0).toDouble(),
      trendDirection: data['trendDirection'] ?? 'stable',
      trendSlope: (data['trendSlope'] ?? 0).toDouble(),
      trendSignificance: (data['trendSignificance'] ?? 0).toDouble(),
      anomalies: (data['anomalies'] as List<dynamic>? ?? [])
          .map((item) => AnomalyData.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      dataPoints: (data['dataPoints'] as List<dynamic>? ?? [])
          .map((item) => DataPointData.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      unit: data['unit'] ?? '',
      dateRange: DateRangeData.fromMap(Map<String, dynamic>.from(data['dateRange'] ?? {})),
    );
  }

  bool get isConcerrning {
    return trendSignificance > 0.7 && 
           (trendDirection == 'increasing' || trendDirection == 'decreasing') ||
           anomalies.any((anomaly) => anomaly.severity == 'high');
  }

  String get formattedTrendDirection {
    switch (trendDirection) {
      case 'increasing':
        return 'Trending Up ↗️';
      case 'decreasing':
        return 'Trending Down ↘️';
      case 'stable':
        return 'Stable ➡️';
      default:
        return trendDirection;
    }
  }

  String get trendInterpretation {
    if (trendSignificance < 0.3) {
      return 'No clear trend detected';
    } else if (trendSignificance < 0.6) {
      return 'Mild ${trendDirection} trend';
    } else if (trendSignificance < 0.8) {
      return 'Moderate ${trendDirection} trend';
    } else {
      return 'Strong ${trendDirection} trend';
    }
  }
}

class PredictionData {
  final DateTime date;
  final double predictedValue;
  final ConfidenceIntervalData confidenceInterval;
  final double confidence;
  final int monthsAhead;

  PredictionData({
    required this.date,
    required this.predictedValue,
    required this.confidenceInterval,
    required this.confidence,
    required this.monthsAhead,
  });

  factory PredictionData.fromMap(Map<String, dynamic> data) {
    return PredictionData(
      date: DateTime.parse(data['date']),
      predictedValue: (data['predictedValue'] ?? 0).toDouble(),
      confidenceInterval: ConfidenceIntervalData.fromMap(
        Map<String, dynamic>.from(data['confidenceInterval'] ?? {})
      ),
      confidence: (data['confidence'] ?? 0).toDouble(),
      monthsAhead: data['monthsAhead'] ?? 0,
    );
  }

  String get formattedDate {
    return '${date.month}/${date.year}';
  }

  String get confidencePercentage {
    return '${(confidence * 100).round()}%';
  }
}

// Additional data model classes...
class TimeSpanData {
  final int days;
  final int months;
  final DateTime startDate;
  final DateTime endDate;

  TimeSpanData({
    required this.days,
    required this.months,
    required this.startDate,
    required this.endDate,
  });

  factory TimeSpanData.fromMap(Map<String, dynamic> data) {
    return TimeSpanData(
      days: data['days'] ?? 0,
      months: data['months'] ?? 0,
      startDate: DateTime.parse(data['startDate'] ?? DateTime.now().toISOString()),
      endDate: DateTime.parse(data['endDate'] ?? DateTime.now().toISOString()),
    );
  }
}

class AnomalyData {
  final int index;
  final double value;
  final double zScore;
  final String severity;

  AnomalyData({
    required this.index,
    required this.value,
    required this.zScore,
    required this.severity,
  });

  factory AnomalyData.fromMap(Map<String, dynamic> data) {
    return AnomalyData(
      index: data['index'] ?? 0,
      value: (data['value'] ?? 0).toDouble(),
      zScore: (data['zScore'] ?? 0).toDouble(),
      severity: data['severity'] ?? 'low',
    );
  }
}

class DataPointData {
  final DateTime date;
  final double value;
  final String unit;
  final String status;
  final String reportId;

  DataPointData({
    required this.date,
    required this.value,
    required this.unit,
    required this.status,
    required this.reportId,
  });

  factory DataPointData.fromMap(Map<String, dynamic> data) {
    return DataPointData(
      date: DateTime.parse(data['date']),
      value: (data['value'] ?? 0).toDouble(),
      unit: data['unit'] ?? '',
      status: data['status'] ?? 'normal',
      reportId: data['reportId'] ?? '',
    );
  }
}

class DateRangeData {
  final DateTime start;
  final DateTime end;

  DateRangeData({required this.start, required this.end});

  factory DateRangeData.fromMap(Map<String, dynamic> data) {
    return DateRangeData(
      start: DateTime.parse(data['start'] ?? DateTime.now().toISOString()),
      end: DateTime.parse(data['end'] ?? DateTime.now().toISOString()),
    );
  }
}

class ConfidenceIntervalData {
  final double lower;
  final double upper;

  ConfidenceIntervalData({required this.lower, required this.upper});

  factory ConfidenceIntervalData.fromMap(Map<String, dynamic> data) {
    return ConfidenceIntervalData(
      lower: (data['lower'] ?? 0).toDouble(),
      upper: (data['upper'] ?? 0).toDouble(),
    );
  }
}
```

### Phase 4: Frontend UI Components

#### **4.1 Trend Analysis Screen**

**File:** `lib/screens/trend_analysis_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/trend_analysis_service.dart';

class TrendAnalysisScreen extends StatefulWidget {
  final String? labReportType;

  const TrendAnalysisScreen({Key? key, this.labReportType}) : super(key: key);

  @override
  State<TrendAnalysisScreen> createState() => _TrendAnalysisScreenState();
}

class _TrendAnalysisScreenState extends State<TrendAnalysisScreen> {
  List<TrendAnalysisData> _trendAnalyses = [];
  TrendAnalysisData? _selectedTrend;
  bool _isLoading = true;
  String? _selectedVital;

  @override
  void initState() {
    super.initState();
    _loadTrendAnalyses();
  }

  Future<void> _loadTrendAnalyses() async {
    try {
      setState(() => _isLoading = true);

      if (widget.labReportType != null) {
        final trend = await TrendAnalysisService.getTrendAnalysis(widget.labReportType!);
        if (trend != null) {
          setState(() {
            _trendAnalyses = [trend];
            _selectedTrend = trend;
          });
        }
      } else {
        final trends = await TrendAnalysisService.getAllTrendAnalyses();
        setState(() {
          _trendAnalyses = trends;
          if (trends.isNotEmpty) {
            _selectedTrend = trends.first;
          }
        });
      }

      if (_selectedTrend != null && _selectedTrend!.vitals.isNotEmpty) {
        _selectedVital = _selectedTrend!.vitals.keys.first;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trend analyses: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Trends'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrendAnalyses,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trendAnalyses.isEmpty
              ? _buildEmptyState()
              : _buildTrendAnalysisView(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Trend Analysis Available',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload at least 5 lab reports of the same type\nto generate trend analysis',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAnalysisView() {
    return Column(
      children: [
        if (_trendAnalyses.length > 1) _buildTrendSelector(),
        if (_selectedTrend != null) ...[
          _buildTrendSummary(),
          if (_selectedTrend!.vitals.isNotEmpty) _buildVitalSelector(),
          Expanded(child: _buildTrendChart()),
        ],
      ],
    );
  }

  Widget _buildTrendSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: DropdownButtonFormField<TrendAnalysisData>(
        value: _selectedTrend,
        decoration: const InputDecoration(
          labelText: 'Select Lab Report Type',
          border: OutlineInputBorder(),
        ),
        items: _trendAnalyses.map((trend) {
          return DropdownMenuItem(
            value: trend,
            child: Text(trend.labReportType),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedTrend = value;
            if (value != null && value.vitals.isNotEmpty) {
              _selectedVital = value.vitals.keys.first;
            }
          });
        },
      ),
    );
  }

  Widget _buildTrendSummary() {
    final trend = _selectedTrend!;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trend.labReportType,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSummaryItem('Reports', '${trend.reportCount}', Icons.description),
              const SizedBox(width: 16),
              _buildSummaryItem('Timespan', '${trend.timespan.months} months', Icons.calendar_today),
              const SizedBox(width: 16),
              _buildSummaryItem('Vitals', '${trend.vitals.length}', Icons.favorite),
            ],
          ),
          if (trend.hasAnomalies) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Anomalies detected',
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue[600]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildVitalSelector() {
    final vitals = _selectedTrend!.vitals.keys.toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedVital,
        decoration: const InputDecoration(
          labelText: 'Select Vital Parameter',
          border: OutlineInputBorder(),
        ),
        items: vitals.map((vital) {
          final vitalData = _selectedTrend!.vitals[vital]!;
          return DropdownMenuItem(
            value: vital,
            child: Row(
              children: [
                Text(_formatVitalName(vital)),
                const Spacer(),
                Text(
                  vitalData.formattedTrendDirection,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getTrendColor(vitalData.trendDirection),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedVital = value);
        },
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_selectedVital == null) {
      return const Center(child: Text('Select a vital parameter to view chart'));
    }

    final vitalData = _selectedTrend!.vitals[_selectedVital]!;
    final predictions = _selectedTrend!.predictions[_selectedVital] ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVitalInfo(vitalData),
          const SizedBox(height: 16),
          Expanded(child: _buildLineChart(vitalData, predictions)),
          if (predictions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPredictionsTable(predictions),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalInfo(VitalTrendData vitalData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatVitalName(vitalData.vitalName),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildVitalStat('Current', '${vitalData.currentValue.toStringAsFixed(1)} ${vitalData.unit}'),
              const SizedBox(width: 16),
              _buildVitalStat('Average', '${vitalData.meanValue.toStringAsFixed(1)} ${vitalData.unit}'),
              const SizedBox(width: 16),
              _buildVitalStat('Trend', vitalData.trendInterpretation),
            ],
          ),
          if (vitalData.anomalies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${vitalData.anomalies.length} anomalie(s) detected',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLineChart(VitalTrendData vitalData, List<PredictionData> predictions) {
    final dataPoints = vitalData.dataPoints;
    final spots = dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    // Add prediction points
    final predictionSpots = predictions.asMap().entries.map((entry) {
      return FlSpot(
        (dataPoints.length + entry.key).toDouble(),
        entry.value.predictedValue,
      );
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < dataPoints.length) {
                  final date = dataPoints[index].date;
                  return Text(
                    '${date.month}/${date.year.toString().substring(2)}',
                    style: const TextStyle(fontSize: 10),
                  );
                } else if (predictions.isNotEmpty) {
                  final predIndex = index - dataPoints.length;
                  if (predIndex < predictions.length) {
                    final date = predictions[predIndex].date;
                    return Text(
                      '${date.month}/${date.year.toString().substring(2)}',
                      style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                    );
                  }
                }
                return const Text('');
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          // Historical data line
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
          // Prediction line
          if (predictionSpots.isNotEmpty)
            LineChartBarData(
              spots: predictionSpots,
              isCurved: true,
              color: Colors.blue[300],
              barWidth: 2,
              dotData: FlDotData(show: true),
              dashArray: [5, 5], // Dashed line for predictions
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final isHistorical = barSpot.x < dataPoints.length;
                final prefix = isHistorical ? 'Actual: ' : 'Predicted: ';
                return LineTooltipItem(
                  '$prefix${barSpot.y.toStringAsFixed(1)} ${vitalData.unit}',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionsTable(List<PredictionData> predictions) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Text(
              'Future Predictions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...predictions.map((prediction) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    Text('${prediction.monthsAhead} months:'),
                    const Spacer(),
                    Text(
                      '${prediction.predictedValue.toStringAsFixed(1)} ± ${(prediction.confidenceInterval.upper - prediction.confidenceInterval.lower).toStringAsFixed(1)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        prediction.confidencePercentage,
                        style: TextStyle(fontSize: 10, color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _formatVitalName(String vital) {
    return vital
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getTrendColor(String trendDirection) {
    switch (trendDirection) {
      case 'increasing':
        return Colors.red;
      case 'decreasing':
        return Colors.orange;
      case 'stable':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
```

### Phase 5: Integration and Dependencies

#### **5.1 Add Required Dependencies**

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... existing dependencies ...
  fl_chart: ^0.68.0  # For interactive charts
  
dev_dependencies:
  # ... existing dev dependencies ...
```

#### **5.2 Add Navigation Integration**

Update existing screens to include trend analysis navigation:

```dart
// In medical_records_screen.dart or dashboard
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrendAnalysisScreen(),
      ),
    );
  },
  child: const Icon(Icons.trending_up),
),

// Or add as a tab/menu item
ListTile(
  leading: const Icon(Icons.analytics),
  title: const Text('Health Trends'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrendAnalysisScreen(),
      ),
    );
  },
),
```

### Phase 6: Testing and Deployment

#### **6.1 Backend Testing**

1. **Deploy Functions:**
```bash
cd functions
npm install
firebase deploy --only functions:detectLabTrends
```

2. **Test Trend Detection:**
```bash
# Upload 5+ lab reports of same type
# Monitor Firebase logs for trend detection triggers
# Verify Firestore structure under users/{userId}/trend_analysis/
```

#### **6.2 Frontend Testing**

1. **Test UI Components:**
```bash
flutter run
# Navigate to Trend Analysis screen
# Verify charts display correctly
# Test different lab report types
```

2. **Test Integration:**
```bash
# Upload new lab report
# Check if trend analysis updates automatically
# Verify predictions are generated
```

## 📈 Expected Results

After implementation:

1. **Automatic Detection:** System detects when 5+ reports of same type exist
2. **Intelligent Analysis:** AI extracts vital parameters and calculates trends
3. **Visual Graphs:** Interactive charts show historical values and predictions
4. **Health Insights:** Trend direction, significance, and anomaly detection
5. **Future Predictions:** 3, 6, and 12-month forecasts with confidence intervals
6. **Smart Notifications:** Alerts for concerning trends or anomalies

## 🔄 Enhancement Opportunities

1. **Machine Learning Integration:** Replace linear regression with ML models
2. **Reference Range Alerts:** Compare trends against medical normal ranges
3. **Correlation Analysis:** Find relationships between different vital parameters
4. **Doctor Integration:** Share trend reports with healthcare providers
5. **Export Capabilities:** PDF reports for medical consultations
6. **Advanced Analytics:** Seasonal patterns, risk assessment, health scores

This comprehensive system will provide users with valuable insights into their health trends and help them make informed decisions about their healthcare journey.
