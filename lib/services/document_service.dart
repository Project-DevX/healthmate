import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class DocumentService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadDocument(BuildContext context, String userId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'webp'],
        allowMultiple: false,
        withData: true, // Always get bytes for web compatibility
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Validate file size (max 10MB)
        if (file.size > 10 * 1024 * 1024) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size should be less than 10MB')),
          );
          return;
        }

        // Ensure we have file bytes
        if (file.bytes == null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to read file data')),
          );
          return;
        }

        String fileName = file.name;
        String fileExtension = fileName.split('.').last.toLowerCase();
        String uniqueFileName =
            '${DateTime.now().millisecondsSinceEpoch}_$fileName';

        // Create reference to Firebase Storage
        Reference ref = _storage
            .ref()
            .child('medical_documents')
            .child(userId)
            .child(uniqueFileName);

        // Upload using bytes (works for both web and mobile)
        UploadTask uploadTask = ref.putData(
          file.bytes!,
          SettableMetadata(
            contentType: _getContentType(fileExtension),
            customMetadata: {'uploadedBy': userId, 'originalName': fileName},
          ),
        );

        // Monitor upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        });

        // Wait for upload completion
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // Classify document using AI
        String category = 'other';
        String subfolder = 'general';
        double confidence = 0.0;
        String reasoning = 'No classification attempted';
        String? labReportType;

        try {
          final classificationResult = await _classifyDocument(
            fileName,
            ref.fullPath,
          );
          category = classificationResult['category'] ?? 'other';
          subfolder = classificationResult['suggestedSubfolder'] ?? 'general';
          confidence = (classificationResult['confidence'] ?? 0.0).toDouble();
          reasoning = classificationResult['reasoning'] ?? 'AI classification';
          labReportType = classificationResult['labReportType'];

        } catch (e) {
          print('Classification error: $e');
        }

        // Save document metadata to Firestore
        final documentData = {
          'fileName': fileName,
          'fileSize': file.size,
          'fileType': fileExtension,
          'downloadUrl': downloadUrl,
          'uploadDate': FieldValue.serverTimestamp(),
          'storagePath': ref.fullPath,
          'category': category,
          'subfolder': subfolder,
          'classificationConfidence': confidence,
          'classificationReasoning': reasoning,
        };

        // Add lab report type if this is a lab report
        if (labReportType != null) {
          documentData['labReportType'] = labReportType;
        }

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('documents')
            .add(documentData);

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fileName uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      Navigator.pop(context);
      print('Error uploading document: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  // Classify document using Firebase Functions
  Future<Map<String, dynamic>> _classifyDocument(
    String fileName,
    String storagePath,
  ) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'classifyMedicalDocument',
      );
      final result = await callable.call({
        'fileName': fileName,
        'storagePath': storagePath,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('Error classifying document: $e');
      return {
        'category': 'other',
        'suggestedSubfolder': 'general',
        'confidence': 0.0,
        'reasoning': 'Classification failed: $e',
      };
    }
  }

  // Update lab report type using Cloud Function
  Future<void> _updateLabReportType(
    String fileName,
    String storagePath,
    String selectedType,
  ) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'updateLabReportType',
      );
      await callable.call({
        'fileName': fileName,
        'storagePath': storagePath,
        'selectedType': selectedType,
      });
    } catch (e) {
      print('Error updating lab report type: $e');
      rethrow;
    }
  }

  // Fetch documents for a specific user
  Future<List<DocumentInfo>> getUserDocuments(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('documents')
          .orderBy('uploadDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => DocumentInfo.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching documents: $e');
      return [];
    }
  }

  // Delete a document
  Future<bool> deleteDocument(String userId, DocumentInfo document) async {
    try {
      // 1. Delete from storage
      await _storage.ref(document.storagePath).delete();

      // 2. Delete from main documents collection (if you want to keep this collection)
      await _firestore
          .collection('documents')
          .where('storagePath', isEqualTo: document.storagePath)
          .get()
          .then((snapshot) {
            for (var doc in snapshot.docs) {
              doc.reference.delete();
            }
          });

      // 3. Delete from user's documents subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('documents')
          .doc(document.id)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting document: $e');
      return false;
    }
  }

  /// Get document text content for analysis
  Future<Map<String, String>> getDocumentContents(String userId) async {
    try {
      final documents = await getUserDocuments(userId);
      Map<String, String> contents = {};

      for (var doc in documents) {
        // Store document metadata in a structured format
        contents[doc.fileName] =
            'Type: ${doc.fileType}, Size: ${_formatFileSize(doc.fileSize)}, Date: ${_formatDate(doc.uploadDate)}';

        // For real implementation, you would extract text content here
        // This would require additional processing based on file type
      }

      return contents;
    } catch (e) {
      print('Error getting document contents: $e');
      return {};
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Model class for documents
class DocumentInfo {
  final String id;
  final String userId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final DateTime uploadDate;
  final String downloadUrl;
  final String storagePath;
  final String category;
  final String subfolder;
  final double classificationConfidence;
  final String classificationReasoning;
  final String? labReportType;

  DocumentInfo({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.uploadDate,
    required this.downloadUrl,
    required this.storagePath,
    this.category = 'other',
    this.subfolder = 'general',
    this.classificationConfidence = 0.0,
    this.classificationReasoning = 'No classification',
    this.labReportType,
  });

  factory DocumentInfo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['uploadDate'] as Timestamp?;

    return DocumentInfo(
      id: doc.id,
      userId: data['userId'] ?? '',
      fileName: data['fileName'] ?? 'Unknown file',
      fileType: data['fileType'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      uploadDate: timestamp?.toDate() ?? DateTime.now(),
      downloadUrl: data['downloadUrl'] ?? '',
      storagePath: data['storagePath'] ?? '',
      category: data['category'] ?? 'other',
      subfolder: data['subfolder'] ?? 'general',
      classificationConfidence: (data['classificationConfidence'] ?? 0.0)
          .toDouble(),
      classificationReasoning:
          data['classificationReasoning'] ?? 'No classification',
      labReportType: data['labReportType'],
    );
  }
}
