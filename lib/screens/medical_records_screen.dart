import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/document_service.dart';
import '../services/gemini_service.dart';
import '../screens/medical_summary_screen.dart';

class MedicalRecordsScreen extends StatefulWidget {
  final String userId;

  const MedicalRecordsScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final DocumentService _documentService = DocumentService();
  bool _isLoading = true;
  bool _isAnalyzing = false;
  List<DocumentInfo> _documents = [];

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading documents: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening document: $e')),
      );
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
      
      final success = await _documentService.deleteDocument(widget.userId, document);
      
      if (success) {
        _loadDocuments(); // Reload the list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
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

  void _analyzeDocuments() async {
    if (_documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No medical records found to analyze')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    
    try {
      final geminiService = GeminiService();
      final summary = await geminiService.analyzeMedicalRecords(widget.userId);
      
      setState(() => _isAnalyzing = false);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MedicalSummaryScreen(userId: widget.userId),
          ),
        );
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing documents: $e')),
        );
      }
    }
  }

  void _viewMedicalSummary() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalSummaryScreen(userId: widget.userId),
      ),
    );
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
          // Add a prominent summary button at the top
          if (_documents.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _viewMedicalSummary,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('View AI Medical Summary'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          // Existing content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No medical records found',
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _documents.length,
                        itemBuilder: (context, index) {
                          final doc = _documents[index];
                          final formattedDate = DateFormat('MMM d, yyyy').format(doc.uploadDate);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: _getFileIcon(doc.fileType),
                              title: Text(
                                doc.fileName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${_formatFileSize(doc.fileSize)} • $formattedDate',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: () => _openDocument(doc.downloadUrl),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                    onPressed: () => _deleteDocument(doc),
                                  ),
                                ],
                              ),
                              onTap: () => _openDocument(doc.downloadUrl),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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