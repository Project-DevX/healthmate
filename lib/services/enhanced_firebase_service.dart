// lib/services/enhanced_firebase_service.dart
import 'package:cloud_functions/cloud_functions.dart';

class EnhancedFirebaseService {
  static final _functions = FirebaseFunctions.instance;

  // Health Check
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final result = await _functions.httpsCallable('healthCheck').call();
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Health check failed: $e');
    }
  }

  // User Analytics
  static Future<Map<String, dynamic>> getUserAnalytics() async {
    try {
      final result = await _functions.httpsCallable('getUserAnalytics').call();
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to get analytics: $e');
    }
  }

  // Advanced Document Search
  static Future<Map<String, dynamic>> searchDocuments({
    String query = "",
    String? category,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final result = await _functions.httpsCallable('searchDocuments').call({
        'query': query,
        'category': category,
        'dateFrom': dateFrom?.toIso8601String(),
        'dateTo': dateTo?.toIso8601String(),
        'limit': limit,
        'offset': offset,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }

  // Health Timeline
  static Future<Map<String, dynamic>> generateHealthTimeline({
    String timeRange = "1year",
  }) async {
    try {
      final result = await _functions
          .httpsCallable('generateHealthTimeline')
          .call({'timeRange': timeRange});
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to generate timeline: $e');
    }
  }

  // Health Recommendations
  static Future<Map<String, dynamic>> getHealthRecommendations() async {
    try {
      final result = await _functions
          .httpsCallable('getHealthRecommendations')
          .call();
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to get recommendations: $e');
    }
  }

  // Batch Process Documents
  static Future<Map<String, dynamic>> batchProcessDocuments({
    required List<String> documentIds,
    required String operation,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('batchProcessDocuments')
          .call({'documentIds': documentIds, 'operation': operation});
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Batch processing failed: $e');
    }
  }

  // Create Secure Share
  static Future<Map<String, dynamic>> createSecureShare({
    required List<String> documentIds,
    int expiresInHours = 24,
    String? accessCode,
    String? recipientEmail,
  }) async {
    try {
      final result = await _functions.httpsCallable('createSecureShare').call({
        'documentIds': documentIds,
        'expiresInHours': expiresInHours,
        'accessCode': accessCode,
        'recipientEmail': recipientEmail,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to create share: $e');
    }
  }

  // Export User Data
  static Future<Map<String, dynamic>> exportUserData({
    String format = "json",
  }) async {
    try {
      final result = await _functions.httpsCallable('exportUserData').call({
        'format': format,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Data export failed: $e');
    }
  }

  // Create Document Version
  static Future<Map<String, dynamic>> createDocumentVersion({
    required String documentId,
    String? versionNote,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('createDocumentVersion')
          .call({'documentId': documentId, 'versionNote': versionNote});
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to create version: $e');
    }
  }
}
