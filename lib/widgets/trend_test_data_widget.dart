import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/test_data_service.dart';

/// Test Data Generation Widget
///
/// Add this widget to your dashboard or any screen to easily generate test data
/// for trend analysis. This will create realistic lab report data with trends.
class TrendTestDataWidget extends StatefulWidget {
  const TrendTestDataWidget({Key? key}) : super(key: key);

  @override
  State<TrendTestDataWidget> createState() => _TrendTestDataWidgetState();
}

class _TrendTestDataWidgetState extends State<TrendTestDataWidget> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Test Data Generator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Generate realistic lab report data to test trend analysis features. This will create:',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            _buildFeatureList(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateFullTestData,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_graph),
                    label: Text(
                      _isGenerating ? 'Generating...' : 'Generate Full Data',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _generateQuickData,
                    icon: const Icon(Icons.speed),
                    label: const Text('Quick Test'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _isGenerating ? null : _clearTestData,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear Test Data'),
              style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
            ),
            TextButton.icon(
              onPressed: _isGenerating ? null : _triggerTrendAnalysis,
              icon: const Icon(Icons.trending_up, size: 16),
              label: const Text('Trigger Trend Analysis'),
              style: TextButton.styleFrom(foregroundColor: Colors.green[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureItem('• 15 Blood Sugar reports with upward trend'),
        _buildFeatureItem('• 6 A1c reports showing improvement'),
        _buildFeatureItem('• 8 CBC reports with infection spikes'),
        _buildFeatureItem('• Realistic anomalies and patterns'),
        _buildFeatureItem('• Perfect for testing trend graphs'),
      ],
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  Future<void> _generateFullTestData() async {
    setState(() => _isGenerating = true);

    try {
      await TrendAnalysisTestData.generateTestData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Test data generated successfully! Check Health Trends.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating test data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _generateQuickData() async {
    setState(() => _isGenerating = true);

    try {
      await TrendAnalysisTestData.generateQuickBloodSugarData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ Quick test data generated! Check Health Trends.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating quick data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _clearTestData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Test Data'),
        content: const Text(
          'Are you sure you want to clear all test data? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isGenerating = true);

      try {
        await TrendAnalysisTestData.clearTestData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🧹 Test data cleared successfully!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error clearing test data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isGenerating = false);
        }
      }
    }
  }

  Future<void> _triggerTrendAnalysis() async {
    setState(() => _isGenerating = true);

    try {
      // Import Firebase Functions
      final functions = FirebaseFunctions.instance;

      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be logged in');
      }

      // List of lab types to trigger analysis for
      final labTypes = [
        'Random Blood Sugar Test',
        'Hemoglobin A1c',
        'Complete Blood Count',
      ];

      for (final labType in labTypes) {
        try {
          final callable = functions.httpsCallable('detectLabTrends');
          await callable.call({'userId': user.uid, 'labReportType': labType});

          // Wait between calls
          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          print('Failed to trigger analysis for $labType: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🔄 Trend analysis triggered! Check Health Trends in a moment.',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error triggering analysis: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}

/// Compact version for floating action button or small spaces
class TrendTestDataButton extends StatefulWidget {
  const TrendTestDataButton({Key? key}) : super(key: key);

  @override
  State<TrendTestDataButton> createState() => _TrendTestDataButtonState();
}

class _TrendTestDataButtonState extends State<TrendTestDataButton> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _isGenerating ? null : _generateTestData,
      icon: _isGenerating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.auto_graph),
      label: Text(_isGenerating ? 'Generating...' : 'Generate Test Data'),
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
    );
  }

  Future<void> _generateTestData() async {
    setState(() => _isGenerating = true);

    try {
      await TrendAnalysisTestData.generateTestData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test data generated! Check Health Trends screen.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
