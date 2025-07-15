// lib/models/shared_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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
      prescribedDate: (data['prescribedDate'] as Timestamp).toDate(),
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
  final int duration;
  final String instructions;

  PrescriptionMedicine({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instructions,
  });

  factory PrescriptionMedicine.fromMap(Map<String, dynamic> map) {
    return PrescriptionMedicine(
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      duration: map['duration'] ?? 0,
      instructions: map['instructions'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
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
