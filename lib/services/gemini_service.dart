import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GeminiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Request analysis of medical documents for a user
  Future<String> analyzeMedicalRecords(String userId) async {
    try {
      // Check if we have a recent analysis already (cache for 24 hours)
      final analysisDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('ai_analysis')
          .doc('latest')
          .get();

      // If analysis exists and is recent, return it
      if (analysisDoc.exists) {
        final data = analysisDoc.data();
        final timestamp = data?['timestamp'] as Timestamp?;

        if (timestamp != null) {
          final analysisAge = DateTime.now().difference(timestamp.toDate());
          if (analysisAge.inHours < 24) {
            return data?['summary'] as String? ?? 'No summary available';
          }
        }
      }

      // Otherwise, call the Cloud Function to generate a new analysis
      final result = await _functions
          .httpsCallable('analyzeMedicalRecords')
          .call({'userId': userId});

      return result.data['summary'] ?? 'No summary available';
    } catch (e) {
      print('Error analyzing medical records: $e');
      // Provide more specific error messages based on the error type
      if (e.toString().contains('unauthenticated')) {
        return 'Please log in to analyze your medical records.';
      } else if (e.toString().contains('failed-precondition')) {
        return 'Medical analysis service is currently unavailable.';
      }
      return 'Error generating medical summary. Please try again later.';
    }
  }

  /// Get cached medical analysis without triggering new analysis
  Future<String?> getCachedAnalysis(String userId) async {
    try {
      final result = await _functions.httpsCallable('getMedicalAnalysis').call({
        'userId': userId,
      });

      return result.data['summary'];
    } catch (e) {
      print('Error getting cached analysis: $e');
      return null;
    }
  }

  /// Check if analysis is available and recent
  Future<bool> hasRecentAnalysis(String userId) async {
    try {
      final analysisDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('ai_analysis')
          .doc('latest')
          .get();

      if (!analysisDoc.exists) return false;

      final data = analysisDoc.data();
      final timestamp = data?['timestamp'] as Timestamp?;

      if (timestamp != null) {
        final analysisAge = DateTime.now().difference(timestamp.toDate());
        return analysisAge.inHours < 24;
      }

      return false;
    } catch (e) {
      print('Error checking analysis status: $e');
      return false;
    }
  }

  /// Force refresh analysis (bypass cache)
  Future<String> refreshAnalysis(String userId) async {
    try {
      // Call the Cloud Function directly without checking cache
      final result = await _functions
          .httpsCallable('analyzeMedicalRecords')
          .call({'userId': userId});

      return result.data['summary'] ?? 'No summary available';
    } catch (e) {
      print('Error refreshing medical analysis: $e');
      if (e.toString().contains('unauthenticated')) {
        return 'Please log in to analyze your medical records.';
      } else if (e.toString().contains('failed-precondition')) {
        return 'Medical analysis service is currently unavailable.';
      }
      return 'Error generating medical summary. Please try again later.';
    }
  }

  /// Store the analysis result in Firestore for future reference
  /// Note: This method is now handled by the Cloud Function automatically
  @deprecated
  Future<void> storeAnalysisResult(String userId, String summary) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('ai_analysis')
        .doc('latest')
        .set({'summary': summary, 'timestamp': FieldValue.serverTimestamp()});
  }
}
