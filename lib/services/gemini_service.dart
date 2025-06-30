import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GeminiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Try different regions - check which one your functions are deployed to
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  // If that doesn't work, try: 'us-east1', 'europe-west1', 'asia-northeast1'

  /// Request analysis of medical documents for a user
  Future<String> analyzeMedicalRecords(String userId) async {
    try {
      // Verify user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print('🔐 Authenticated user: ${currentUser.uid}');
      print('🔐 User email: ${currentUser.email}');

      // Check if the user's token is valid
      try {
        final idToken = await currentUser.getIdToken(true); // Force refresh
        print('🔐 Token obtained: ${idToken != null && idToken.isNotEmpty}');
      } catch (tokenError) {
        print('❌ Token error: $tokenError');
        throw Exception('Authentication token error: $tokenError');
      }

      // Check cache first using the authenticated user's ID
      final analysisDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
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
            print('✅ Using cached analysis');
            return data?['summary'] as String? ?? 'No summary available';
          }
        }
      }

      print('🔄 Generating new analysis...');

      // Wait a moment to ensure authentication is fully processed
      await Future.delayed(const Duration(milliseconds: 500));

      // Retry logic for network issues
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          // Call the Cloud Function without userId parameter
          // The function will use context.auth.uid
          final result = await _functions
              .httpsCallable('analyzeMedicalRecords')
              .call({}); // Empty data object

          return result.data['summary'] ?? 'No summary available';
        } catch (e) {
          retryCount++;
          print('❌ Attempt $retryCount failed: $e');

          if (retryCount >= maxRetries) {
            rethrow; // Throw the error after all retries
          }

          // Wait before retrying
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }

      return 'Error generating medical summary. Please try again later.';
    } catch (e) {
      print('❌ Error analyzing medical records: $e');
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
      final result = await _functions
          .httpsCallable('getMedicalAnalysis')
          .call({});
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
          .call({}); // Empty data object

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

  /// Debug function to test Cloud Functions connectivity and authentication
  Future<Map<String, dynamic>> debugCloudFunction() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print('🔧 Testing debug function...');

      final result = await _functions.httpsCallable('debugFunction').call({});

      print('✅ Debug function result: ${result.data}');
      return result.data;
    } catch (e) {
      print('❌ Debug function error: $e');
      rethrow;
    }
  }
}
