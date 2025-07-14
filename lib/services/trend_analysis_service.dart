import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trend_data_models.dart';

class TrendAnalysisService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Cache for trend data
  static final Map<String, TrendAnalysisData> _cache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static const Duration _cacheExpiry = Duration(minutes: 30);

  /// Get trend analysis for a specific lab report type with caching
  static Future<TrendAnalysisData?> getTrendAnalysis(
    String labReportType,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final cacheKey = '${user.uid}_$labReportType';

      // Check cache first
      if (_cache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamp[cacheKey];
        if (timestamp != null &&
            DateTime.now().difference(timestamp) < _cacheExpiry) {
          return _cache[cacheKey];
        }
      }

      // Fetch from server
      final data = await _fetchTrendAnalysis(labReportType);
      if (data != null) {
        _cache[cacheKey] = data;
        _cacheTimestamp[cacheKey] = DateTime.now();
      }

      return data;
    } catch (e) {
      throw Exception('Failed to get trend analysis: $e');
    }
  }

  /// Internal method to fetch trend analysis from Firestore
  static Future<TrendAnalysisData?> _fetchTrendAnalysis(
    String labReportType,
  ) async {
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
      final result = await callable.call({'labReportType': labReportType});

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
          .where('labReportType', isEqualTo: labReportType)
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
          .where('labReportType', isEqualTo: labReportType)
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
          .where('type', isEqualTo: 'trend_analysis')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return notificationsSnapshot.docs
          .map((doc) => TrendNotification.fromFirestore(doc.data()))
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
  static Future<bool> retryTrendAnalysis(
    String labReportType, {
    bool forceUpdate = false,
  }) async {
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

  /// Get historical trend analysis data
  static Future<List<TrendAnalysisData>> getHistoricalTrends(
    String labReportType, {
    int limit = 10,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final trendsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('trend_analysis')
          .where('labReportType', isEqualTo: labReportType)
          .orderBy('generatedAt', descending: true)
          .limit(limit)
          .get();

      return trendsSnapshot.docs
          .map((doc) => TrendAnalysisData.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get historical trends: $e');
    }
  }

  /// Get summary of all trend analyses
  static Future<TrendSummary> getTrendSummary() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return TrendSummary(
          totalTrends: 0,
          trendTypes: [],
          hasAnomalies: false,
          lastUpdated: null,
        );
      }

      final trendsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('latest_trends')
          .get();

      final trends = trendsSnapshot.docs
          .map((doc) => TrendAnalysisData.fromFirestore(doc.data()))
          .toList();

      final trendTypes = trends.map((t) => t.labReportType).toList();
      final hasAnomalies = trends.any((t) => t.hasAnomalies);
      final lastUpdated = trends.isNotEmpty
          ? trends
                .map((t) => t.generatedAt)
                .reduce((a, b) => a.isAfter(b) ? a : b)
          : null;

      return TrendSummary(
        totalTrends: trends.length,
        trendTypes: trendTypes,
        hasAnomalies: hasAnomalies,
        lastUpdated: lastUpdated,
      );
    } catch (e) {
      throw Exception('Failed to get trend summary: $e');
    }
  }

  /// Delete trend analysis for a specific lab type
  static Future<bool> deleteTrendAnalysis(String labReportType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final batch = _firestore.batch();

      // Delete from latest_trends
      final latestTrendRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('latest_trends')
          .doc(labReportType);
      batch.delete(latestTrendRef);

      // Delete from trend_analysis (all historical records)
      final trendsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('trend_analysis')
          .where('labReportType', isEqualTo: labReportType)
          .get();

      for (final doc in trendsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return true;
    } catch (e) {
      throw Exception('Failed to delete trend analysis: $e');
    }
  }

  /// Clear cache for a specific user
  static void clearCache() {
    _cache.clear();
    _cacheTimestamp.clear();
  }

  /// Get lab report types that are eligible for trend analysis
  static Future<List<String>> getEligibleLabTypes() async {
    try {
      final typeCounts = await getLabReportTypeCounts();
      return typeCounts.entries
          .where((entry) => entry.value >= 5)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      throw Exception('Failed to get eligible lab types: $e');
    }
  }

  /// Check if any new trends are available since last check
  static Future<bool> hasNewTrends({DateTime? since}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      Query query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('latest_trends');

      if (since != null) {
        query = query.where(
          'lastUpdated',
          isGreaterThan: Timestamp.fromDate(since),
        );
      }

      final snapshot = await query.get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
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
        .map(
          (item) => BatchProcessItem.fromMap(Map<String, dynamic>.from(item)),
        )
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
  final String type;
  final bool read;
  final DateTime createdAt;

  TrendNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.createdAt,
  });

  factory TrendNotification.fromFirestore(Map<String, dynamic> data) {
    return TrendNotification(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'info',
      read: data['read'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Trend summary class
class TrendSummary {
  final int totalTrends;
  final List<String> trendTypes;
  final bool hasAnomalies;
  final DateTime? lastUpdated;

  TrendSummary({
    required this.totalTrends,
    required this.trendTypes,
    required this.hasAnomalies,
    this.lastUpdated,
  });

  String get formattedLastUpdated {
    if (lastUpdated == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastUpdated!);

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
