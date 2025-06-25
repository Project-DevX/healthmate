import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/document_model.dart';

class MedicalRecordsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload document with progress tracking
  Future<String?> uploadDocument({
    required File file,
    required String category,
    required String description,
    required Function(double) onProgress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final fileName = file.path.split('/').last;
      final fileExtension = fileName.split('.').last.toLowerCase();
      final fileSize = await file.length();

      // Create unique file path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath =
          'medical_records/${user.uid}/$category/${timestamp}_$fileName';

      // Upload to Firebase Storage with progress tracking
      final storageRef = _storage.ref().child(filePath);
      final uploadTask = storageRef.putFile(file);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });

      final taskSnapshot = await uploadTask;
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Save document metadata to Firestore
      final documentData = MedicalDocument(
        id: '',
        fileName: fileName,
        filePath: filePath,
        downloadUrl: downloadUrl,
        category: category,
        description: description,
        uploadDate: DateTime.now(),
        uploadedBy: user.email ?? 'Unknown',
        fileSize: fileSize,
        fileType: fileExtension,
        metadata: {
          'originalPath': file.path,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final docRef = await _firestore
          .collection('medical_records')
          .doc(user.uid)
          .collection('documents')
          .add(documentData.toFirestore());

      return docRef.id;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // Get documents with filtering and sorting
  Stream<List<MedicalDocument>> getDocuments({
    String? category,
    String? searchQuery,
    String sortBy = 'uploadDate',
    bool descending = true,
  }) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    Query query = _firestore
        .collection('medical_records')
        .doc(user.uid)
        .collection('documents');

    // Apply category filter
    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    // Apply sorting
    query = query.orderBy(sortBy, descending: descending);

    return query.snapshots().map((snapshot) {
      List<MedicalDocument> documents = snapshot.docs
          .map((doc) => MedicalDocument.fromFirestore(doc))
          .toList();

      // Apply search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        documents = documents.where((doc) {
          return doc.fileName.toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ||
              doc.description.toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ||
              doc.category.toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();
      }

      return documents;
    });
  }

  // Delete document
  Future<bool> deleteDocument(String documentId, String filePath) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Delete from Firestore
      await _firestore
          .collection('medical_records')
          .doc(user.uid)
          .collection('documents')
          .doc(documentId)
          .delete();

      // Delete from Storage
      await _storage.ref().child(filePath).delete();

      return true;
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }

  // Download document
  Future<String?> downloadDocument(MedicalDocument document) async {
    try {
      // Request storage permission
      if (await Permission.storage.request().isGranted) {
        final directory = await getExternalStorageDirectory();
        final filePath = '${directory!.path}/HealthMate/${document.fileName}';

        // Create directory if it doesn't exist
        final file = File(filePath);
        await file.parent.create(recursive: true);

        // Download file
        await _storage.ref().child(document.filePath).writeToFile(file);

        return filePath;
      }
      return null;
    } catch (e) {
      print('Download error: $e');
      return null;
    }
  }

  // Pick file from device
  Future<File?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        return File(result.files.first.path!);
      }
      return null;
    } catch (e) {
      print('File picker error: $e');
      return null;
    }
  }

  // Pick image from camera or gallery
  Future<File?> pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('Image picker error: $e');
      return null;
    }
  }

  // Get document statistics
  Future<Map<String, int>> getDocumentStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final snapshot = await _firestore
          .collection('medical_records')
          .doc(user.uid)
          .collection('documents')
          .get();

      Map<String, int> stats = {};
      for (var category in DocumentCategory.values) {
        stats[category.displayName] = 0;
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] ?? 'General';
        stats[category] = (stats[category] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Stats error: $e');
      return {};
    }
  }
}
