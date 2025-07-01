import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GeminiService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Check analysis status to see if new documents are available for analysis
  Future<Map<String, dynamic>> checkAnalysisStatus({
    String analysisType =
        'all_documents', // 'all_documents' or 'lab_reports_only'
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print(
        '🔍 Checking analysis status for user: ${currentUser.uid} (type: $analysisType)',
      );

      // Get the analysis data first
      final analysisData = await getMedicalAnalysis(analysisType: analysisType);

      if (!analysisData['hasAnalysis']) {
        // No analysis exists - need to analyze
        return {
          'hasAnalysis': false,
          'totalDocuments': 0,
          'needsAnalysis': true,
          'statusMessage':
              'No analysis found. Click to generate your first AI summary.',
          'newDocumentsCount': 0,
          'lastUpdated': null,
        };
      }

      // For now, we'll rely on the backend functions to determine if new documents are available
      // This could be enhanced with more sophisticated client-side checking
      return {
        'hasAnalysis': true,
        'totalDocuments': analysisData['totalDocuments'],
        'needsAnalysis': false,
        'statusMessage': 'Analysis up to date',
        'newDocumentsCount': 0,
        'lastUpdated': analysisData['timestamp'],
      };
    } catch (e) {
      print('❌ Error checking analysis status: $e');
      return {
        'hasAnalysis': false,
        'totalDocuments': 0,
        'needsAnalysis': false,
        'statusMessage': 'Error checking status',
        'newDocumentsCount': 0,
        'lastUpdated': null,
      };
    }
  }

  /// Get cached medical analysis with full status information
  Future<Map<String, dynamic>> getMedicalAnalysis({
    String analysisType =
        'all_documents', // 'all_documents' or 'lab_reports_only'
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print(
        '📄 Getting medical analysis for user: ${currentUser.uid} (type: $analysisType)',
      );

      // Get analysis from the appropriate collection
      String collectionPath;
      if (analysisType == 'lab_reports_only') {
        collectionPath = 'lab_reports';
      } else {
        collectionPath = 'comprehensive';
      }

      final analysisDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('ai_analysis')
          .doc(collectionPath)
          .get();

      if (!analysisDoc.exists) {
        return {
          'summary': null,
          'hasAnalysis': false,
          'totalDocuments': 0,
          'analyzedDocuments': 0,
          'newDocumentsAvailable': false,
          'newDocumentsCount': 0,
          'analysisUpToDate': false,
          'timestamp': null,
          'lastAnalysisType': 'none',
        };
      }

      final data = analysisDoc.data()!;
      return {
        'summary': data['summary'],
        'hasAnalysis': true,
        'totalDocuments': data['documentCount'] ?? 0,
        'analyzedDocuments': (data['analyzedDocuments'] as List?)?.length ?? 0,
        'newDocumentsAvailable':
            false, // Will be calculated by checkAnalysisStatus
        'newDocumentsCount': 0,
        'analysisUpToDate': true,
        'timestamp': data['timestamp'],
        'lastAnalysisType': data['analysisType'] ?? analysisType,
      };
    } catch (e) {
      print('❌ Error getting medical analysis: $e');
      return {
        'summary': null,
        'hasAnalysis': false,
        'totalDocuments': 0,
        'analyzedDocuments': 0,
        'newDocumentsAvailable': false,
        'newDocumentsCount': 0,
        'analysisUpToDate': false,
        'timestamp': null,
        'lastAnalysisType': 'error',
      };
    }
  }

  /// Request new analysis - only analyzes new documents and combines with existing summaries
  Future<Map<String, dynamic>> analyzeMedicalRecords({
    bool forceReanalysis = false,
    String analysisType =
        'all_documents', // 'all_documents' or 'lab_reports_only'
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print(
        '🔄 ${forceReanalysis ? "Force re-analyzing" : "Analyzing new"} medical records for user: ${currentUser.uid} (type: $analysisType)',
      );

      // Wait a moment to ensure authentication is fully processed
      await Future.delayed(const Duration(milliseconds: 500));

      // Call the appropriate function based on analysis type
      String functionName;
      if (analysisType == 'lab_reports_only') {
        functionName = 'analyzeLabReports';
      } else {
        functionName = 'analyzeAllMedicalRecords';
      }

      final result = await _functions.httpsCallable(functionName).call({
        'forceReanalysis': forceReanalysis,
      });

      return {
        'summary': result.data['summary'] ?? 'No summary available',
        'documentsAnalyzed': result.data['documentsAnalyzed'] ?? 0,
        'newDocumentsAnalyzed': result.data['newDocumentsAnalyzed'] ?? 0,
        'lastUpdated': result.data['lastUpdated'],
        'isCached': result.data['isCached'] ?? false,
        'analysisType': result.data['analysisType'] ?? 'unknown',
      };
    } catch (e) {
      print('❌ Error analyzing medical records: $e');

      // Provide more specific error messages based on the error type
      String errorMessage;
      if (e.toString().contains('unauthenticated')) {
        errorMessage = 'Please log in to analyze your medical records.';
      } else if (e.toString().contains('failed-precondition')) {
        errorMessage = 'Medical analysis service is currently unavailable.';
      } else {
        errorMessage =
            'Error generating medical summary. Please try again later.';
      }

      return {
        'summary': errorMessage,
        'documentsAnalyzed': 0,
        'newDocumentsAnalyzed': 0,
        'lastUpdated': null,
        'isCached': false,
        'analysisType': 'error',
      };
    }
  }

  /// Legacy method for backward compatibility - now uses the new system
  Future<String> analyzeMedicalRecordsLegacy(String userId) async {
    final result = await analyzeMedicalRecords();
    return result['summary'] as String;
  }

  /// Get cached medical analysis without triggering new analysis
  @deprecated
  Future<String?> getCachedAnalysis(String userId) async {
    final result = await getMedicalAnalysis();
    return result['summary'] as String?;
  }

  /// Check if analysis is available and recent
  @deprecated
  Future<bool> hasRecentAnalysis(String userId) async {
    final result = await getMedicalAnalysis();
    return result['analysisUpToDate'] as bool;
  }

  /// Force refresh analysis (bypass cache) - now does full reanalysis
  @deprecated
  Future<String> refreshAnalysis(String userId) async {
    final result = await analyzeMedicalRecords(forceReanalysis: true);
    return result['summary'] as String;
  }

  /// Store the analysis result in Firestore for future reference
  /// Note: This method is now handled by the Cloud Function automatically
  @deprecated
  Future<void> storeAnalysisResult(String userId, String summary) async {
    // This is now handled automatically by the Firebase Function
    print(
      '⚠️ storeAnalysisResult is deprecated - handled automatically by Firebase Function',
    );
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
