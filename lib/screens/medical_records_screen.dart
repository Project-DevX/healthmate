import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/document_service.dart';
import '../services/gemini_service.dart';
import '../services/lab_report_type_service.dart';
import '../screens/medical_summary_screen.dart';

class MedicalRecordsScreen extends StatefulWidget {
  final String userId;

  const MedicalRecordsScreen({super.key, required this.userId});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final DocumentService _documentService = DocumentService();
  final GeminiService _geminiService = GeminiService();
  bool _isLoading = true;
  List<DocumentInfo> _documents = [];
  String _selectedCategory = 'All';

  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.folder, 'color': Colors.grey},
    {'name': 'Lab Reports', 'icon': Icons.science, 'color': Colors.blue},
    {'name': 'Prescriptions', 'icon': Icons.medication, 'color': Colors.green},
    {'name': 'Doctor Notes', 'icon': Icons.note_alt, 'color': Colors.orange},
    {'name': 'Other', 'icon': Icons.description, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);

    try {
      final docs = await _documentService.getUserDocuments(widget.userId);
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading documents: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openDocument(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening document: $e')));
    }
  }

  Future<void> _deleteDocument(DocumentInfo document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      final success = await _documentService.deleteDocument(
        widget.userId,
        document,
      );

      if (success) {
        _loadDocuments(); // Reload the list
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document deleted')));
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete document')),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _viewMedicalSummary() async {
    // Show analysis type selection dialog
    final selectedAnalysisType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Analysis Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select what documents to include in your AI summary:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.science, color: Colors.blue),
              title: const Text('Lab Reports Only'),
              subtitle: const Text(
                'Generate summary using only lab reports and test results',
              ),
              onTap: () => Navigator.of(context).pop('lab_reports_only'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_shared, color: Colors.green),
              title: const Text('All Documents'),
              subtitle: const Text(
                'Generate comprehensive summary using all medical documents',
              ),
              onTap: () => Navigator.of(context).pop('all_documents'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // If user cancelled, return
    if (selectedAnalysisType == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Check if there are new documents that need analysis
      final statusData = await _geminiService.checkAnalysisStatus(
        analysisType: selectedAnalysisType,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (statusData['needsAnalysis']) {
        // There are new documents - trigger analysis before showing summary
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MedicalSummaryScreen(
              userId: widget.userId,
              autoTriggerAnalysis: true,
              analysisType: selectedAnalysisType,
            ),
          ),
        );
      } else {
        // No new documents - just show the summary
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MedicalSummaryScreen(
              userId: widget.userId,
              analysisType: selectedAnalysisType,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking analysis status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<DocumentInfo> get _filteredDocuments {
    if (_selectedCategory == 'All') return _documents;

    String categoryFilter;
    switch (_selectedCategory) {
      case 'Lab Reports':
        categoryFilter = 'lab_reports';
        break;
      case 'Prescriptions':
        categoryFilter = 'prescriptions';
        break;
      case 'Doctor Notes':
        categoryFilter = 'doctor_notes';
        break;
      case 'Other':
        categoryFilter = 'other';
        break;
      default:
        return _documents;
    }

    return _documents.where((doc) => doc.category == categoryFilter).toList();
  }

  int _getCategoryCount(String categoryName) {
    if (categoryName == 'All') return _documents.length;

    String categoryFilter;
    switch (categoryName) {
      case 'Lab Reports':
        categoryFilter = 'lab_reports';
        break;
      case 'Prescriptions':
        categoryFilter = 'prescriptions';
        break;
      case 'Doctor Notes':
        categoryFilter = 'doctor_notes';
        break;
      case 'Other':
        categoryFilter = 'other';
        break;
      default:
        return 0;
    }

    return _documents.where((doc) => doc.category == categoryFilter).length;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == 'All'
                ? 'No medical records found'
                : 'No ${_selectedCategory.toLowerCase()} found',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your first medical document',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(DocumentInfo document) {
    final categoryInfo = _categories.firstWhere(
      (cat) => _getCategoryNameFromType(document.category) == cat['name'],
      orElse: () => _categories.last, // Default to 'Other'
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _getFileIcon(document.fileType),
        title: Row(
          children: [
            Expanded(
              child: Text(
                document.fileName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: categoryInfo['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    categoryInfo['icon'],
                    size: 14,
                    color: categoryInfo['color'],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getCategoryDisplayName(document.category),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: categoryInfo['color'],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  document.subfolder,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Spacer(),
                if (document.classificationConfidence > 0.7)
                  Icon(Icons.check_circle, size: 14, color: Colors.green)
                else if (document.classificationConfidence > 0.4)
                  Icon(Icons.help_outline, size: 14, color: Colors.orange)
                else
                  Icon(Icons.error_outline, size: 14, color: Colors.red),
              ],
            ),
            const SizedBox(height: 4),
            // Show lab report type if this is a lab report
            if (document.category == 'lab_reports' &&
                document.labReportType != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science, size: 12, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Type: ${LabReportTypeService.getDisplayName(document.labReportType!)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text(
              'Size: ${_formatFileSize(document.fileSize)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Uploaded: ${DateFormat('MMM d, yyyy').format(document.uploadDate)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (document.classificationReasoning.isNotEmpty)
              Text(
                'AI: ${document.classificationReasoning}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openDocument(document.downloadUrl),
              tooltip: 'Open document',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteDocument(document),
              tooltip: 'Delete document',
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryNameFromType(String categoryType) {
    switch (categoryType) {
      case 'lab_reports':
        return 'Lab Reports';
      case 'prescriptions':
        return 'Prescriptions';
      case 'doctor_notes':
        return 'Doctor Notes';
      default:
        return 'Other';
    }
  }

  String _getCategoryDisplayName(String categoryType) {
    switch (categoryType) {
      case 'lab_reports':
        return 'Lab';
      case 'prescriptions':
        return 'Rx';
      case 'doctor_notes':
        return 'Notes';
      default:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records'),
        actions: [
          if (_documents.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.summarize),
              tooltip: 'View AI Summary',
              onPressed: _viewMedicalSummary,
            ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Section
          Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category['name'];
                final count = _getCategoryCount(category['name']);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category['name'];
                    });
                  },
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? category['color'].withOpacity(0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? category['color']
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category['icon'],
                          size: 32,
                          color: isSelected
                              ? category['color']
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category['name'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? category['color']
                                : Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: category['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: category['color'],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Add a prominent summary button
          if (_documents.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _viewMedicalSummary,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('View AI Medical Summary'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Documents List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDocuments.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredDocuments.length,
                    itemBuilder: (context, index) {
                      final doc = _filteredDocuments[index];
                      return _buildDocumentCard(doc);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "medical_records_fab",
        onPressed: () async {
          await _documentService.uploadDocument(context, widget.userId);
          _loadDocuments(); // Reload after upload
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _getFileIcon(String fileType) {
    IconData iconData;
    Color color;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        color = Colors.blue;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        iconData = Icons.image;
        color = Colors.green;
        break;
      default:
        iconData = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withOpacity(0.2),
      child: Icon(iconData, color: color),
    );
  }
}
