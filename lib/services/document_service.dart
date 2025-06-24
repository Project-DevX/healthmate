import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class DocumentService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Upload a document to Firebase Storage and save reference to Firestore
  Future<bool> uploadDocument(BuildContext context, String userId) async {
    try {
      // 1. Pick file using file_picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) {
        // User canceled the picker
        return false;
      }

      final file = result.files.first;
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading document...')),
      );

      // 2. Process file
      late File fileToUpload;
      String fileName = file.name;
      
      if (file.path != null) {
        fileToUpload = File(file.path!);
      } else {
        // Handle web platform or path issue
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to process file')),
        );
        return false;
      }

      // 3. Generate a unique storage path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(fileName);
      final storagePath = 'documents/$userId/${timestamp}_$fileName';

      // 4. Upload to Firebase Storage
      final uploadTask = _storage.ref(storagePath).putFile(
        fileToUpload,
        SettableMetadata(
          contentType: _getContentType(fileExtension),
        ),
      );

      // 5. Monitor upload progress (optional)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        // Could update UI with progress if needed
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // 6. Wait for upload to complete
      final snapshot = await uploadTask;

      // 7. Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 8. Save document reference to Firestore
      final docData = {
        'userId': userId,
        'fileName': fileName,
        'fileType': fileExtension.replaceFirst('.', ''),
        'fileSize': file.size,
        'uploadDate': FieldValue.serverTimestamp(),
        'downloadUrl': downloadUrl,
        'storagePath': storagePath,
      };

      // Save to documents collection with a reference to user
      await _firestore.collection('documents').add(docData);

      // Also save reference in user's documents subcollection for easy querying
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('documents')
          .add(docData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully')),
      );
      return true;
    } catch (e) {
      print('Error uploading document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading document: ${e.toString()}')),
      );
      return false;
    }
  }

  // Get content type based on file extension
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

  DocumentInfo({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.uploadDate,
    required this.downloadUrl,
    required this.storagePath,
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
    );
  }
}