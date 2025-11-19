// lib/services/interconnect_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shared_models.dart';
import 'consent_service.dart';

class InterconnectService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============ APPOINTMENT MANAGEMENT ============

  // Get available doctors for appointments
  static Future<List<DoctorProfile>> getAvailableDoctors() async {
    try {
      print('🔍 INTERCONNECT: Fetching real doctors from Firestore...');

      // Fetch real doctors from the users collection
      final doctorsSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'doctor')
          .where('isAvailable', isEqualTo: true)
          .get();

      print(
        '🔍 INTERCONNECT: Found ${doctorsSnapshot.docs.length} available doctors',
      );

      final doctors = <DoctorProfile>[];

      for (var doc in doctorsSnapshot.docs) {
        final data = doc.data();
        final doctorId = doc.id;

        print(
          '🔍 INTERCONNECT: Processing doctor: ${data['fullName']} (ID: $doctorId)',
        );

        // Create DoctorProfile from real doctor data
        final doctor = DoctorProfile(
          id: doctorId, // Use the actual Firebase document ID
          name: data['fullName'] ?? 'Unknown Doctor',
          email: data['email'] ?? '',
          specialty: data['specialization'] ?? 'General Practice',
          hospitalId: data['affiliation'] ?? 'general-hospital',
          hospitalName: data['affiliation'] ?? 'General Hospital',
          qualifications: data['qualifications'] != null
              ? List<String>.from(data['qualifications'])
              : ['MBBS'],
          experienceYears: data['experienceYears'] ?? 5,
          rating: data['rating']?.toDouble() ?? 4.5,
          availableDays: data['availableDays'] != null
              ? List<String>.from(data['availableDays'])
              : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
          timeSlots: data['timeSlots'] != null
              ? List<String>.from(data['timeSlots'])
              : ['09:00 AM', '10:00 AM', '11:00 AM', '02:00 PM', '03:00 PM'],
          consultationFee: data['consultationFee']?.toDouble() ?? 100.0,
          isAvailable: data['isAvailable'] ?? true,
        );

        doctors.add(doctor);
        print(
          '✅ INTERCONNECT: Added doctor: ${doctor.name} (${doctor.specialty})',
        );
      }

      if (doctors.isEmpty) {
        print(
          '⚠️ INTERCONNECT: No real doctors found, using fallback sample data',
        );
        // If no real doctors found, return one sample doctor with the real doctor's ID
        return [
          DoctorProfile(
            id: '8FLajrsoGGP1nKaxIT8t7nkX5fU2', // Use the real doctor ID
            name: 'Dr. Sarah Wilson',
            email: 'dr.sarah.wilson@gmail.com',
            specialty: 'Cardiology',
            hospitalId: 'city-general-hospital',
            hospitalName: 'City General Hospital',
            qualifications: ['MBBS', 'MD Cardiology'],
            experienceYears: 8,
            rating: 4.8,
            availableDays: [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
            ],
            timeSlots: [
              '09:00 AM',
              '10:00 AM',
              '11:00 AM',
              '02:00 PM',
              '03:00 PM',
              '04:00 PM',
            ],
            consultationFee: 150.0,
            isAvailable: true,
          ),
        ];
      }

      print('✅ INTERCONNECT: Returning ${doctors.length} available doctors');
      return doctors;
    } catch (e) {
      print('❌ INTERCONNECT: Error fetching doctors: $e');
      // Fallback to sample data with real doctor ID
      return [
        DoctorProfile(
          id: '8FLajrsoGGP1nKaxIT8t7nkX5fU2', // Use the real doctor ID
          name: 'Dr. Sarah Wilson',
          email: 'dr.sarah.wilson@gmail.com',
          specialty: 'Cardiology',
          hospitalId: 'city-general-hospital',
          hospitalName: 'City General Hospital',
          qualifications: ['MBBS', 'MD Cardiology'],
          experienceYears: 8,
          rating: 4.8,
          availableDays: [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
          ],
          timeSlots: [
            '09:00 AM',
            '10:00 AM',
            '11:00 AM',
            '02:00 PM',
            '03:00 PM',
            '04:00 PM',
          ],
          consultationFee: 150.0,
          isAvailable: true,
        ),
      ];
    }
  }

  // Sample doctors for testing when no real doctors are registered
  // Book appointment (from patient/caregiver)
  static Future<String> bookAppointment(Appointment appointment) async {
    try {
      // Create appointment with proper date handling
      final appointmentData = appointment.toMap();

      // Store appointmentDate as proper timestamp for the selected date and time
      final appointmentDateTime = _combineDateTime(
        appointment.appointmentDate,
        appointment.timeSlot,
      );
      appointmentData['appointmentDate'] = Timestamp.fromDate(
        appointmentDateTime,
      );

      final docRef = await _firestore
          .collection('appointments')
          .add(appointmentData);

      // Send notification to doctor
      await _sendNotification(
        recipientId: appointment.doctorId,
        recipientType: 'doctor',
        title: 'New Appointment Request',
        message:
            'New appointment request from ${appointment.patientName} for ${appointment.timeSlot} on ${_formatDate(appointment.appointmentDate)}',
        type: 'appointment',
        relatedId: docRef.id,
      );

      // Send notification to hospital
      await _sendNotification(
        recipientId: appointment.hospitalId,
        recipientType: 'hospital',
        title: 'New Appointment Scheduled',
        message:
            'Appointment scheduled for Dr. ${appointment.doctorName} with ${appointment.patientName}',
        type: 'appointment',
        relatedId: docRef.id,
      );

      // If caregiver is involved, notify them too
      if (appointment.caregiverId != null) {
        await _sendNotification(
          recipientId: appointment.caregiverId!,
          recipientType: 'caregiver',
          title: 'Appointment Booked',
          message:
              'Appointment booked for ${appointment.patientName} with Dr. ${appointment.doctorName}',
          type: 'appointment',
          relatedId: docRef.id,
        );
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to book appointment: $e');
    }
  }

  // Helper method to combine date and time slot
  static DateTime _combineDateTime(DateTime date, String timeSlot) {
    try {
      // Parse time slot (e.g., "09:30 AM" or "02:30 PM")
      final timeParts = timeSlot.split(' ');
      final time = timeParts[0].split(':');
      final hour = int.parse(time[0]);
      final minute = int.parse(time[1]);
      final isPM = timeParts[1].toUpperCase() == 'PM';

      int finalHour = hour;
      if (isPM && hour != 12) {
        finalHour = hour + 12;
      } else if (!isPM && hour == 12) {
        finalHour = 0;
      }

      return DateTime(date.year, date.month, date.day, finalHour, minute);
    } catch (e) {
      // Fallback to noon if parsing fails
      return DateTime(date.year, date.month, date.day, 12, 0);
    }
  }

  // Helper method to format date
  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Get appointments for user
  static Future<List<Appointment>> getUserAppointments(
    String userId,
    String userType,
  ) async {
    try {
      Query query;

      switch (userType) {
        case 'patient':
          query = _firestore
              .collection('appointments')
              .where('patientId', isEqualTo: userId);
          break;
        case 'doctor':
          query = _firestore
              .collection('appointments')
              .where('doctorId', isEqualTo: userId);
          break;
        case 'caregiver':
          query = _firestore
              .collection('appointments')
              .where('caregiverId', isEqualTo: userId);
          break;
        case 'hospital':
          query = _firestore
              .collection('appointments')
              .where('hospitalId', isEqualTo: userId);
          break;
        default:
          throw Exception('Invalid user type');
      }

      // Get data without ordering first to avoid index requirement
      final snapshot = await query.get();
      final appointments = snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .toList();

      // Sort in memory instead of using Firebase orderBy to avoid index requirement
      appointments.sort(
        (a, b) => b.appointmentDate.compareTo(a.appointmentDate),
      );

      return appointments;
    } catch (e) {
      throw Exception('Failed to fetch appointments: $e');
    }
  }

  // Update appointment status
  static Future<void> updateAppointmentStatus(
    String appointmentId,
    String status, {
    String? notes,
  }) async {
    try {
      final updateData = {'status': status};
      if (notes != null) updateData['notes'] = notes;

      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .update(updateData);

      // Get appointment details for notifications
      final appointmentDoc = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();
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
          message:
              'Appointment status updated for ${appointment.patientName}: $status',
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
      // Log the lab report data before creating
      final reportMap = labReport.toMap();
      print('🔬 INTERCONNECT: Creating lab test request...');
      print('🔬 INTERCONNECT: labId: ${labReport.labId}');
      print('🔬 INTERCONNECT: patientId: ${labReport.patientId}');
      print('🔬 INTERCONNECT: doctorId: ${labReport.doctorId}');
      print('🔬 INTERCONNECT: testName: ${labReport.testName}');
      print('🔬 INTERCONNECT: status: ${labReport.status}');
      print('🔬 INTERCONNECT: Full data map: $reportMap');

      // Verify labId is not empty
      if (labReport.labId.isEmpty) {
        throw Exception('labId cannot be empty when creating lab test request');
      }

      // Verify lab user exists
      final labUserDoc = await _firestore
          .collection('users')
          .doc(labReport.labId)
          .get();
      if (!labUserDoc.exists) {
        throw Exception(
          'Lab user not found with ID: ${labReport.labId}. Cannot create lab test request.',
        );
      }
      final labUserData = labUserDoc.data();
      final labUserType = labUserData?['userType'] ?? 'unknown';
      if (labUserType != 'lab') {
        print(
          '⚠️ INTERCONNECT: Warning - User ${labReport.labId} has userType "$labUserType", expected "lab"',
        );
      }
      print(
        '✅ INTERCONNECT: Verified lab user exists: ${labUserData?['institutionName'] ?? labUserData?['name'] ?? labReport.labId}',
      );

      final docRef = await _firestore.collection('lab_reports').add(reportMap);

      print('✅ INTERCONNECT: Lab test request created with ID: ${docRef.id}');
      print('✅ INTERCONNECT: Document path: lab_reports/${docRef.id}');

      // Verify the document was created correctly
      final createdDoc = await docRef.get();
      if (createdDoc.exists) {
        final createdData = createdDoc.data();
        print(
          '✅ INTERCONNECT: Verified created document - labId: ${createdData?['labId']}, status: ${createdData?['status']}',
        );
      } else {
        print('⚠️ INTERCONNECT: WARNING - Created document does not exist!');
      }

      // Notify lab
      await _sendNotification(
        recipientId: labReport.labId,
        recipientType: 'lab',
        title: 'New Lab Test Request',
        message:
            'New ${labReport.testName} test requested for ${labReport.patientName}',
        type: 'lab_result',
        relatedId: docRef.id,
      );
      print('✅ INTERCONNECT: Notification sent to lab: ${labReport.labId}');

      // Notify patient
      await _sendNotification(
        recipientId: labReport.patientId,
        recipientType: 'patient',
        title: 'Lab Test Scheduled',
        message: 'Your ${labReport.testName} test has been scheduled',
        type: 'lab_result',
        relatedId: docRef.id,
      );
      print(
        '✅ INTERCONNECT: Notification sent to patient: ${labReport.patientId}',
      );

      return docRef.id;
    } catch (e, stackTrace) {
      print('❌ INTERCONNECT: Failed to request lab test: $e');
      print('❌ INTERCONNECT: Stack trace: $stackTrace');
      throw Exception('Failed to request lab test: $e');
    }
  }

  // Upload lab result (from lab)
  static Future<void> uploadLabResult(
    String reportId,
    String reportUrl,
    Map<String, dynamic>? results, {
    String? notes,
  }) async {
    try {
      await _firestore.collection('lab_reports').doc(reportId).update({
        'status': 'completed',
        'reportUrl': reportUrl,
        'results': results,
        'notes': notes,
      });

      // Get report details
      final reportDoc = await _firestore
          .collection('lab_reports')
          .doc(reportId)
          .get();
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
        message:
            'Lab results for ${report.patientName} (${report.testName}) are available',
        type: 'lab_result',
        relatedId: reportId,
      );
    } catch (e) {
      throw Exception('Failed to upload lab result: $e');
    }
  }

  // Update lab report status (from lab) with notifications
  static Future<void> updateLabReportStatus(
    String reportId,
    String status, {
    String? notes,
  }) async {
    try {
      // Update the lab report status
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': Timestamp.now(),
      };
      if (notes != null) {
        updateData['notes'] = notes;
      }

      await _firestore
          .collection('lab_reports')
          .doc(reportId)
          .update(updateData);

      // Get report details for notifications
      final reportDoc = await _firestore
          .collection('lab_reports')
          .doc(reportId)
          .get();
      final report = LabReport.fromFirestore(reportDoc);

      // Determine notification messages based on status
      String patientTitle;
      String patientMessage;
      String doctorTitle;
      String doctorMessage;

      switch (status.toLowerCase()) {
        case 'in_progress':
          patientTitle = 'Lab Test Started';
          patientMessage =
              'Your ${report.testName} test is now being processed at ${report.labName}';
          doctorTitle = 'Lab Test Processing';
          doctorMessage =
              '${report.patientName}\'s ${report.testName} test is now being processed';
          break;
        case 'completed':
        case 'uploaded':
          patientTitle = 'Lab Test Completed';
          patientMessage =
              'Your ${report.testName} test has been completed at ${report.labName}';
          doctorTitle = 'Lab Test Completed';
          doctorMessage =
              '${report.patientName}\'s ${report.testName} test has been completed';
          break;
        default:
          patientTitle = 'Lab Test Status Update';
          patientMessage =
              'Your ${report.testName} test status has been updated to: ${status.replaceAll('_', ' ')}';
          doctorTitle = 'Lab Test Status Update';
          doctorMessage =
              '${report.patientName}\'s ${report.testName} test status updated to: ${status.replaceAll('_', ' ')}';
      }

      // Notify patient
      await _sendNotification(
        recipientId: report.patientId,
        recipientType: 'patient',
        title: patientTitle,
        message: patientMessage,
        type: 'lab_result',
        relatedId: reportId,
      );

      // Notify doctor (if doctor requested the test)
      if (report.doctorId.isNotEmpty) {
        await _sendNotification(
          recipientId: report.doctorId,
          recipientType: 'doctor',
          title: doctorTitle,
          message: doctorMessage,
          type: 'lab_result',
          relatedId: reportId,
        );
      }
    } catch (e) {
      throw Exception('Failed to update lab report status: $e');
    }
  }

  // Get lab reports for user
  static Future<List<LabReport>> getUserLabReports(
    String userId,
    String userType,
  ) async {
    try {
      Query query;

      switch (userType) {
        case 'patient':
          query = _firestore
              .collection('lab_reports')
              .where('patientId', isEqualTo: userId);
          break;
        case 'doctor':
          query = _firestore
              .collection('lab_reports')
              .where('doctorId', isEqualTo: userId);
          break;
        case 'lab':
          query = _firestore
              .collection('lab_reports')
              .where('labId', isEqualTo: userId);
          break;
        default:
          throw Exception('Invalid user type: $userType');
      }

      print('🔍 INTERCONNECT: Fetching lab reports for $userType: $userId');
      print('🔍 INTERCONNECT: Query collection: lab_reports');
      if (userType == 'lab') {
        print('🔍 INTERCONNECT: Query filter: labId == $userId');
      }

      // Get data without ordering first to avoid index requirement
      final snapshot = await query.get();
      print(
        '📊 INTERCONNECT: Found ${snapshot.docs.length} lab report documents',
      );

      // DIAGNOSTIC: Also check ALL lab_reports to see what's in the database
      if (userType == 'lab' && snapshot.docs.isEmpty) {
        print('⚠️ INTERCONNECT: No reports found for labId: $userId');
        print(
          '🔍 INTERCONNECT: Running diagnostic query - checking ALL lab_reports...',
        );
        try {
          final allReportsSnapshot = await _firestore
              .collection('lab_reports')
              .limit(10)
              .get();
          print(
            '📊 INTERCONNECT: DIAGNOSTIC - Total lab_reports in database: ${allReportsSnapshot.docs.length}',
          );
          for (final doc in allReportsSnapshot.docs) {
            final data = doc.data();
            final docLabId = data['labId']?.toString() ?? 'NULL';
            final docPatientId = data['patientId']?.toString() ?? 'NULL';
            final docStatus = data['status']?.toString() ?? 'NULL';
            final docTestName = data['testName']?.toString() ?? 'NULL';
            print(
              '📄 INTERCONNECT: DIAGNOSTIC - Report ${doc.id}: labId=$docLabId, patientId=$docPatientId, status=$docStatus, testName=$docTestName',
            );
            print(
              '   Looking for: labId=$userId (match: ${docLabId == userId})',
            );
          }
        } catch (e) {
          print('⚠️ INTERCONNECT: Diagnostic query failed: $e');
        }
      }

      final labReports = <LabReport>[];
      for (final doc in snapshot.docs) {
        try {
          final rawData = doc.data();
          if (rawData == null) {
            print('⚠️ INTERCONNECT: Document ${doc.id} has no data');
            continue;
          }

          // Validate that rawData is a Map
          if (rawData is! Map<String, dynamic>) {
            print(
              '⚠️ INTERCONNECT: Document ${doc.id} data is not a Map, type: ${rawData.runtimeType}',
            );
            print('⚠️ INTERCONNECT: Raw data: $rawData');
            continue;
          }

          // Log key fields for debugging
          final reportLabId = rawData['labId']?.toString() ?? 'NULL';
          final reportStatus = rawData['status']?.toString() ?? 'NULL';
          final reportTestName = rawData['testName']?.toString() ?? 'NULL';
          print(
            '📋 INTERCONNECT: Parsing report ${doc.id}: labId=$reportLabId, status=$reportStatus, testName=$reportTestName',
          );

          labReports.add(LabReport.fromFirestore(doc));
          print('✅ INTERCONNECT: Successfully parsed lab report ${doc.id}');
        } catch (e, stackTrace) {
          print(
            '⚠️ INTERCONNECT: Skipping lab report ${doc.id} due to parse error: $e',
          );
          print('⚠️ INTERCONNECT: Stack trace: $stackTrace');
        }
      }

      // Sort in memory instead of using Firebase orderBy to avoid index requirement
      labReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print(
        '✅ INTERCONNECT: Successfully loaded ${labReports.length} lab reports',
      );
      return labReports;
    } catch (e, stackTrace) {
      print('❌ INTERCONNECT: Failed to fetch lab reports: $e');
      print('❌ INTERCONNECT: Stack trace: $stackTrace');
      throw Exception('Failed to fetch lab reports: $e');
    }
  }

  // ============ PRESCRIPTION MANAGEMENT ============

  // Create prescription (from doctor)
  static Future<String> createPrescription(Prescription prescription) async {
    try {
      final docRef = await _firestore
          .collection('prescriptions')
          .add(prescription.toMap());

      // Notify patient
      await _sendNotification(
        recipientId: prescription.patientId,
        recipientType: 'patient',
        title: 'New Prescription',
        message:
            'Dr. ${prescription.doctorName} has prescribed medications for you',
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
  static Future<void> updatePrescriptionStatus(
    String prescriptionId,
    String status,
  ) async {
    try {
      final updateData = <String, dynamic>{'status': status};
      if (status == 'filled') {
        updateData['filledDate'] = Timestamp.now();
      }

      await _firestore
          .collection('prescriptions')
          .doc(prescriptionId)
          .update(updateData);

      // Get prescription details
      final prescriptionDoc = await _firestore
          .collection('prescriptions')
          .doc(prescriptionId)
          .get();
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
        message:
            'Prescription for ${prescription.patientName} has been $status',
        type: 'prescription',
        relatedId: prescriptionId,
      );
    } catch (e) {
      throw Exception('Failed to update prescription: $e');
    }
  }

  // Get prescriptions for user
  static Future<List<Prescription>> getUserPrescriptions(
    String userId,
    String userType,
  ) async {
    try {
      Query query;

      switch (userType) {
        case 'patient':
          print('🔍 INTERCONNECT: Querying prescriptions for patient: $userId');
          query = _firestore
              .collection('prescriptions')
              .where('patientId', isEqualTo: userId);
          break;
        case 'doctor':
          query = _firestore
              .collection('prescriptions')
              .where('doctorId', isEqualTo: userId);
          break;
        case 'pharmacy':
          query = _firestore
              .collection('prescriptions')
              .where('pharmacyId', isEqualTo: userId);
          break;
        default:
          throw Exception('Invalid user type');
      }

      // Get data without ordering first to avoid index requirement
      final snapshot = await query.get();
      print(
        '🔍 INTERCONNECT: Found ${snapshot.docs.length} prescription documents',
      );

      for (var doc in snapshot.docs.take(2)) {
        final data = doc.data() as Map<String, dynamic>;
        print('🔍 INTERCONNECT: Prescription doc ${doc.id}:');
        print('   - patientId: ${data['patientId']}');
        print('   - status: ${data['status']}');
        print('   - prescribedDate: ${data['prescribedDate']}');
        print('   - prescriptionDate: ${data['prescriptionDate']}');
        print(
          '   - medicines count: ${(data['medicines'] as List?)?.length ?? 0}',
        );
      }

      final prescriptions = <Prescription>[];
      for (var doc in snapshot.docs) {
        try {
          final prescription = Prescription.fromFirestore(doc);
          prescriptions.add(prescription);
        } catch (e) {
          print('❌ INTERCONNECT: Error parsing prescription ${doc.id}: $e');
          print('   Document data: ${doc.data()}');
        }
      }

      print(
        '🔍 INTERCONNECT: Successfully mapped ${prescriptions.length} prescription objects',
      );
      for (final prescription in prescriptions.take(3)) {
        print(
          '   - ID: ${prescription.id}, Doctor: ${prescription.doctorName}, Status: ${prescription.status}',
        );
      }

      // Sort in memory instead of using Firebase orderBy to avoid index requirement
      prescriptions.sort(
        (a, b) => b.prescribedDate.compareTo(a.prescribedDate),
      );

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
      final senderDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
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
  static Future<List<NotificationModel>> getUserNotifications(
    String userId,
  ) async {
    try {
      // Get data without ordering first to avoid index requirement
      final snapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .get();

      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();

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
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
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
          .where(
            (patient) =>
                patient['name'].toString().toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                patient['email'].toString().toLowerCase().contains(
                  query.toLowerCase(),
                ),
          )
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
        .where(
          (patient) =>
              patient['name'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              patient['email'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
  }

  // Get patient medical history (for doctors)
  static Future<Map<String, dynamic>> getPatientMedicalHistory(
    String patientId,
  ) async {
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
      final appointments = appointmentsSnapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .toList();
      final labReports = labReportsSnapshot.docs
          .map((doc) => LabReport.fromFirestore(doc))
          .toList();
      final prescriptions = prescriptionsSnapshot.docs
          .map((doc) => Prescription.fromFirestore(doc))
          .toList();

      // Sort by date (most recent first)
      appointments.sort(
        (a, b) => b.appointmentDate.compareTo(a.appointmentDate),
      );
      labReports.sort((a, b) => b.testDate.compareTo(a.testDate));
      prescriptions.sort(
        (a, b) => b.prescribedDate.compareTo(a.prescribedDate),
      );

      return {
        'appointments': appointments,
        'labReports': labReports,
        'prescriptions': prescriptions,
      };
    } catch (e) {
      throw Exception('Failed to fetch patient medical history: $e');
    }
  }

  // Enhanced patient medical history with consent check
  static Future<Map<String, dynamic>> getPatientMedicalHistoryWithConsent(
    String patientId,
    String requestingDoctorId,
    String consentRequestId,
    String purpose,
  ) async {
    try {
      // Use the ConsentService to get accessible records with proper consent verification
      return await ConsentService.getAccessiblePatientRecords(
        requestingDoctorId,
        patientId,
        consentRequestId,
        purpose,
      );
    } catch (e) {
      throw Exception(
        'Failed to fetch patient medical history with consent: $e',
      );
    }
  }

  // Get available time slots for doctor
  static Future<List<String>> getAvailableTimeSlots(
    String doctorId,
    DateTime date,
  ) async {
    try {
      // First check if doctor has availability settings
      final availabilityDoc = await _firestore
          .collection('doctorAvailability')
          .doc(doctorId)
          .get();

      List<String> allTimeSlots = [];

      if (availabilityDoc.exists) {
        final availabilityData = availabilityDoc.data()!;

        // Check if doctor is available on this day
        final dayName = _getDayName(date);
        final workingDays = Map<String, bool>.from(
          availabilityData['workingDays'] ?? {},
        );

        if (workingDays[dayName] != true ||
            availabilityData['isOnline'] != true) {
          return []; // Doctor not available on this day
        }

        // Use doctor's generated time slots
        allTimeSlots = List<String>.from(availabilityData['timeSlots'] ?? []);
      }

      // Fallback to default slots if no availability settings
      if (allTimeSlots.isEmpty) {
        final doctorDoc = await _firestore
            .collection('users')
            .doc(doctorId)
            .get();
        final doctorData = doctorDoc.data();
        allTimeSlots = List<String>.from(
          doctorData?['timeSlots'] ??
              [
                '09:00 AM',
                '09:30 AM',
                '10:00 AM',
                '10:30 AM',
                '11:00 AM',
                '11:30 AM',
                '02:00 PM',
                '02:30 PM',
                '03:00 PM',
                '03:30 PM',
                '04:00 PM',
                '04:30 PM',
              ],
        );
      }

      // Get all appointments for the doctor on the selected date
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      // Filter appointments for the specific date and extract booked time slots
      final bookedSlots = <String>{};
      for (final doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final appointmentDate = (data['appointmentDate'] as Timestamp).toDate();

        // Check if appointment is on the selected date and not cancelled
        if (appointmentDate.isAfter(startOfDay) &&
            appointmentDate.isBefore(endOfDay) &&
            data['status'] != 'cancelled') {
          final timeSlot = data['timeSlot'] as String?;
          if (timeSlot != null) {
            bookedSlots.add(timeSlot);
          }
        }
      }

      // Return only available (not booked) time slots
      return allTimeSlots.where((slot) => !bookedSlots.contains(slot)).toList();
    } catch (e) {
      print('Error getting available time slots: $e');
      // Return basic time slots as fallback
      return [
        '09:00 AM',
        '10:00 AM',
        '11:00 AM',
        '02:00 PM',
        '03:00 PM',
        '04:00 PM',
      ];
    }
  }

  // Helper method to get day name from date
  static String _getDayName(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
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
