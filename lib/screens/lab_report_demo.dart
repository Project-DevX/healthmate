import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/lab_report_service.dart';

class LabReportDemo extends StatelessWidget {
  const LabReportDemo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Report Feature Demo'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFeatureOverview(),
            const SizedBox(height: 24),
            _buildHowItWorks(),
            const SizedBox(height: 24),
            _buildDemoButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureOverview() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.teal, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Lab Report Content Extraction',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Automatically extracts text content from lab reports using AI when documents are uploaded.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Features:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildFeatureItem('🔬', 'Automatic OCR text extraction'),
            _buildFeatureItem(
              '📊',
              'Structured test results with values and ranges',
            ),
            _buildFeatureItem('🏥', 'Lab report type classification'),
            _buildFeatureItem('⚠️', 'Abnormal value highlighting'),
            _buildFeatureItem('📱', 'Easy mobile viewing interface'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How It Works',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStep(1, 'Upload a lab report document'),
            _buildStep(2, 'AI automatically classifies it as a lab report'),
            _buildStep(3, 'Gemini AI extracts text using OCR'),
            _buildStep(4, 'Content is stored in structured format'),
            _buildStep(5, 'View organized results in the app'),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.teal,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildDemoButton(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Try It Out',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('To test this feature:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            const Text(
              '1. Upload a lab report through Medical Records\n'
              '2. Wait for AI processing (about 10-30 seconds)\n'
              '3. Check the Lab Reports section to view extracted content',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _testLabReportService(context),
                icon: const Icon(Icons.science),
                label: const Text('View Lab Reports'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _testLabReportService(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view lab reports')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await LabReportService.getLabReportContent();
      Navigator.of(context).pop(); // Close loading dialog

      final count = result['totalCount'] ?? 0;
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found $count lab reports!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to lab reports screen
        Navigator.pushNamed(context, '/lab-reports');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No lab reports found. Upload some lab reports first!',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
