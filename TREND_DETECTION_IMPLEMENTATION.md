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
  final String modelType;
  final Map<String, dynamic>? mlInsights;
  final Map<String, List<FeatureImportanceData>>? featureImportance;

  TrendAnalysisData({
    required this.labReportType,
    required this.reportCount,
    required this.timespan,
    required this.vitals,
    required this.predictions,
    required this.generatedAt,
    required this.modelType,
    this.mlInsights,
    this.featureImportance,
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

    // Parse ML insights
    final mlInsightsMap = <String, dynamic>{};
    final mlInsightsData = data['mlInsights'] as Map<String, dynamic>? ?? {};
    mlInsightsData.forEach((key, value) {
      mlInsightsMap[key] = value;
    });

    // Parse feature importance
    final featureImportanceMap = <String, List<FeatureImportanceData>>{};
    vitalsData.forEach((vitalName, vitalData) {
      if (vitalData is Map<String, dynamic> && vitalData['featureImportance'] != null) {
        final importanceList = (vitalData['featureImportance'] as List<dynamic>)
            .map((item) => FeatureImportanceData.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        featureImportanceMap[vitalName] = importanceList;
      }
    });

    return TrendAnalysisData(
      labReportType: data['labReportType'] ?? '',
      reportCount: data['reportCount'] ?? 0,
      timespan: TimeSpanData.fromMap(Map<String, dynamic>.from(data['timespan'] ?? {})),
      vitals: vitalsMap,
      predictions: predictionsMap,
      generatedAt: DateTime.parse(data['generatedAt'] ?? DateTime.now().toISOString()),
      modelType: data['modelType'] ?? 'linear',
      mlInsights: mlInsightsMap.isNotEmpty ? mlInsightsMap : null,
      featureImportance: featureImportanceMap.isNotEmpty ? featureImportanceMap : null,
    );
  }

  bool get isMLEnhanced => modelType == 'xgboost';
  
  bool get hasCrossPatientInsights => 
    mlInsights?.isNotEmpty ?? false;
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
    return '${date.month}/${date.year.toString().substring(2)}';
  }

  String get confidencePercentage {
    return '${(confidence * 100).round()}%';
  }
}

class FeatureImportanceData {
  final String featureName;
  final double importance;
  final String interpretation;

  FeatureImportanceData({
    required this.featureName,
    required this.importance,
    required this.interpretation,
  });

  factory FeatureImportanceData.fromMap(Map<String, dynamic> data) {
    return FeatureImportanceData(
      featureName: data['feature_name'] ?? '',
      importance: (data['importance'] ?? 0).toDouble(),
      interpretation: data['interpretation'] ?? '',
    );
  }

  String get formattedImportance => '${(importance * 100).toStringAsFixed(1)}%';
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
  final String modelType;
  final Map<String, dynamic>? mlInsights;
  final Map<String, List<FeatureImportanceData>>? featureImportance;

  TrendAnalysisData({
    required this.labReportType,
    required this.reportCount,
    required this.timespan,
    required this.vitals,
    required this.predictions,
    required this.generatedAt,
    required this.modelType,
    this.mlInsights,
    this.featureImportance,
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

    // Parse ML insights
    final mlInsightsMap = <String, dynamic>{};
    final mlInsightsData = data['mlInsights'] as Map<String, dynamic>? ?? {};
    mlInsightsData.forEach((key, value) {
      mlInsightsMap[key] = value;
    });

    // Parse feature importance
    final featureImportanceMap = <String, List<FeatureImportanceData>>{};
    vitalsData.forEach((vitalName, vitalData) {
      if (vitalData is Map<String, dynamic> && vitalData['featureImportance'] != null) {
        final importanceList = (vitalData['featureImportance'] as List<dynamic>)
            .map((item) => FeatureImportanceData.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        featureImportanceMap[vitalName] = importanceList;
      }
    });

    return TrendAnalysisData(
      labReportType: data['labReportType'] ?? '',
      reportCount: data['reportCount'] ?? 0,
      timespan: TimeSpanData.fromMap(Map<String, dynamic>.from(data['timespan'] ?? {})),
      vitals: vitalsMap,
      predictions: predictionsMap,
      generatedAt: DateTime.parse(data['generatedAt'] ?? DateTime.now().toISOString()),
      modelType: data['modelType'] ?? 'linear',
      mlInsights: mlInsightsMap.isNotEmpty ? mlInsightsMap : null,
      featureImportance: featureImportanceMap.isNotEmpty ? featureImportanceMap : null,
    );
  }

  bool get isMLEnhanced => modelType == 'xgboost';
  
  bool get hasCrossPatientInsights => 
    mlInsights?.isNotEmpty ?? false;
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
    return '${date.month}/${date.year.toString().substring(2)}';
  }

  String get confidencePercentage {
    return '${(confidence * 100).round()}%';
  }
}

class FeatureImportanceData {
  final String featureName;
  final double importance;
  final String interpretation;

  FeatureImportanceData({
    required this.featureName,
    required this.importance,
    required this.interpretation,
  });

  factory FeatureImportanceData.fromMap(Map<String, dynamic> data) {
    return FeatureImportanceData(
      featureName: data['feature_name'] ?? '',
      importance: (data['importance'] ?? 0).toDouble(),
      interpretation: data['interpretation'] ?? '',
    );
  }

  String get formattedImportance => '${(importance * 100).toStringAsFixed(1)}%';
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
  final String modelType;
  final Map<String, dynamic>? mlInsights;
  final Map<String, List<FeatureImportanceData>>? featureImportance;

  TrendAnalysisData({
    required this.labReportType,
    required this.reportCount,
    required this.timespan,
    required this.vitals,
    required this.predictions,
    required this.generatedAt,
    required this.modelType,
    this.mlInsights,
    this.featureImportance,
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

    // Parse ML insights
    final mlInsightsMap = <String, dynamic>{};
    final mlInsightsData = data['mlInsights'] as Map<String, dynamic>? ?? {};
    mlInsightsData.forEach((key, value) {
      mlInsightsMap[key] = value;
    });

    // Parse feature importance
    final featureImportanceMap = <String, List<FeatureImportanceData>>{};
    vitalsData.forEach((vitalName, vitalData) {
      if (vitalData is Map<String, dynamic> && vitalData['featureImportance'] != null) {
        final importanceList = (vitalData['featureImportance'] as List<dynamic>)
            .map((item) => FeatureImportanceData.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        featureImportanceMap[vitalName] = importanceList;
      }
    });

    return TrendAnalysisData(
      labReportType: data['labReportType'] ?? '',
      reportCount: data['reportCount'] ?? 0,
      timespan: TimeSpanData.fromMap(Map<String, dynamic>.from(data['timespan'] ?? {})),
      vitals: vitalsMap,
      predictions: predictionsMap,
      generatedAt: DateTime.parse(data['generatedAt'] ?? DateTime.now().toISOString()),
      modelType: data['modelType'] ?? 'linear',
      mlInsights: mlInsightsMap.isNotEmpty ? mlInsightsMap : null,
      featureImportance: featureImportanceMap.isNotEmpty ? featureImportanceMap : null,
    );
  }

  bool get isMLEnhanced => modelType == 'xgboost';
  
  bool get hasCrossPatientInsights => 
    mlInsights?.isNotEmpty ?? false;
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
    return '${date.month}/${date.year.toString().substring(2)}';
  }

  String get confidencePercentage {
    return '${(confidence * 100).round()}%';
  }
}

class FeatureImportanceData {
  final String featureName;
  final double importance;
  final String interpretation;

  FeatureImportanceData({
    required this.featureName,
    required this.importance,
    required this.interpretation,
  });

  factory FeatureImportanceData.fromMap(Map<String, dynamic> data) {
    return FeatureImportanceData(
      featureName: data['feature_name'] ?? '',
      importance: (data['importance'] ?? 0).toDouble(),
      interpretation: data['interpretation'] ?? '',
    );
  }

  String get formattedImportance => '${(importance * 100).toStringAsFixed(1)}%';
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
  final String modelType;
  final Map<String, dynamic>? mlInsights;
  final Map<String, List<FeatureImportanceData>>? featureImportance;

  TrendAnalysisData({
    required this.labReportType,
    required this.reportCount,
    required this.timespan,
    required this.vitals,
    required this.predictions,
    required this.generatedAt,
    required this.modelType,
    this.mlInsights,
    this.featureImportance,
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

    // Parse ML insights
    final mlInsightsMap = <String, dynamic>{};
    final mlInsightsData = data['mlInsights'] as Map<String, dynamic>? ?? {};
    mlInsightsData.forEach((key, value) {
      mlInsightsMap[key] = value;
    });

    // Parse feature importance
    final featureImportanceMap = <String, List<FeatureImportanceData>>{};
       vitalsData.forEach((vitalName, vitalData) {
      if (vitalData is Map<String, dynamic> && vitalData['featureImportance'] != null) {
        final importanceList = (vitalData['featureImportance'] as List<dynamic>)
            .map((item) => FeatureImportanceData.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        featureImportanceMap[vitalName] = importanceList;
      }
    });

    return TrendAnalysisData(
      labReportType: data['labReportType'] ?? '',
      reportCount: data['reportCount'] ?? 0,
      timespan: TimeSpanData.fromMap(Map<String, dynamic>.from(data['timespan'] ?? {})),
      vitals: vitalsMap,
      predictions: predictionsMap,
      generatedAt: DateTime.parse(data['generatedAt'] ?? DateTime.now().toISOString()),
      modelType: data['modelType'] ?? 'linear',
      mlInsights: mlInsightsMap.isNotEmpty ? mlInsightsMap : null,
      featureImportance: featureImportanceMap.isNotEmpty ? featureImportanceMap : null,
    );
  }

  bool get isMLEnhanced => modelType == 'xgboost';
  
  bool get hasCrossPatientInsights => 
    mlInsights?.isNotEmpty ?? false;
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
    return '${date.month}/${date.year.toString().substring(2)}';
  }

  String get confidencePercentage {
    return '${(confidence * 100).round()}%';
  }
}

class FeatureImportanceData {
  final String featureName;
  final double importance;
  final String interpretation;

  FeatureImportanceData({
    required this.featureName,
    required this.importance,
    required this.interpretation,
  });

  factory FeatureImportanceData.fromMap(Map<String, dynamic> data) {
    return FeatureImportanceData(
      featureName: data['feature_name'] ?? '',
      importance: (data['importance'] ?? 0).toDouble(),
      interpretation: data['interpretation'] ?? '',
    );
  }

  String get formattedImportance => '${(importance * 100).toStringAsFixed(1)}%';
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
  final String modelType;
  final Map<String, dynamic>? mlInsights;
  final Map<String, List<FeatureImportanceData>>? featureImportance;

  TrendAnalysisData({
    required this.labReportType,
    required this.reportCount,
    required this.timespan,
    required this.vitals,
    required this.predictions,
    required this.generatedAt,
    required this.modelType,
    this.mlInsights,
    this.featureImportance,
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

    // Parse ML insights
    final mlInsightsMap = <String, dynamic>{};
    final mlInsightsData = data['mlInsights'] as Map<String, dynamic>? ?? {};
    mlInsightsData.forEach((key, value) {
      mlInsightsMap[key] = value;
    });

    // Parse feature importance
    final featureImportanceMap = <String, List<FeatureImportanceData>>{};
    vitalsData.forEach((vitalName, vitalData) {
      if (vitalData is Map<String, dynamic> && vitalData['featureImportance'] != null) {
        final importanceList = (vitalData['featureImportance'] as List<dynamic>)
            .map((item) => FeatureImportanceData.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        featureImportanceMap[vitalName] = importanceList;
      }
    });

    return TrendAnalysisData(
      labReportType: data['labReportType'] ?? '',
      reportCount: data['reportCount'] ?? 0,
      timespan: TimeSpanData.fromMap(Map<String, dynamic>.from(data['timespan'] ?? {})),
      vitals: vitalsMap,
      predictions: predictionsMap,
      generatedAt: DateTime.parse(data['generatedAt'] ?? DateTime.now().toISOString()),
      modelType: data['modelType'] ?? 'linear',
      mlInsights: mlInsightsMap.isNotEmpty ? mlInsightsMap : null,
      featureImportance: featureImportanceMap.isNotEmpty ? featureImportanceMap : null,
    );
  }

  bool get isMLEnhanced => modelType == 'xgboost';
  
  bool get hasCrossPatientInsights => 
    mlInsights?.isNotEmpty ?? false;
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
    return '${date.month}/${date.year.toString().substring(2)}';
  }

  String get confidencePercentage {
    return '${(confidence * 100).round()}%';
  }
}

class FeatureImportanceData {
  final String featureName;
  final double importance;
  final String interpretation;

  FeatureImportanceData({
    required this.featureName,
    required this.importance,
    required this.interpretation,
  });

  factory FeatureImportanceData.fromMap(Map<String, dynamic> data) {
    return FeatureImportanceData(
      featureName: data['feature_name'] ?? '',
      importance: (data['importance'] ?? 0).toDouble(),
      interpretation: data['interpretation'] ?? '',
    );
  }

  String get formattedImportance => '${(importance * 100).toStringAsFixed(1)}%';
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
  final String modelType;
  final Map<String, dynamic>? mlInsights;
  final Map<String, List<FeatureImportanceData>>? featureImportance;

  TrendAnalysisData({
    required this.labReportType,
    required this.reportCount,
    required this.timespan,
    required this.vitals,
    required this.predictions,
    required this.generatedAt,
    required this.modelType,
    this.mlInsights,
    this.featureImportance,
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

    // Parse ML insights
    final mlInsightsMap = <String, dynamic>{};
    final mlInsightsData = data['mlInsights'] as Map<String, dynamic>? ?? {};
    mlInsightsData.forEach((key, value) {
      mlInsightsMap[key] = value;
    });

    // Parse feature importance
    final featureImportanceMap = <String, List<FeatureImportanceData>>{};
    vitalsData.forEach((vitalName, vitalData) {
      if (vitalData is Map<String, dynamic> && vitalData['featureImportance'] != null) {
        final importanceList = (vitalData['featureImportance'] as List<dynamic>)
            .map((item) => FeatureImportanceData.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        featureImportanceMap[vitalName] = importanceList;
      }
    });

    return TrendAnalysisData(
      labReportType: data['labReportType'] ?? '',
      reportCount: data['reportCount'] ?? 0,
      timespan: TimeSpanData.fromMap(Map<String, dynamic>.from(data['timespan'] ?? {})),
      vitals: vitalsMap,
      predictions: predictionsMap,
      generatedAt: DateTime.parse(data['generatedAt'] ?? DateTime.now().toISOString()),
      modelType: data['modelType'] ?? 'linear',
      mlInsights: mlInsightsMap.isNotEmpty ? mlInsightsMap : null,
      featureImportance: featureImportanceMap.isNotEmpty ? featureImportanceMap : null,
    );
  }

  bool get isMLEnhanced => modelType == 'xgboost';
  
  bool get hasCrossPatientInsights => 
    mlInsights?.isNotEmpty ?? false;
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
    return '${date.month}/${date.year.toString().substring(2)}';
  }

  String get confidencePercentage {
    return '${(confidence * 100).round()}%';
  }
}

class FeatureImportanceData {
  final String featureName;
  final double importance;
  final String interpretation;

  FeatureImportanceData({
    required this.featureName,
    required this.importance,
    required this.interpretation,
  });

  factory FeatureImportanceData.fromMap(Map<String, dynamic> data) {
    return FeatureImportanceData(
      featureName: data['feature_name'] ?? '',
      importance: (data['importance'] ?? 0).toDouble(),
      interpretation: data['interpretation'] ?? '',
    );
  }

  String get formattedImportance => '${(importance * 100).toStringAsFixed(1)}%';
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
  final String modelType;
  final Map<String, dynamic>? mlInsights;
  final Map<String, List<FeatureImportanceData>>? featureImportance;

  TrendAnalysisData({
    required this.labReportType,
    required this.reportCount,
    required this.timespan,
    required this.vitals,
    required this.predictions,
    required this.generatedAt,
    required this.modelType,
    this.mlInsights,
    this.featureImportance,
  });

  factory TrendAnalysisData.fromFirestore(Map<String, dynamic> data) {
    final vitalsMap = <String, VitalTrendData>{};
    final vitalsData = data['vitals'] as Map<String, dynamic>? ?? {};
    
    vitalsData.forEach((key, value) {
      vitalsMap[key] = VitalTrendData.fromMap(Map<String, dynamic>.from(value));
    });

    final predictionsMap = <String, List<PredictionData>>{};
    final predictionsData = data['predictions'] as Map<String, dynamic>? ?? {};
    