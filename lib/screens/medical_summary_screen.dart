import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/gemini_service.dart';

class MedicalSummaryScreen extends StatefulWidget {
  final String userId;
  final bool autoTriggerAnalysis;

  const MedicalSummaryScreen({
    super.key,
    required this.userId,
    this.autoTriggerAnalysis = false,
  });

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
    if (widget.autoTriggerAnalysis) {
      _autoTriggerAnalysis();
    } else {
      _loadSummary();
    }
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

      // Check analysis status first
      final statusData = await _geminiService.checkAnalysisStatus();

      if (!statusData['hasAnalysis']) {
        // No existing analysis
        if (statusData['needsAnalysis']) {
          // We have documents but no analysis - show generate button
          setState(() {
            _summary =
                '📄 You have ${statusData['totalDocuments']} medical document(s) ready for AI analysis.\n\n'
                '🤖 Click "Generate Analysis" below to create your comprehensive medical summary using AI-powered text extraction and analysis.\n\n'
                '⏱️ This may take a moment as we analyze the content of your medical images.';
            _isLoading = false;
          });
        } else {
          // No documents available
          setState(() {
            _summary =
                '📋 No medical documents found.\n\n'
                'Please upload some medical records (lab reports, prescriptions, discharge summaries, etc.) first to generate an AI-powered medical summary.\n\n'
                '💡 Tip: Upload clear images of your medical documents for best results.';
            _isLoading = false;
          });
        }
      } else {
        // We have existing analysis - get it and check for updates
        final analysisData = await _geminiService.getMedicalAnalysis();

        if (analysisData['newDocumentsAvailable']) {
          // There are new documents - show the cached summary but indicate update is available
          setState(() {
            _summary =
                '${analysisData['summary']}\n\n'
                '🆕 NEW: ${analysisData['newDocumentsCount']} new document(s) available for analysis.\n\n'
                '👆 Click "Update Analysis" above to analyze the new documents and update your summary.';
            _isLoading = false;
          });
        } else {
          // Analysis is up to date
          setState(() {
            _summary =
                '${analysisData['summary']}\n\n'
                '✅ Your analysis is up to date (includes ${analysisData['analyzedDocuments']} document(s)).';
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
            content: Text(
              'Re-analyzing all documents... This may take longer.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }

      // Request complete re-analysis of all documents
      final result = await _geminiService.analyzeMedicalRecords(
        forceReanalysis: true,
      );

      setState(() {
        _summary = result['summary'];
        _isLoading = false;
      });

      // Show result information
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Complete re-analysis completed for ${result['documentsAnalyzed']} document(s)',
            ),
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

  Future<void> _autoTriggerAnalysis() async {
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

      print('🚀 Auto-triggering analysis...');

      // Check status first
      final statusData = await _geminiService.checkAnalysisStatus();

      if (statusData['needsAnalysis']) {
        // Show analysis is starting
        setState(() {
          _summary =
              '🔄 Analyzing your medical documents...\n\n'
              'This may take a moment as we process ${statusData['totalDocuments']} document(s) using AI-powered analysis.\n\n'
              'Please wait...';
        });

        // Trigger analysis
        final result = await _geminiService.analyzeMedicalRecords();

        setState(() {
          _summary = result['summary'];
          _isLoading = false;
        });

        // Show success message
        if (mounted) {
          final message = result['analysisType'] == 'incremental_update'
              ? 'Analysis updated with ${result['newDocumentsAnalyzed']} new document(s)'
              : result['analysisType'] == 'initial_analysis'
              ? 'Analysis completed for ${result['documentsAnalyzed']} document(s)'
              : 'Analysis completed';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // No new documents - just load existing summary
        _loadSummary();
      }
    } catch (e) {
      print('❌ Error in _autoTriggerAnalysis: $e');
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
            icon: const Icon(Icons.auto_awesome),
            onPressed: _refreshAnalysis,
            tooltip: 'Generate/Update AI Analysis',
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
                child: Text('Reload Status'),
              ),
              const PopupMenuItem(
                value: 'force_reanalysis',
                child: Text('Re-analyze All Documents'),
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
                    'AI Medical Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'AI-powered analysis of your medical records using advanced OCR and text understanding',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Divider(height: 32),

                  // Show Generate Analysis button if no analysis exists and documents are available
                  if (_summary.contains('ready for AI analysis') ||
                      _summary.contains('new document(s) available')) ...[
                    Center(
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _refreshAnalysis,
                            icon: const Icon(Icons.auto_awesome),
                            label: Text(
                              _summary.contains('new document(s) available')
                                  ? 'Update Analysis'
                                  : 'Generate AI Analysis',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],

                  Text(_summary),
                ],
              ),
            ),
    );
  }
}
