# Frontend Services - Trend Analysis Service Layer

## Overview

This document covers the Flutter service layer for accessing trend analysis data from Firebase. This service handles all communication between the app and the backend trend analysis system.

## Implementation

### Create Trend Analysis Service

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

  /// Manually trigger trend analysis (for testing or user request)
  static Future<bool> triggerManualAnalysis(String labReportType) async {
    try {
      final callable = _functions.httpsCallable('triggerTrendAnalysisManual');
      final result = await callable.call({
        'labReportType': labReportType,
      });

      return result.data['success'] ?? false;
    } catch (e) {
      throw Exception('Failed to trigger manual analysis: $e');
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

  /// Get report count for a specific lab type
  static Future<int> getReportCount(String labReportType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final countSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('lab_report_content')
          .where('labReportType', '==', labReportType)
          .get();

      return countSnapshot.size;
    } catch (e) {
      return 0;
    }
  }

  /// Get available lab report types with their counts
  static Future<Map<String, int>> getLabReportTypeCounts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final reportsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('lab_report_content')
          .get();

      final typeCounts = <String, int>{};
      
      for (final doc in reportsSnapshot.docs) {
        final data = doc.data();
        final labType = data['labReportType'] as String?;
        
        if (labType != null && labType != 'other_lab_tests') {
          typeCounts[labType] = (typeCounts[labType] ?? 0) + 1;
        }
      }

      return typeCounts;
    } catch (e) {
      throw Exception('Failed to get lab report type counts: $e');
    }
  }

  /// Get trend notifications for user
  static Future<List<TrendNotification>> getTrendNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final notificationsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('type', '==', 'trend_analysis')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return notificationsSnapshot.docs
          .map((doc) => TrendNotification.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get trend notifications: $e');
    }
  }

  /// Mark trend notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Stream trend analysis updates
  static Stream<TrendAnalysisData?> streamTrendAnalysis(String labReportType) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('latest_trends')
        .doc(labReportType)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return TrendAnalysisData.fromFirestore(doc.data()!);
      }
      return null;
    });
  }

  /// Stream all trend analyses
  static Stream<List<TrendAnalysisData>> streamAllTrendAnalyses() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('latest_trends')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TrendAnalysisData.fromFirestore(doc.data()))
          .toList();
    });
  }

  /// Retry failed trend analysis
  static Future<bool> retryTrendAnalysis(String labReportType, {bool forceUpdate = false}) async {
    try {
      final callable = _functions.httpsCallable('retryTrendAnalysis');
      final result = await callable.call({
        'labReportType': labReportType,
        'forceUpdate': forceUpdate,
      });

      return result.data['success'] ?? false;
    } catch (e) {
      throw Exception('Failed to retry trend analysis: $e');
    }
  }

  /// Batch process all available trends
  static Future<BatchProcessResult> batchProcessTrends() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final callable = _functions.httpsCallable('batchProcessTrends');
      final result = await callable.call({
        'userId': user.uid,
        'isAdmin': false,
      });

      return BatchProcessResult.fromMap(result.data);
    } catch (e) {
      throw Exception('Failed to batch process trends: $e');
    }
  }
}

/// Result class for batch processing
class BatchProcessResult {
  final bool success;
  final int processedTypes;
  final List<BatchProcessItem> results;

  BatchProcessResult({
    required this.success,
    required this.processedTypes,
    required this.results,
  });

  factory BatchProcessResult.fromMap(Map<String, dynamic> data) {
    final resultsList = (data['results'] as List<dynamic>? ?? [])
        .map((item) => BatchProcessItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    return BatchProcessResult(
      success: data['success'] ?? false,
      processedTypes: data['processedTypes'] ?? 0,
      results: resultsList,
    );
  }
}

class BatchProcessItem {
  final String labReportType;
  final bool success;
  final int? reportCount;
  final int? vitalsAnalyzed;
  final String? error;

  BatchProcessItem({
    required this.labReportType,
    required this.success,
    this.reportCount,
    this.vitalsAnalyzed,
    this.error,
  });

  factory BatchProcessItem.fromMap(Map<String, dynamic> data) {
    return BatchProcessItem(
      labReportType: data['labReportType'] ?? '',
      success: data['success'] ?? false,
      reportCount: data['reportCount'],
      vitalsAnalyzed: data['vitalsAnalyzed'],
      error: data['error'],
    );
  }
}

/// Trend notification class
class TrendNotification {
  final String id;
  final String title;
  final String message;
  final String labReportType;
  final int vitalsAnalyzed;
  final bool hasAnomalies;
  final DateTime createdAt;
  final bool read;

  TrendNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.labReportType,
    required this.vitalsAnalyzed,
    required this.hasAnomalies,
    required this.createdAt,
    required this.read,
  });

  factory TrendNotification.fromFirestore(String id, Map<String, dynamic> data) {
    return TrendNotification(
      id: id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      labReportType: data['labReportType'] ?? '',
      vitalsAnalyzed: data['vitalsAnalyzed'] ?? 0,
      hasAnomalies: data['hasAnomalies'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      read: data['read'] ?? false,
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
```

## Usage Examples

### Get Trend Analysis

```dart
// Get specific trend
final bloodSugarTrend = await TrendAnalysisService.getTrendAnalysis('Blood Sugar');
if (bloodSugarTrend != null) {
  print('Found ${bloodSugarTrend.vitals.length} vital parameters');
}

// Get all trends
final allTrends = await TrendAnalysisService.getAllTrendAnalyses();
print('Total trend analyses: ${allTrends.length}');
```

### Check Availability

```dart
// Check if trend analysis is available
final isAvailable = await TrendAnalysisService.isTrendAnalysisAvailable('Cholesterol Panel');
if (isAvailable) {
  // Show trend analysis option
} else {
  final count = await TrendAnalysisService.getReportCount('Cholesterol Panel');
  print('Need ${5 - count} more reports for trend analysis');
}
```

### Stream Updates

```dart
// Listen to trend updates
StreamBuilder<TrendAnalysisData?>(
  stream: TrendAnalysisService.streamTrendAnalysis('Blood Sugar'),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data != null) {
      return TrendChart(trendData: snapshot.data!);
    }
    return Text('No trend data available');
  },
);
```

### Trigger Analysis

```dart
// Manual trigger
try {
  final success = await TrendAnalysisService.triggerManualAnalysis('Blood Sugar');
  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Trend analysis triggered successfully')),
    );
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to trigger analysis: $e')),
  );
}
```

### Batch Processing

```dart
// Process all available trends
try {
  final result = await TrendAnalysisService.batchProcessTrends();
  print('Processed ${result.processedTypes} lab report types');
  
  for (final item in result.results) {
    if (item.success) {
      print('✅ ${item.labReportType}: ${item.vitalsAnalyzed} vitals analyzed');
    } else {
      print('❌ ${item.labReportType}: ${item.error}');
    }
  }
} catch (e) {
  print('Batch processing failed: $e');
}
```

## Error Handling

The service includes comprehensive error handling:

- **Network errors**: Timeout and connectivity issues
- **Authentication errors**: User not logged in
- **Permission errors**: Insufficient access rights
- **Data errors**: Invalid or missing data
- **Function errors**: Backend processing failures

## Testing

Test the service layer:

1. **Unit tests** for data parsing and validation
2. **Integration tests** with Firebase
3. **Error scenario tests** for network failures
4. **Performance tests** for large datasets

## Next Steps

Continue to **06_FRONTEND_DATA_MODELS.md** to implement the data model classes used by this service.
