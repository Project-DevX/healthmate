import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalRecord {
  final String id;
  final String userId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final DateTime uploadDate;
  final String downloadUrl;
  final String storagePath;
  final String recordType;
  final String? description;

  MedicalRecord({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.uploadDate,
    required this.downloadUrl,
    required this.storagePath,
    required this.recordType,
    this.description,
  });

  factory MedicalRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['uploadDate'] as Timestamp?;

    return MedicalRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      fileName: data['fileName'] ?? 'Unknown file',
      fileType: data['fileType'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      uploadDate: timestamp?.toDate() ?? DateTime.now(),
      downloadUrl: data['downloadUrl'] ?? '',
      storagePath: data['storagePath'] ?? '',
      recordType: data['recordType'] ?? 'Other',
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'uploadDate': FieldValue.serverTimestamp(),
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'recordType': recordType,
      'description': description,
    };
  }
}

// Medical Record Types
class MedicalRecordType {
  static const String labReport = 'Lab Report';
  static const String prescription = 'Prescription';
  static const String xray = 'X-Ray';
  static const String scan = 'Scan/MRI/CT';
  static const String discharge = 'Discharge Summary';
  static const String vaccine = 'Vaccination Record';
  static const String insurance = 'Insurance Document';
  static const String other = 'Other';

  static List<String> get allTypes => [
    labReport,
    prescription,
    xray,
    scan,
    discharge,
    vaccine,
    insurance,
    other,
  ];

  static String getIcon(String type) {
    switch (type) {
      case labReport:
        return '🧪';
      case prescription:
        return '💊';
      case xray:
        return '🦴';
      case scan:
        return '🧠';
      case discharge:
        return '🏥';
      case vaccine:
        return '💉';
      case insurance:
        return '📄';
      default:
        return '📋';
    }
  }
}
