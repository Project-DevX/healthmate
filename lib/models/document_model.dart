import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MedicalDocument {
  final String id;
  final String fileName;
  final String filePath;
  final String downloadUrl;
  final String category;
  final String description;
  final DateTime uploadDate;
  final String uploadedBy;
  final int fileSize;
  final String fileType;
  final Map<String, dynamic>? metadata;

  MedicalDocument({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.downloadUrl,
    required this.category,
    required this.description,
    required this.uploadDate,
    required this.uploadedBy,
    required this.fileSize,
    required this.fileType,
    this.metadata,
  });

  factory MedicalDocument.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MedicalDocument(
      id: doc.id,
      fileName: data['fileName'] ?? '',
      filePath: data['filePath'] ?? '',
      downloadUrl: data['downloadUrl'] ?? '',
      category: data['category'] ?? 'General',
      description: data['description'] ?? '',
      uploadDate: (data['uploadDate'] as Timestamp).toDate(),
      uploadedBy: data['uploadedBy'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      fileType: data['fileType'] ?? '',
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'filePath': filePath,
      'downloadUrl': downloadUrl,
      'category': category,
      'description': description,
      'uploadDate': Timestamp.fromDate(uploadDate),
      'uploadedBy': uploadedBy,
      'fileSize': fileSize,
      'fileType': fileType,
      'metadata': metadata,
    };
  }
}

enum DocumentCategory {
  labReports('Lab Reports', Icons.science),
  prescriptions('Prescriptions', Icons.medication),
  xRays('X-Rays', Icons.medical_services),
  scanReports('Scan Reports', Icons.scanner),
  discharge('Discharge Summary', Icons.assignment),
  insurance('Insurance', Icons.health_and_safety),
  vaccination('Vaccination', Icons.vaccines),
  general('General', Icons.folder);

  const DocumentCategory(this.displayName, this.icon);
  final String displayName;
  final IconData icon;
}
