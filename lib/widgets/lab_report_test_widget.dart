import 'package:flutter/material.dart';
import '../services/lab_report_service.dart';

class LabReportTestWidget extends StatefulWidget {
  const LabReportTestWidget({Key? key}) : super(key: key);

  @override
  State<LabReportTestWidget> createState() => _LabReportTestWidgetState();
}

class _LabReportTestWidgetState extends State<LabReportTestWidget> {
  bool _isLoading = false;
  String _result = '';

  Future<void> _testLabReportService() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final result = await LabReportService.getLabReportContent();
      setState(() {
        _result = 'Success! Found ${result['totalCount']} lab reports';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lab Report Service Test',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testLabReportService,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Test Lab Report Service'),
            ),
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _result.startsWith('Error')
                      ? Colors.red[50]
                      : Colors.green[50],
                  border: Border.all(
                    color: _result.startsWith('Error')
                        ? Colors.red
                        : Colors.green,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _result,
                  style: TextStyle(
                    color: _result.startsWith('Error')
                        ? Colors.red[800]
                        : Colors.green[800],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
