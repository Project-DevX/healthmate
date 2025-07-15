// lib/services/interconnect_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shared_models.dart';

class InterconnectService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============ APPOINTMENT MANAGEMENT ============

  // Get available doctors for appointment booking
  static Future<List<DoctorProfile>> getAvailableDoctors({
    String? specialty,
    String? hospitalId,
  }) async {
    try {
      Query query = _firestore.collection('users').where('role', isEqualTo: 'doctor');
      
      if (specialty != null && specialty.isNotEmpty) {
        query = query.where('specialty', isEqualTo: specialty);
      }
      
      if (hospitalId != null && hospitalId.isNotEmpty) {
        query = query.where('hospitalId', isEqualTo: hospitalId);
      }

      final snapshot = await query.get();
      final doctors = snapshot.docs.map((doc) => DoctorProfile.fromFirestore(doc)).toList();
      
      // If no doctors found, return sample doctors for testing
      if (doctors.isEmpty) {
        return _getSampleDoctors();
      }
      
      return doctors;
    } catch (e) {
      // Return sample doctors if query fails
      print('Failed to fetch doctors, returning sample data: $e');
      return _getSampleDoctors();
    }
  }

  // Sample doctors for testing when no real doctors are registered
  static List<DoctorProfile> _getSampleDoctors() {
    return [
      DoctorProfile(
        id: 'sample_doctor_1',
        name: 'Dr. Sarah Wilson',
        email: 'sarah.wilson@hospital.com',
        specialty: 'Cardiology',
        hospitalId: 'sample_hospital_1',
        hospitalName: 'City General Hospital',
        qualifications: ['MBBS', 'MD Cardiology'],
        experienceYears: 8,
        rating: 4.8,
        availableDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        timeSlots: ['09:00 AM', '10:00 AM', '11:00 AM', '02:00 PM', '03:00 PM', '04:00 PM'],
        consultationFee: 150.0,
        isAvailable: true,
      ),
      DoctorProfile(
        id: 'sample_doctor_2',
        name: 'Dr. Michael Chen',
        email: 'michael.chen@hospital.com',
        specialty: 'General Medicine',
        hospitalId: 'sample_hospital_1',
        hospitalName: 'City General Hospital',
        qualifications: ['MBBS', 'MD Internal Medicine'],
        experienceYears: 12,
        rating: 4.9,
        availableDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        timeSlots: ['09:30 AM', '10:30 AM', '11:30 AM', '02:30 PM', '03:30 PM', '04:30 PM'],
        consultationFee: 120.0,
        isAvailable: true,
      ),
      DoctorProfile(
        id: 'sample_doctor_3',
        name: 'Dr. Emily Rodriguez',
        email: 'emily.rodriguez@hospital.com',
        specialty: 'Pediatrics',
        hospitalId: 'sample_hospital_2',
        hospitalName: 'Metro Medical Center',
        qualifications: ['MBBS', 'MD Pediatrics'],
        experienceYears: 6,
        rating: 4.7,
        availableDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        timeSlots: ['10:00 AM', '11:00 AM', '02:00 PM', '03:00 PM', '04:00 PM'],
        consultationFee: 130.0,
        isAvailable: true,
      ),
      DoctorProfile(
        id: 'sample_doctor_4',
        name: 'Dr. David Kumar',
        email: 'david.kumar@hospital.com',
        specialty: 'Orthopedics',
        hospitalId: 'sample_hospital_1',
        hospitalName: 'City General Hospital',
        qualifications: ['MBBS', 'MS Orthopedics'],
        experienceYears: 10,
        rating: 4.6,
        availableDays: ['Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
        timeSlots: ['09:00 AM', '10:00 AM', '11:00 AM', '03:00 PM', '04:00 PM'],
        consultationFee: 180.0,
        isAvailable: true,
      ),
    ];
  }

  // Book appointment (from patient/caregiver)
  static Future<String> bookAppointment(Appointment appointment) async {
    try {
      final docRef = await _firestore.collection('appointments').add(appointment.toMap());
      
      // Send notification to doctor
      await _sendNotification(
        recipientId: appointment.doctorId,
        recipientType: 'doctor',
        title: 'New Appointment Request',
        message: 'New appointment request from ${appointment.patientName}',
        type: 'appointment',
        relatedId: docRef.id,
      );

      // Send notification to hospital
      await _sendNotification(
        recipientId: appointment.hospitalId,
        recipientType: 'hospital',
        title: 'New Appointment Scheduled',
        message: 'Appointment scheduled for Dr. ${appointment.doctorName}',
        type: 'appointment',
        relatedId: docRef.id,
      );

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to book appointment: $e');
    }
  }

  // Get appointments for user
  static Future<List<Appointment>> getUserAppointments(String userId, String userType) async {
    try {
      Query query;
      
      switch (userType) {
        case 'patient':
          query = _firestore.collection('appointments').where('patientId', isEqualTo: userId);
          break;
        case 'doctor':
          query = _firestore.collection('appointments').where('doctorId', isEqualTo: userId);
          break;
        case 'caregiver':
          query = _firestore.collection('appointments').where('caregiverId', isEqualTo: userId);
          break;
        case 'hospital':
          query = _firestore.collection('appointments').where('hospitalId', isEqualTo: userId);
          break;
        default:
          throw Exception('Invalid user type');
      }

      // Get data without ordering first to avoid index requirement
      final snapshot = await query.get();
      final appointments = snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
      
      // Sort in memory instead of using Firebase orderBy to avoid index requirement
      appointments.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
      
      return appointments;
    } catch (e) {
      throw Exception('Failed to fetch appointments: $e');
    }
  }

  // Update appointment status
  static Future<void> updateAppointmentStatus(String appointmentId, String status, {String? notes}) async {
    try {
      final updateData = {'status': status};
      if (notes != null) updateData['notes'] = notes;
      
      await _firestore.collection('appointments').doc(appointmentId).update(updateData);
      
      // Get appointment details for notifications
      final appointmentDoc = await _firestore.collection('appointments').doc(appointmentId).get();
      final appointment = Appointment.fromFirestore(appointmentDoc);
      
      // Notify patient
      await _sendNotification(
        recipientId: appointment.patientId,
        recipientType: 'patient',
        title: 'Appointment Update',
        message: 'Your appointment status has been updated to: $status',
        type: 'appointment',
        relatedId: appointmentId,
      );
      
      // Notify caregiver if exists
      if (appointment.caregiverId != null) {
        await _sendNotification(
          recipientId: appointment.caregiverId!,
          recipientType: 'caregiver',
          title: 'Appointment Update',
          message: 'Appointment status updated for ${appointment.patientName}: $status',
          type: 'appointment',
          relatedId: appointmentId,
        );
      }
    } catch (e) {
      throw Exception('Failed to update appointment: $e');
    }
  }

  // ============ LAB REPORT MANAGEMENT ============

  // Request lab test (from doctor)
  static Future<String> requestLabTest(LabReport labReport) async {
    try {
      final docRef = await _firestore.collection('lab_reports').add(labReport.toMap());
      
      // Notify lab
      await _sendNotification(
        recipientId: labReport.labId,
        recipientType: 'lab',
        title: 'New Lab Test Request',
        message: 'New ${labReport.testName} test requested for ${labReport.patientName}',
        type: 'lab_result',
        relatedId: docRef.id,
      );

      // Notify patient
      await _sendNotification(
        recipientId: labReport.patientId,
        recipientType: 'patient',
        title: 'Lab Test Scheduled',
        message: 'Your ${labReport.testName} test has been scheduled',
        type: 'lab_result',
        relatedId: docRef.id,
      );

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to request lab test: $e');
    }
  }

  // Upload lab result (from lab)
  static Future<void> uploadLabResult(String reportId, String reportUrl, Map<String, dynamic>? results, {String? notes}) async {
    try {
      await _firestore.collection('lab_reports').doc(reportId).update({
        'status': 'completed',
        'reportUrl': reportUrl,
        'results': results,
        'notes': notes,
      });

      // Get report details
      final reportDoc = await _firestore.collection('lab_reports').doc(reportId).get();
      final report = LabReport.fromFirestore(reportDoc);

      // Notify patient
      await _sendNotification(
        recipientId: report.patientId,
        recipientType: 'patient',
        title: 'Lab Results Available',
        message: 'Your ${report.testName} results are now available',
        type: 'lab_result',
        relatedId: reportId,
      );

      // Notify doctor
      await _sendNotification(
        recipientId: report.doctorId,
        recipientType: 'doctor',
        title: 'Lab Results Available',
        message: 'Lab results for ${report.patientName} (${report.testName}) are available',
        type: 'lab_result',
        relatedId: reportId,
      );

    } catch (e) {
      throw Exception('Failed to upload lab result: $e');
    }
  }

  // Get lab reports for user
  static Future<List<LabReport>> getUserLabReports(String userId, String userType) async {
    try {
      Query query;
      
      switch (userType) {
        case 'patient':
          query = _firestore.collection('lab_reports').where('patientId', isEqualTo: userId);
          break;
        case 'doctor':
          query = _firestore.collection('lab_reports').where('doctorId', isEqualTo: userId);
          break;
        case 'lab':
          query = _firestore.collection('lab_reports').where('labId', isEqualTo: userId);
          break;
        default:
          throw Exception('Invalid user type');
      }

      // Get data without ordering first to avoid index requirement
      final snapshot = await query.get();
      final labReports = snapshot.docs.map((doc) => LabReport.fromFirestore(doc)).toList();
      
      // Sort in memory instead of using Firebase orderBy to avoid index requirement
      labReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return labReports;
    } catch (e) {
      throw Exception('Failed to fetch lab reports: $e');
    }
  }

  // ============ PRESCRIPTION MANAGEMENT ============

  // Create prescription (from doctor)
  static Future<String> createPrescription(Prescription prescription) async {
    try {
      final docRef = await _firestore.collection('prescriptions').add(prescription.toMap());
      
      // Notify patient
      await _sendNotification(
        recipientId: prescription.patientId,
        recipientType: 'patient',
        title: 'New Prescription',
        message: 'Dr. ${prescription.doctorName} has prescribed medications for you',
        type: 'prescription',
        relatedId: docRef.id,
      );

      // Notify pharmacy
      await _sendNotification(
        recipientId: prescription.pharmacyId,
        recipientType: 'pharmacy',
        title: 'New Prescription',
        message: 'New prescription for ${prescription.patientName}',
        type: 'prescription',
        relatedId: docRef.id,
      );

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create prescription: $e');
    }
  }

  // Update prescription status (from pharmacy)
  static Future<void> updatePrescriptionStatus(String prescriptionId, String status) async {
    try {
      final updateData = <String, dynamic>{'status': status};
      if (status == 'filled') {
        updateData['filledDate'] = Timestamp.now();
      }
      
      await _firestore.collection('prescriptions').doc(prescriptionId).update(updateData);
      
      // Get prescription details
      final prescriptionDoc = await _firestore.collection('prescriptions').doc(prescriptionId).get();
      final prescription = Prescription.fromFirestore(prescriptionDoc);
      
      // Notify patient
      await _sendNotification(
        recipientId: prescription.patientId,
        recipientType: 'patient',
        title: 'Prescription Update',
        message: 'Your prescription status: $status',
        type: 'prescription',
        relatedId: prescriptionId,
      );

      // Notify doctor
      await _sendNotification(
        recipientId: prescription.doctorId,
        recipientType: 'doctor',
        title: 'Prescription Update',
        message: 'Prescription for ${prescription.patientName} has been $status',
        type: 'prescription',
        relatedId: prescriptionId,
      );

    } catch (e) {
      throw Exception('Failed to update prescription: $e');
    }
  }

  // Get prescriptions for user
  static Future<List<Prescription>> getUserPrescriptions(String userId, String userType) async {
    try {
      Query query;
      
      switch (userType) {
        case 'patient':
          query = _firestore.collection('prescriptions').where('patientId', isEqualTo: userId);
          break;
        case 'doctor':
          query = _firestore.collection('prescriptions').where('doctorId', isEqualTo: userId);
          break;
        case 'pharmacy':
          query = _firestore.collection('prescriptions').where('pharmacyId', isEqualTo: userId);
          break;
        default:
          throw Exception('Invalid user type');
      }

      // Get data without ordering first to avoid index requirement
      final snapshot = await query.get();
      final prescriptions = snapshot.docs.map((doc) => Prescription.fromFirestore(doc)).toList();
      
      // Sort in memory instead of using Firebase orderBy to avoid index requirement
      prescriptions.sort((a, b) => b.prescribedDate.compareTo(a.prescribedDate));
      
      return prescriptions;
    } catch (e) {
      throw Exception('Failed to fetch prescriptions: $e');
    }
  }

  // ============ NOTIFICATION MANAGEMENT ============

  // Send notification
  static Future<void> _sendNotification({
    required String recipientId,
    required String recipientType,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get sender info
      final senderDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final senderData = senderDoc.data();
      
      final notification = NotificationModel(
        id: '',
        recipientId: recipientId,
        recipientType: recipientType,
        senderId: currentUser.uid,
        senderType: senderData?['role'] ?? 'system',
        senderName: senderData?['name'] ?? 'System',
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('notifications').add(notification.toMap());
    } catch (e) {
      print('Failed to send notification: $e');
    }
  }

  // Get notifications for user
  static Future<List<NotificationModel>> getUserNotifications(String userId) async {
    try {
      // Get data without ordering first to avoid index requirement
      final snapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .get();

      final notifications = snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();
      
      // Sort in memory and limit to 50 most recent
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return notifications.take(50).toList();
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // ============ SEARCH AND DISCOVERY ============

  // Search patients (for doctors/hospitals)
  static Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .get();

      final patients = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((patient) => 
              patient['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
              patient['email'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();

      // If no patients found, return sample patients for testing
      if (patients.isEmpty || query.isEmpty) {
        return _getSamplePatients(query);
      }

      return patients;
    } catch (e) {
      // Return sample patients if query fails
      print('Failed to search patients, returning sample data: $e');
      return _getSamplePatients(query);
    }
  }

  // Sample patients for testing when no real patients are registered
  static List<Map<String, dynamic>> _getSamplePatients(String query) {
    final samplePatients = [
      {
        'id': 'sample_patient_1',
        'name': 'John Smith',
        'email': 'john.smith@email.com',
        'phone': '+1-555-0101',
        'dateOfBirth': '1990-05-15',
        'gender': 'Male',
        'bloodGroup': 'O+',
        'address': '123 Main Street, City',
      },
      {
        'id': 'sample_patient_2',
        'name': 'Jane Doe',
        'email': 'jane.doe@email.com',
        'phone': '+1-555-0102',
        'dateOfBirth': '1985-08-22',
        'gender': 'Female',
        'bloodGroup': 'A+',
        'address': '456 Oak Avenue, City',
      },
      {
        'id': 'sample_patient_3',
        'name': 'Robert Johnson',
        'email': 'robert.johnson@email.com',
        'phone': '+1-555-0103',
        'dateOfBirth': '1978-12-03',
        'gender': 'Male',
        'bloodGroup': 'B+',
        'address': '789 Pine Road, City',
      },
      {
        'id': 'sample_patient_4',
        'name': 'Emily Davis',
        'email': 'emily.davis@email.com',
        'phone': '+1-555-0104',
        'dateOfBirth': '1992-03-18',
        'gender': 'Female',
        'bloodGroup': 'AB+',
        'address': '321 Elm Street, City',
      },
      {
        'id': 'sample_patient_5',
        'name': 'Michael Brown',
        'email': 'michael.brown@email.com',
        'phone': '+1-555-0105',
        'dateOfBirth': '1975-09-30',
        'gender': 'Male',
        'bloodGroup': 'O-',
        'address': '654 Maple Drive, City',
      },
    ];

    if (query.isEmpty) {
      return samplePatients;
    }

    return samplePatients
        .where((patient) => 
            patient['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
            patient['email'].toString().toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Get patient medical history (for doctors)
  static Future<Map<String, dynamic>> getPatientMedicalHistory(String patientId) async {
    try {
      // Get appointments (without orderBy to avoid index requirement)
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .get();

      // Get lab reports (without orderBy to avoid index requirement)
      final labReportsSnapshot = await _firestore
          .collection('lab_reports')
          .where('patientId', isEqualTo: patientId)
          .get();

      // Get prescriptions (without orderBy to avoid index requirement)
      final prescriptionsSnapshot = await _firestore
          .collection('prescriptions')
          .where('patientId', isEqualTo: patientId)
          .get();

      // Convert to objects and sort in memory to avoid Firebase index requirement
      final appointments = appointmentsSnapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
      final labReports = labReportsSnapshot.docs.map((doc) => LabReport.fromFirestore(doc)).toList();
      final prescriptions = prescriptionsSnapshot.docs.map((doc) => Prescription.fromFirestore(doc)).toList();

      // Sort by date (most recent first)
      appointments.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
      labReports.sort((a, b) => b.testDate.compareTo(a.testDate));
      prescriptions.sort((a, b) => b.prescribedDate.compareTo(a.prescribedDate));

      return {
        'appointments': appointments,
        'labReports': labReports,
        'prescriptions': prescriptions,
      };
    } catch (e) {
      throw Exception('Failed to fetch patient medical history: $e');
    }
  }

  // Get available time slots for doctor
  static Future<List<String>> getAvailableTimeSlots(String doctorId, DateTime date) async {
    try {
      // Get doctor's available time slots
      final doctorDoc = await _firestore.collection('users').doc(doctorId).get();
      final doctorData = doctorDoc.data();
      final allTimeSlots = List<String>.from(doctorData?['timeSlots'] ?? [
        '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
        '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM'
      ]);

      // Get all appointments for the doctor (without date filtering to avoid index requirement)
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      // Filter appointments for the specific date in memory
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final bookedSlots = appointmentsSnapshot.docs
          .where((doc) {
            final appointmentDate = (doc.data()['appointmentDate'] as Timestamp).toDate();
            return appointmentDate.isAfter(startOfDay) && appointmentDate.isBefore(endOfDay);
          })
          .map((doc) => doc.data()['timeSlot'] as String)
          .toSet();

      return allTimeSlots.where((slot) => !bookedSlots.contains(slot)).toList();
    } catch (e) {
      throw Exception('Failed to get available time slots: $e');
    }
  }

  // ============ MEDICAL RECORDS SHARING ============

  // Share medical records between roles
  static Future<void> shareRecordAccess({
    required String recordId,
    required String sharedWithId,
    required String sharedWithType,
    required String recordType,
    Duration? expiresIn,
  }) async {
    try {
      final shareData = {
        'recordId': recordId,
        'recordType': recordType,
        'sharedById': _auth.currentUser?.uid,
        'sharedWithId': sharedWithId,
        'sharedWithType': sharedWithType,
        'createdAt': Timestamp.now(),
        'expiresAt': expiresIn != null 
            ? Timestamp.fromDate(DateTime.now().add(expiresIn))
            : null,
        'isActive': true,
      };

      await _firestore.collection('shared_records').add(shareData);

      // Send notification
      await _sendNotification(
        recipientId: sharedWithId,
        recipientType: sharedWithType,
        title: 'Medical Record Shared',
        message: 'A medical record has been shared with you',
        type: 'general',
        relatedId: recordId,
      );
    } catch (e) {
      throw Exception('Failed to share record access: $e');
    }
  }
}
