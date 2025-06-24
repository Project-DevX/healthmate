import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/medical_record.dart';

class MedicalRecordsService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Upload a medical record
  Future<bool> uploadMedicalRecord(BuildContext context, String userId) async {
    try {
      // Step 1: Select record type
      String? recordType = await _showRecordTypeDialog(context);
      if (recordType == null) return false;

      // Step 2: Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return false;

      final file = result.files.first;

      // Step 3: Validate file size (10MB limit)
      const maxFileSize = 10 * 1024 * 1024;
      if (file.size > maxFileSize) {
        _showSnackBar(context, 'File size must be less than 10MB', Colors.red);
        return false;
      }

      // Step 4: Get description (optional)
      String? description = await _showDescriptionDialog(context);

      // Step 5: Show uploading progress
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Uploading medical record...'),
            ],
          ),
        ),
      );

      // Step 6: Upload file
      final fileToUpload = File(file.path!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(file.name);
      final storagePath = 'medical_records/$userId/${timestamp}_${file.name}';

      final uploadTask = _storage
          .ref(storagePath)
          .putFile(
            fileToUpload,
            SettableMetadata(contentType: _getContentType(fileExtension)),
          );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Step 7: Save to Firestore
      final record = MedicalRecord(
        id: '',
        userId: userId,
        fileName: file.name,
        fileType: fileExtension.replaceFirst('.', ''),
        fileSize: file.size,
        uploadDate: DateTime.now(),
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        recordType: recordType,
        description: description,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medical_records')
          .add(record.toMap());

      Navigator.of(context).pop(); // Dismiss loading dialog
      _showSnackBar(
        context,
        'Medical record uploaded successfully!',
        Colors.green,
      );
      return true;
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loading dialog
      _showSnackBar(
        context,
        'Error uploading record: ${e.toString()}',
        Colors.red,
      );
      return false;
    }
  }

  // Get medical records for a user
  Future<List<MedicalRecord>> getMedicalRecords(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medical_records')
          .orderBy('uploadDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MedicalRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching medical records: $e');
      return [];
    }
  }

  // Delete a medical record
  Future<bool> deleteMedicalRecord(String userId, MedicalRecord record) async {
    try {
      // Delete from storage
      await _storage.ref(record.storagePath).delete();

      // Delete from Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medical_records')
          .doc(record.id)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting medical record: $e');
      return false;
    }
  }

  // Helper methods
  Future<String?> _showRecordTypeDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Record Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MedicalRecordType.allTypes.map((type) {
            return ListTile(
              leading: Text(
                MedicalRecordType.getIcon(type),
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(type),
              onTap: () => Navigator.of(context).pop(type),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showDescriptionDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Description (Optional)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Brief description of the record...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
