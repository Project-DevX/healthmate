import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/medical_record.dart';
import '../services/medical_records_service_clean.dart';

class MedicalRecordsScreen extends StatefulWidget {
  final String userId;

  const MedicalRecordsScreen({Key? key, required this.userId})
    : super(key: key);

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final MedicalRecordsService _service = MedicalRecordsService();
  List<MedicalRecord> _records = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final records = await _service.getMedicalRecords(widget.userId);
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading records: $e', Colors.red);
    }
  }

  List<MedicalRecord> get _filteredRecords {
    if (_selectedFilter == 'All') return _records;
    return _records
        .where((record) => record.recordType == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter by Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('All'),
                      ...MedicalRecordType.allTypes.map(_buildFilterChip),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Records List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecords.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = _filteredRecords[index];
                      return _buildRecordCard(record);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadRecord,
        icon: const Icon(Icons.add),
        label: const Text('Upload'),
        tooltip: 'Upload medical record',
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(filter),
        onSelected: (selected) {
          setState(() => _selectedFilter = filter);
        },
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All'
                ? 'No medical records found'
                : 'No $_selectedFilter records found',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to upload your first record',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(MedicalRecord record) {
    final formattedDate = DateFormat('MMM d, yyyy').format(record.uploadDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _buildFileIcon(record.fileType),
        title: Text(
          record.fileName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(MedicalRecordType.getIcon(record.recordType)),
                const SizedBox(width: 4),
                Text(record.recordType),
                const Spacer(),
                Text(
                  '${_formatFileSize(record.fileSize)} • $formattedDate',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            if (record.description != null &&
                record.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                record.description!,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openRecord(record),
              tooltip: 'Open record',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () => _deleteRecord(record),
              tooltip: 'Delete record',
            ),
          ],
        ),
        onTap: () => _openRecord(record),
      ),
    );
  }

  Widget _buildFileIcon(String fileType) {
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _uploadRecord() async {
    final success = await _service.uploadMedicalRecord(context, widget.userId);
    if (success) {
      _loadRecords();
    }
  }

  Future<void> _openRecord(MedicalRecord record) async {
    try {
      final Uri uri = Uri.parse(record.downloadUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showSnackBar('Could not open record', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error opening record: $e', Colors.red);
    }
  }

  Future<void> _deleteRecord(MedicalRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Are you sure you want to delete "${record.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final success = await _service.deleteMedicalRecord(widget.userId, record);

      if (success) {
        _showSnackBar('Record deleted successfully', Colors.green);
        _loadRecords();
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to delete record', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
