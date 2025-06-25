import 'dart:io';
import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../services/medical_records_service.dart';

class UploadProgressDialog extends StatefulWidget {
  final File file;
  final MedicalRecordsService recordsService;

  const UploadProgressDialog({
    super.key,
    required this.file,
    required this.recordsService,
  });

  @override
  _UploadProgressDialogState createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog> {
  double _progress = 0.0;
  bool _isUploading = false;
  String _selectedCategory = DocumentCategory.general.displayName;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Upload Document'),
      content: _isUploading ? _buildUploadingContent() : _buildFormContent(),
      actions: _isUploading ? null : _buildFormActions(),
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // File info
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.path.split('/').last,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Category selection
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          items: DocumentCategory.values
              .map(
                (category) => DropdownMenuItem(
                  value: category.displayName,
                  child: Row(
                    children: [
                      Icon(category.icon, size: 20),
                      SizedBox(width: 8),
                      Text(category.displayName),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value!;
            });
          },
        ),
        SizedBox(height: 16),
        // Description
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildUploadingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(value: _progress),
        SizedBox(height: 16),
        Text('Uploading... ${(_progress * 100).toInt()}%'),
        SizedBox(height: 8),
        LinearProgressIndicator(value: _progress),
      ],
    );
  }

  List<Widget> _buildFormActions() {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel'),
      ),
      ElevatedButton(onPressed: _uploadDocument, child: Text('Upload')),
    ];
  }

  Future<void> _uploadDocument() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final documentId = await widget.recordsService.uploadDocument(
        file: widget.file,
        category: _selectedCategory,
        description: _descriptionController.text,
        onProgress: (progress) {
          setState(() {
            _progress = progress;
          });
        },
      );

      if (documentId != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document uploaded successfully!')),
        );
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _progress = 0.0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
