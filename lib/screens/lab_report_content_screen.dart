import 'package:flutter/material.dart';
import '../services/lab_report_service.dart';

class LabReportContentScreen extends StatefulWidget {
  const LabReportContentScreen({Key? key}) : super(key: key);

  @override
  State<LabReportContentScreen> createState() => _LabReportContentScreenState();
}

class _LabReportContentScreenState extends State<LabReportContentScreen> {
  List<LabReportContent> _labReports = [];
  bool _isLoading = true;
  String _selectedType = 'all';
  List<String> _availableTypes = ['all'];

  @override
  void initState() {
    super.initState();
    _loadLabReports();
  }

  Future<void> _loadLabReports() async {
    try {
      setState(() => _isLoading = true);

      final result = await LabReportService.getLabReportContent(
        labReportType: _selectedType == 'all' ? null : _selectedType,
      );

      final List<LabReportContent> reports = (result['labReports'] as List)
          .map(
            (item) => LabReportContent.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();

      final Map<String, dynamic> reportsByTypeMap = Map<String, dynamic>.from(
        result['reportsByType'] ?? {},
      );
      final Map<String, List<LabReportContent>> reportsByType = {};

      for (String type in reportsByTypeMap.keys) {
        final List<dynamic> typeReports = reportsByTypeMap[type];
        reportsByType[type] = typeReports
            .map(
              (item) =>
                  LabReportContent.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList();
      }

      final List<String> availableTypes =
          ['all'] + List<String>.from(result['availableTypes'] ?? []);

      setState(() {
        _labReports = reports;
        _availableTypes = availableTypes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lab reports: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Report Content'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLabReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterSection(),
                Expanded(
                  child: _labReports.isEmpty
                      ? _buildEmptyState()
                      : _buildLabReportsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Report Type:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _availableTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(
                  type == 'all' ? 'All Reports' : _formatLabReportType(type),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedType = value);
                _loadLabReports();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Lab Reports Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload lab reports to see extracted content here',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLabReportsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _labReports.length,
      itemBuilder: (context, index) {
        final report = _labReports[index];
        return _buildLabReportCard(report);
      },
    );
  }

  Widget _buildLabReportCard(LabReportContent report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          report.fileName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.formattedLabReportType,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (report.testDate != null)
              Text(
                'Test Date: ${report.testDate}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.science, color: Colors.white),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTestResults(report),
                if (report.extractedText.isNotEmpty) ...[
                  const Divider(),
                  _buildExtractedText(report),
                ],
                if (report.labInfo.name != null ||
                    report.labInfo.orderingPhysician != null) ...[
                  const Divider(),
                  _buildLabInfo(report),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResults(LabReportContent report) {
    if (report.testResults.isEmpty) {
      return const Text(
        'No structured test results extracted',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Test Results:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...report.testResults.map((test) => _buildTestResultRow(test)),
      ],
    );
  }

  Widget _buildTestResultRow(TestResult test) {
    Color statusColor = Colors.green;
    if (test.status.toLowerCase() == 'high') {
      statusColor = Colors.red;
    } else if (test.status.toLowerCase() == 'low') {
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: test.isAbnormal ? statusColor.withOpacity(0.1) : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  test.testName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (test.referenceRange.isNotEmpty)
                  Text(
                    'Normal: ${test.referenceRange}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${test.value} ${test.unit}'.trim(),
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              test.status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedText(LabReportContent report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Extracted Text:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            report.extractedText,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildLabInfo(LabReportContent report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Laboratory Information:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (report.labInfo.name != null) Text('Lab: ${report.labInfo.name}'),
        if (report.labInfo.orderingPhysician != null)
          Text('Ordering Physician: ${report.labInfo.orderingPhysician}'),
      ],
    );
  }

  String _formatLabReportType(String type) {
    switch (type) {
      case 'blood_sugar':
        return 'Blood Sugar';
      case 'cholesterol':
        return 'Cholesterol';
      case 'liver_function':
        return 'Liver Function';
      case 'kidney_function':
        return 'Kidney Function';
      case 'thyroid_function':
        return 'Thyroid Function';
      case 'complete_blood_count':
        return 'Complete Blood Count';
      case 'cardiac_markers':
        return 'Cardiac Markers';
      case 'vitamin_levels':
        return 'Vitamin Levels';
      case 'inflammatory_markers':
        return 'Inflammatory Markers';
      case 'other_lab_tests':
        return 'Other Lab Tests';
      default:
        return type
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }
}
