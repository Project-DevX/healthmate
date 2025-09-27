// TEMPORARY FIX - Essential classes to resolve compilation errors
// This file contains fixed versions of the classes that are causing compilation errors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ConsentRequest class (fixed)
class ConsentRequestFixed {
  final String id;
  final String requestId;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String patientId;
  final String patientName;
  final String requestType;
  final String purpose;
  final DateTime requestDate;
  final String status;
  final DateTime? responseDate;
  final DateTime? expiryDate;
  final String? patientResponse;
  final List<String>? specificRecordIds;
  final String appointmentId;
  final int durationDays;

  ConsentRequestFixed({
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
    this.durationDays = 30,
  });

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
}

// FriendRequest class (fixed)
class FriendRequestFixed {
  final String id;
  final String senderId;
  final String senderName;
  final String senderType;
  final String receiverId;
  final String receiverName;
  final String receiverType;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  FriendRequestFixed({
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
}

// Friend class (fixed)
class FriendFixed {
  final String id;
  final String userId;
  final String friendId;
  final String friendName;
  final String friendType;
  final DateTime addedAt;

  FriendFixed({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendName,
    required this.friendType,
    required this.addedAt,
  });
}

// MedicalRecordAccess class (fixed)
class MedicalRecordAccessFixed {
  final String id;
  final String doctorId;
  final String doctorName;
  final String patientId;
  final String patientName;
  final String recordType;
  final String recordId;
  final DateTime accessTime;
  final String consentRequestId;
  final String purpose;
  final String ipAddress;
  final Map<String, dynamic>? metadata;

  MedicalRecordAccessFixed({
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
}

// MedicalRecordPermission class (fixed)
class MedicalRecordPermissionFixed {
  final String id;
  final String patientId;
  final String doctorId;
  final String appointmentId;
  final bool canViewRecords;
  final bool canViewAnalysis;
  final bool canWritePrescriptions;

  MedicalRecordPermissionFixed({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.appointmentId,
    required this.canViewRecords,
    required this.canViewAnalysis,
    required this.canWritePrescriptions,
  });
}

// PatientConsentSettings class (fixed)
class PatientConsentSettingsFixed {
  final String id;
  final String patientId;
  final bool autoApproveLabReports;
  final bool autoApprovePrescriptions;
  final bool allowEmergencyAccess;
  final int defaultConsentDuration;
  final List<String> trustedDoctors;
  final List<String> blockedDoctors;
  final DateTime lastUpdated;

  PatientConsentSettingsFixed({
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

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'autoApproveLabReports': autoApproveLabReports,
      'autoApprovePrescriptions': autoApprovePrescriptions,
      'allowEmergencyAccess': allowEmergencyAccess,
      'defaultConsentDuration': defaultConsentDuration,
      'trustedDoctors': trustedDoctors,
      'blockedDoctors': blockedDoctors,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}
