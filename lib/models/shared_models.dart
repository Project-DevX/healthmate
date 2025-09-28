// lib/models/shared_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Shared Appointment Model for all roles
class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String hospitalId;
  final String hospitalName;
  final DateTime appointmentDate;
  final String timeSlot;
  final String status; // scheduled, confirmed, completed, cancelled
  final String? reason;
  final String? notes;
  final DateTime createdAt;
  final String? caregiverId;
  final String? symptoms;
  final String? prescriptionId;
  final List<String>? labTestIds;

  Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.hospitalId,
    required this.hospitalName,
    required this.appointmentDate,
    required this.timeSlot,
    required this.status,
    this.reason,
    this.notes,
    required this.createdAt,
    this.caregiverId,
    this.symptoms,
    this.prescriptionId,
    this.labTestIds,
  });

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      patientEmail: data['patientEmail'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      doctorSpecialty: data['doctorSpecialty'] ?? '',
      hospitalId: data['hospitalId'] ?? '',
      hospitalName: data['hospitalName'] ?? '',
      appointmentDate: (data['appointmentDate'] as Timestamp).toDate(),
      timeSlot: data['timeSlot'] ?? '',
      status: data['status'] ?? 'scheduled',
      reason: data['reason'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      caregiverId: data['caregiverId'],
      symptoms: data['symptoms'],
      prescriptionId: data['prescriptionId'],
      labTestIds: List<String>.from(data['labTestIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'patientEmail': patientEmail,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'hospitalId': hospitalId,
      'hospitalName': hospitalName,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'timeSlot': timeSlot,
      'status': status,
      'reason': reason,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'caregiverId': caregiverId,
      'symptoms': symptoms,
      'prescriptionId': prescriptionId,
      'labTestIds': labTestIds ?? [],
    };
  }
}

// Doctor Profile for listing
class DoctorProfile {
  final String id;
  final String name;
  final String email;
  final String specialty;
  final String hospitalId;
  final String hospitalName;
  final List<String> qualifications;
  final int experienceYears;
  final double rating;
  final List<String> availableDays;
  final List<String> timeSlots;
  final double consultationFee;
  final String? profileImageUrl;
  final bool isAvailable;

  DoctorProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.specialty,
    required this.hospitalId,
    required this.hospitalName,
    required this.qualifications,
    required this.experienceYears,
    required this.rating,
    required this.availableDays,
    required this.timeSlots,
    required this.consultationFee,
    this.profileImageUrl,
    required this.isAvailable,
  });

  factory DoctorProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DoctorProfile(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      specialty: data['specialty'] ?? '',
      hospitalId: data['hospitalId'] ?? '',
      hospitalName: data['hospitalName'] ?? '',
      qualifications: List<String>.from(data['qualifications'] ?? []),
      experienceYears: data['experienceYears'] ?? 0,
      rating: (data['rating'] ?? 0.0).toDouble(),
      availableDays: List<String>.from(data['availableDays'] ?? []),
      timeSlots: List<String>.from(data['timeSlots'] ?? []),
      consultationFee: (data['consultationFee'] ?? 0.0).toDouble(),
      profileImageUrl: data['profileImageUrl'],
      isAvailable: data['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'specialty': specialty,
      'hospitalId': hospitalId,
      'hospitalName': hospitalName,
      'qualifications': qualifications,
      'experienceYears': experienceYears,
      'rating': rating,
      'availableDays': availableDays,
      'timeSlots': timeSlots,
      'consultationFee': consultationFee,
      'profileImageUrl': profileImageUrl,
      'isAvailable': isAvailable,
    };
  }
}

// Lab Test/Report Model
class LabReport {
  final String id;
  final String patientId;
  final String patientName;
  final String labId;
  final String labName;
  final String doctorId;
  final String? doctorName;
  final String testType;
  final String testName;
  final DateTime testDate;
  final String status; // requested, in_progress, completed, uploaded
  final String? reportUrl;
  final Map<String, dynamic>? results;
  final String? notes;
  final DateTime createdAt;
  final String? appointmentId;

  LabReport({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.labId,
    required this.labName,
    required this.doctorId,
    this.doctorName,
    required this.testType,
    required this.testName,
    required this.testDate,
    required this.status,
    this.reportUrl,
    this.results,
    this.notes,
    required this.createdAt,
    this.appointmentId,
  });

  factory LabReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LabReport(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      labId: data['labId'] ?? '',
      labName: data['labName'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'],
      testType: data['testType'] ?? '',
      testName: data['testName'] ?? '',
      testDate: (data['testDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'requested',
      reportUrl: data['reportUrl'],
      results: data['results'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      appointmentId: data['appointmentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'labId': labId,
      'labName': labName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'testType': testType,
      'testName': testName,
      'testDate': Timestamp.fromDate(testDate),
      'status': status,
      'reportUrl': reportUrl,
      'results': results,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'appointmentId': appointmentId,
    };
  }
}

// Prescription Model
class Prescription {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String pharmacyId;
  final String? pharmacyName;
  final List<PrescriptionMedicine> medicines;
  final DateTime prescribedDate;
  final String status; // prescribed, filled, partial, cancelled
  final String? notes;
  final String? appointmentId;
  final DateTime? filledDate;

  Prescription({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.pharmacyId,
    this.pharmacyName,
    required this.medicines,
    required this.prescribedDate,
    required this.status,
    this.notes,
    this.appointmentId,
    this.filledDate,
  });

  factory Prescription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Prescription(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      pharmacyId: data['pharmacyId'] ?? '',
      pharmacyName: data['pharmacyName'],
      medicines: (data['medicines'] as List? ?? [])
          .map((med) => PrescriptionMedicine.fromMap(med))
          .toList(),
      prescribedDate:
          (data['prescribedDate'] as Timestamp?)?.toDate() ??
          (data['prescriptionDate'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      status: data['status'] ?? 'prescribed',
      notes: data['notes'],
      appointmentId: data['appointmentId'],
      filledDate: data['filledDate'] != null
          ? (data['filledDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'medicines': medicines.map((med) => med.toMap()).toList(),
      'prescribedDate': Timestamp.fromDate(prescribedDate),
      'status': status,
      'notes': notes,
      'appointmentId': appointmentId,
      'filledDate': filledDate != null ? Timestamp.fromDate(filledDate!) : null,
    };
  }
}

class PrescriptionMedicine {
  final String name;
  final String dosage;
  final String frequency;
  final String
  duration; // Changed from int to String to handle "5 days", "7 days", etc.
  final String instructions;
  final int quantity; // Add quantity field but no pricing

  PrescriptionMedicine({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instructions,
    required this.quantity,
  });

  factory PrescriptionMedicine.fromMap(Map<String, dynamic> map) {
    // Handle duration field with robust parsing
    String durationStr = '0';
    if (map['duration'] != null) {
      final durationValue = map['duration'];
      if (durationValue is String) {
        durationStr = durationValue;
      } else if (durationValue is int) {
        durationStr = durationValue.toString();
      } else if (durationValue is double) {
        durationStr = durationValue.toInt().toString();
      } else {
        durationStr = durationValue.toString();
      }
    }

    // Handle quantity field with robust parsing
    int quantityInt = 1;
    if (map['quantity'] != null) {
      final quantityValue = map['quantity'];
      if (quantityValue is int) {
        quantityInt = quantityValue;
      } else if (quantityValue is String) {
        quantityInt = int.tryParse(quantityValue) ?? 1;
      } else if (quantityValue is double) {
        quantityInt = quantityValue.toInt();
      }
    }

    return PrescriptionMedicine(
      name: map['name']?.toString() ?? '',
      dosage: map['dosage']?.toString() ?? '',
      frequency: map['frequency']?.toString() ?? '',
      duration: durationStr,
      instructions: map['instructions']?.toString() ?? '',
      quantity: quantityInt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
      'quantity': quantity,
    };
  }
}

// Notification Model for cross-role communication
class NotificationModel {
  final String id;
  final String recipientId;
  final String recipientType; // patient, doctor, pharmacy, lab, hospital
  final String senderId;
  final String senderType;
  final String senderName;
  final String title;
  final String message;
  final String type; // appointment, lab_result, prescription, general
  final String? relatedId; // appointment id, prescription id, etc.
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.recipientId,
    required this.recipientType,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      recipientId: data['recipientId'] ?? '',
      recipientType: data['recipientType'] ?? '',
      senderId: data['senderId'] ?? '',
      senderType: data['senderType'] ?? '',
      senderName: data['senderName'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'general',
      relatedId: data['relatedId'],
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'recipientType': recipientType,
      'senderId': senderId,
      'senderType': senderType,
      'senderName': senderName,
      'title': title,
      'message': message,
      'type': type,
      'relatedId': relatedId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// Medical Record Access Consent Model
class ConsentRequest {
  final String id;
  final String requestId;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String patientId;
  final String patientName;
  final String requestType; // 'lab_reports', 'prescriptions', 'full_history'
  final String purpose; // Reason for access request
  final DateTime requestDate;
  final String status; // 'pending', 'approved', 'denied', 'expired'
  final DateTime? responseDate;
  final DateTime? expiryDate; // When consent expires
  final String? patientResponse; // Patient's reason for approval/denial
  final List<String>? specificRecordIds; // If requesting specific records
  final String appointmentId; // Related appointment
  final int durationDays; // Consent duration in days

  ConsentRequest({
    required this.id,
    required this.requestId,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.patientId,
    required this.patientName,
    required this.requestType,
    required this.purpose,
    required this.requestDate,
    required this.status,
    this.responseDate,
    this.expiryDate,
    this.patientResponse,
    this.specificRecordIds,
    required this.appointmentId,
    this.durationDays = 30, // Default 30 days
  });

  factory ConsentRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConsentRequest(
      id: doc.id,
      requestId: data['requestId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      doctorSpecialty: data['doctorSpecialty'] ?? '',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      requestType: data['requestType'] ?? '',
      purpose: data['purpose'] ?? '',
      requestDate: (data['requestDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      responseDate: data['responseDate'] != null
          ? (data['responseDate'] as Timestamp).toDate()
          : null,
      expiryDate: data['expiryDate'] != null
          ? (data['expiryDate'] as Timestamp).toDate()
          : null,
      patientResponse: data['patientResponse'],
      specificRecordIds: data['specificRecordIds'] != null
          ? List<String>.from(data['specificRecordIds'])
          : null,
      appointmentId: data['appointmentId'] ?? '',
      durationDays: data['durationDays'] ?? 30,
    );
  }

  String get requestTypeDisplayName {
    switch (requestType) {
      case 'lab_reports':
        return 'Lab Reports';
      case 'prescriptions':
        return 'Prescriptions';
      case 'full_history':
        return 'Full Medical History';
      default:
        return requestType;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'denied':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'patientId': patientId,
      'patientName': patientName,
      'requestType': requestType,
      'purpose': purpose,
      'requestDate': Timestamp.fromDate(requestDate),
      'status': status,
      'responseDate': responseDate != null
          ? Timestamp.fromDate(responseDate!)
          : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'patientResponse': patientResponse,
      'specificRecordIds': specificRecordIds,
      'appointmentId': appointmentId,
      'durationDays': durationDays,
    };
  }
}

// Friend Request Model
class FriendRequest {
  final String id;
  final String senderId;
  final String senderName;
  final String senderType;
  final String receiverId;
  final String receiverName;
  final String receiverType;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;
  final DateTime? respondedAt;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.receiverId,
    required this.receiverName,
    required this.receiverType,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderType: data['senderType'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      receiverType: data['receiverType'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': this.senderId,
      'senderName': this.senderName,
      'senderType': this.senderType,
      'receiverId': this.receiverId,
      'receiverName': this.receiverName,
      'receiverType': this.receiverType,
      'status': this.status,
      'createdAt': Timestamp.fromDate(this.createdAt),
      'respondedAt': this.respondedAt != null
          ? Timestamp.fromDate(this.respondedAt!)
          : null,
    };
  }
}

// Medical Record Access Audit Model
class MedicalRecordAccess {
  final String id;
  final String doctorId;
  final String doctorName;
  final String patientId;
  final String patientName;
  final String recordType; // 'lab_report', 'prescription', 'appointment'
  final String recordId;
  final DateTime accessTime;
  final String consentRequestId;
  final String purpose;
  final String ipAddress;
  final Map<String, dynamic>? metadata;

  MedicalRecordAccess({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
    required this.patientName,
    required this.recordType,
    required this.recordId,
    required this.accessTime,
    required this.consentRequestId,
    required this.purpose,
    required this.ipAddress,
    this.metadata,
  });

  factory MedicalRecordAccess.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicalRecordAccess(
      id: doc.id,
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      recordType: data['recordType'] ?? '',
      recordId: data['recordId'] ?? '',
      accessTime: (data['accessTime'] as Timestamp).toDate(),
      consentRequestId: data['consentRequestId'] ?? '',
      purpose: data['purpose'] ?? '',
      ipAddress: data['ipAddress'] ?? '',
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'doctorId': this.doctorId,
      'doctorName': this.doctorName,
      'patientId': this.patientId,
      'patientName': this.patientName,
      'recordType': this.recordType,
      'recordId': this.recordId,
      'accessTime': Timestamp.fromDate(this.accessTime),
      'consentRequestId': this.consentRequestId,
      'purpose': this.purpose,
      'ipAddress': this.ipAddress,
      'metadata': this.metadata,
    };
  }
}

// Friend Model
class Friend {
  final String id;
  final String userId;
  final String friendId;
  final String friendName;
  final String friendType;
  final DateTime addedAt;

  Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendName,
    required this.friendType,
    required this.addedAt,
  });

  factory Friend.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Friend(
      id: doc.id,
      userId: data['userId'] ?? '',
      friendId: data['friendId'] ?? '',
      friendName: data['friendName'] ?? '',
      friendType: data['friendType'] ?? '',
      addedAt: (data['addedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'friendId': friendId,
      'friendName': friendName,
      'friendType': friendType,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}

// Patient Consent Settings Model
class PatientConsentSettings {
  final String id;
  final String patientId;
  final bool autoApproveLabReports;
  final bool autoApprovePrescriptions;
  final bool allowEmergencyAccess;
  final int defaultConsentDuration; // in days
  final List<String> trustedDoctors;
  final List<String> blockedDoctors;
  final DateTime lastUpdated;

  PatientConsentSettings({
    required this.id,
    required this.patientId,
    this.autoApproveLabReports = false,
    this.autoApprovePrescriptions = false,
    this.allowEmergencyAccess = true,
    this.defaultConsentDuration = 30,
    this.trustedDoctors = const [],
    this.blockedDoctors = const [],
    required this.lastUpdated,
  });

  factory PatientConsentSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PatientConsentSettings(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      autoApproveLabReports: data['autoApproveLabReports'] ?? false,
      autoApprovePrescriptions: data['autoApprovePrescriptions'] ?? false,
      allowEmergencyAccess: data['allowEmergencyAccess'] ?? true,
      defaultConsentDuration: data['defaultConsentDuration'] ?? 30,
      trustedDoctors: List<String>.from(data['trustedDoctors'] ?? []),
      blockedDoctors: List<String>.from(data['blockedDoctors'] ?? []),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': this.patientId,
      'autoApproveLabReports': this.autoApproveLabReports,
      'autoApprovePrescriptions': this.autoApprovePrescriptions,
      'allowEmergencyAccess': this.allowEmergencyAccess,
      'defaultConsentDuration': this.defaultConsentDuration,
      'trustedDoctors': this.trustedDoctors,
      'blockedDoctors': this.blockedDoctors,
      'lastUpdated': Timestamp.fromDate(this.lastUpdated),
    };
  }
}

// Lab Referral Model
class LabReferral {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String labId;
  final String labName;
  final String appointmentId;
  final List<String> testTypes;
  final String status; // 'pending', 'accepted', 'completed', 'cancelled'
  final String? notes;
  final DateTime createdAt;
  final DateTime? completedAt;

  LabReferral({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.labId,
    required this.labName,
    required this.appointmentId,
    required this.testTypes,
    required this.status,
    this.notes,
    required this.createdAt,
    this.completedAt,
  });

  factory LabReferral.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LabReferral(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      labId: data['labId'] ?? '',
      labName: data['labName'] ?? '',
      appointmentId: data['appointmentId'] ?? '',
      testTypes: List<String>.from(data['testTypes'] ?? []),
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'labId': labId,
      'labName': labName,
      'appointmentId': appointmentId,
      'testTypes': testTypes,
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }
}

// Medical Record Permission Model for Doctor Access
class MedicalRecordPermission {
  final String id;
  final String patientId;
  final String doctorId;
  final String appointmentId;
  final bool canViewRecords;
  final bool canViewAnalysis;
  final bool canWritePrescriptions;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final String? grantedBy; // patient id or system
  final bool isActive;

  MedicalRecordPermission({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.appointmentId,
    required this.canViewRecords,
    required this.canViewAnalysis,
    required this.canWritePrescriptions,
    required this.grantedAt,
    this.expiresAt,
    this.grantedBy,
    this.isActive = true,
  });

  factory MedicalRecordPermission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicalRecordPermission(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      appointmentId: data['appointmentId'] ?? '',
      canViewRecords: data['canViewRecords'] ?? false,
      canViewAnalysis: data['canViewAnalysis'] ?? false,
      canWritePrescriptions: data['canWritePrescriptions'] ?? false,
      grantedAt: (data['grantedAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      grantedBy: data['grantedBy'],
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'appointmentId': appointmentId,
      'canViewRecords': canViewRecords,
      'canViewAnalysis': canViewAnalysis,
      'canWritePrescriptions': canWritePrescriptions,
      'grantedAt': Timestamp.fromDate(grantedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'grantedBy': grantedBy,
      'isActive': isActive,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isValidForUse {
    return isActive && !isExpired;
  }
}
