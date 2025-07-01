import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/gemini_service.dart';

class MedicalSummaryScreen extends StatefulWidget {
  final String userId;

  const MedicalSummaryScreen({super.key, required this.userId});

  @override
  State<MedicalSummaryScreen> createState() => _MedicalSummaryScreenState();
}

class _MedicalSummaryScreenState extends State<MedicalSummaryScreen> {
  final GeminiService _geminiService = GeminiService();
  bool _isLoading = true;
  String _summary = '';
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _loadSummary();
  }

  void _setupAuthListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user == null) {
        // User signed out, navigate back or show error
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);

    try {
      // Double-check authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _summary = 'Authentication error: User not logged in';
          _isLoading = false;
        });
        return;
      }

      print('🔍 Current user: ${user.uid}');
      print('🔍 Widget userId: ${widget.userId}');
      print('🔍 User email: ${user.email}');

      // First, test the debug function to ensure connectivity
      try {
        print('🔧 Testing debug function...');
        final debugResult = await _geminiService.debugCloudFunction();
        print('✅ Debug function result: $debugResult');
      } catch (debugError) {
        print('❌ Debug function failed: $debugError');
        setState(() {
          _summary = 'Debug test failed: $debugError';
          _isLoading = false;
        });
        return;
      }

      // If debug passes, try to get existing analysis first
      final analysisData = await _geminiService.getMedicalAnalysis();
      
      if (analysisData['hasAnalysis'] && analysisData['summary'] != null) {
        // We have existing analysis, check if new documents are available
        if (analysisData['newDocumentsAvailable']) {
          // There are new documents - show the cached summary but indicate update is available
          setState(() {
            _summary = '${analysisData['summary']}\n\n' +
                      '⚠️ New documents available for analysis (${analysisData['newDocumentsCount']} new). ' +
                      'Tap refresh to update your summary.';
            _isLoading = false;
          });
        } else {
          // Analysis is up to date
          setState(() {
            _summary = analysisData['summary'];
            _isLoading = false;
          });
        }
      } else {
        // No existing analysis, check if we have documents to analyze
        final statusData = await _geminiService.checkAnalysisStatus();
        
        if (statusData['needsAnalysis']) {
          // We have documents but no analysis - offer to generate one
          setState(() {
            _summary = 'You have ${statusData['totalDocuments']} medical document(s) ready for analysis.\n\n' +
                      'Tap the refresh button to generate your AI-powered medical summary.';
            _isLoading = false;
          });
        } else {
          // No documents available
          setState(() {
            _summary = 'No medical documents found. Please upload some medical records first to generate an AI summary.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error in _loadSummary: $e');
      setState(() {
        _summary = 'Error loading summary: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshAnalysis() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _summary = 'Authentication error: User not logged in';
          _isLoading = false;
        });
        return;
      }

      print('🔄 Requesting new analysis...');
      
      // Show a snackbar to indicate analysis is starting
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analyzing documents... This may take a moment.'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Request new analysis (will only analyze new documents and combine with existing)
      final result = await _geminiService.analyzeMedicalRecords();
      
      setState(() {
        _summary = result['summary'];
        _isLoading = false;
      });

      // Show result information
      if (mounted) {
        final message = result['analysisType'] == 'incremental_update' 
          ? 'Analysis updated with ${result['newDocumentsAnalyzed']} new document(s)'
          : result['analysisType'] == 'initial_analysis'
            ? 'Initial analysis completed for ${result['documentsAnalyzed']} document(s)'
            : 'Analysis completed';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _refreshAnalysis: $e');
      setState(() {
        _summary = 'Error generating analysis: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _forceReanalysis() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _summary = 'Authentication error: User not logged in';
          _isLoading = false;
        });
        return;
      }

      print('🔄 Requesting complete re-analysis...');
      
      // Show a snackbar to indicate analysis is starting
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Re-analyzing all documents... This may take longer.'),
            duration: Duration(seconds: 4),
          ),
        );
      }

      // Request complete re-analysis of all documents
      final result = await _geminiService.analyzeMedicalRecords(forceReanalysis: true);
      
      setState(() {
        _summary = result['summary'];
        _isLoading = false;
      });

      // Show result information
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complete re-analysis completed for ${result['documentsAnalyzed']} document(s)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _forceReanalysis: $e');
      setState(() {
        _summary = 'Error generating analysis: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAnalysis,
            tooltip: 'Generate/Update summary',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reload') {
                _loadSummary();
              } else if (value == 'force_reanalysis') {
                _forceReanalysis();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reload',
                child: Text('Reload Summary'),
              ),
              const PopupMenuItem(
                value: 'force_reanalysis',
                child: Text('Force Complete Re-analysis'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Medical History Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Generated by AI based on your medical records',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Divider(height: 32),
                  Text(_summary),
                ],
              ),
            ),
    );
  }
}
