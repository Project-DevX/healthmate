import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/document_model.dart';

class DocumentPreviewDialog extends StatefulWidget {
  final MedicalDocument document;
  
  const DocumentPreviewDialog({Key? key, required this.document})
    : super(key: key);
    
  @override
  _DocumentPreviewDialogState createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<DocumentPreviewDialog> {
  bool _isDownloading = false;

class DocumentPreviewDialog extends StatefulWidget {
  final MedicalDocument document;
  
  const DocumentPreviewDialog({Key? key, required this.document})
    : super(key: key);
    
  @override
  _DocumentPreviewDialogState createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<DocumentPreviewDialog> {
  @override
  Widget build(BuildContext context) {
    final isImage = [
      'jpg',
      'jpeg',
      'png',
    ].contains(widget.document.fileType.toLowerCase());

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(                          widget.document.fileName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.document.category,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: isImage ? _buildImagePreview() : _buildFilePreview(),
            ),
            // Actions
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openDocument(),
                    icon: Icon(Icons.open_in_new),
                    label: Text('Open'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _downloadDocument(),
                    icon: Icon(Icons.download),
                    label: Text('Download'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildImagePreview() {
    return PhotoView(
      imageProvider: CachedNetworkImageProvider(widget.document.downloadUrl),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 2,
      heroAttributes: PhotoViewHeroAttributes(tag: widget.document.id),
    );
  }

  Widget _buildFilePreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileIcon(widget.document.fileType),
            size: 80,
            color: Colors.grey[600],
          ),
          SizedBox(height: 16),
          Text(
            widget.document.fileName,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            widget.document.description,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'File Size: ${_formatFileSize(widget.document.fileSize)}',
            style: TextStyle(color: Colors.grey[500]),
          ),
          SizedBox(height: 8),
          Text(
            'Uploaded: ${widget.document.uploadDate.toString().split(' ')[0]}',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  void _openDocument() async {
    final url = Uri.parse(widget.document.downloadUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }  Future<void> _downloadDocument() async {
    try {
      setState(() {
        _isDownloading = true;
      });
      
      // Get storage permissions
      if (await Permission.storage.request().isGranted) {
        // Show a loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading document...')),
        );
        
        // Use path_provider to get the external storage directory
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          throw Exception('Could not access storage directory');
        }
        
        // Create the file path
        final filePath = '${directory.path}/HealthMate/${document.fileName}';
        final file = File(filePath);
        
        // Create parent directories if they don't exist
        if (!(await file.parent.exists())) {
          await file.parent.create(recursive: true);
        }
        
        // Download the file from Firebase Storage
        final ref = FirebaseStorage.instance.refFromURL(document.downloadUrl);
        await ref.writeToFile(file);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document downloaded to: $filePath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage permission denied')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading document: $e')),
      );
    }
  }
}
