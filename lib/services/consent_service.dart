// lib/services/consent_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shared_models.dart';

class ConsentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ CONSENT REQUEST MANAGEMENT ============

  /// Doctor-initiated consent request
  static Future<String> requestMedicalRecordAccess({
    required String doctorId,
    required String doctorName,
    required String doctorSpecialty,
    required String patientId,
    required String patientName,
    required String appointmentId,
    required String requestType,
    required String purpose,
    List<String>? specificRecordIds,
    int durationDays = 30,
  }) async {
    try {
      print(
        '🔐 CONSENT: Creating consent request from Dr. $doctorName to $patientName',
      );

      // Check if there's already a pending request for the same type
      final existingRequest = await _firestore
          .collection('consent_requests')
          .where('doctorId', isEqualTo: doctorId)
          .where('patientId', isEqualTo: patientId)
          .where('requestType', isEqualTo: requestType)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception(
          'A pending consent request for $requestType already exists for this patient',
        );
      }

      // Generate unique request ID
      final requestId = 'CR_${DateTime.now().millisecondsSinceEpoch}';

      final consentRequest = ConsentRequest(
        id: '',
        requestId: requestId,
        doctorId: doctorId,
        doctorName: doctorName,
        doctorSpecialty: doctorSpecialty,
        patientId: patientId,
        patientName: patientName,
        requestType: requestType,
        purpose: purpose,
        requestDate: DateTime.now(),
        status: 'pending',
        appointmentId: appointmentId,
        specificRecordIds: specificRecordIds,
        durationDays: durationDays,
      );

      final docRef = await _firestore
          .collection('consent_requests')
          .add(consentRequest.toMap());

      // Send notification to patient
      await _sendConsentRequestNotification(
        patientId: patientId,
        doctorName: doctorName,
        requestType: requestType,
        purpose: purpose,
        requestId: docRef.id,
      );

      print('✅ CONSENT: Request $requestId created successfully');
      return docRef.id;
    } catch (e) {
      print('❌ CONSENT: Failed to create consent request: $e');
      throw Exception('Failed to create consent request: $e');
    }
  }

  /// Patient responds to consent request
  static Future<void> respondToConsentRequest(
    String requestId,
    String response, // 'approved' or 'denied'
    String? patientNote,
  ) async {
    try {
      print('🔐 CONSENT: Patient responding to request $requestId: $response');

      final requestDoc = await _firestore
          .collection('consent_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Consent request not found');
      }

      final consentRequest = ConsentRequest.fromFirestore(requestDoc);

      if (consentRequest.status != 'pending') {
        throw Exception('Consent request has already been responded to');
      }

      DateTime? expiryDate;
      if (response == 'approved') {
        expiryDate = DateTime.now().add(
          Duration(days: consentRequest.durationDays),
        );
      }

      await _firestore.collection('consent_requests').doc(requestId).update({
        'status': response,
        'responseDate': Timestamp.now(),
        'patientResponse': patientNote,
        'expiryDate': expiryDate != null
            ? Timestamp.fromDate(expiryDate)
            : null,
      });

      // Send notification to doctor
      await _sendConsentResponseNotification(
        doctorId: consentRequest.doctorId,
        patientName: consentRequest.patientName,
        response: response,
        requestType: consentRequest.requestType,
      );

      print('✅ CONSENT: Request $requestId updated with response: $response');
    } catch (e) {
      print('❌ CONSENT: Failed to respond to consent request: $e');
      throw Exception('Failed to respond to consent request: $e');
    }
  }

  /// Get pending consent requests for patient
  static Future<List<ConsentRequest>> getPatientPendingRequests(
    String patientId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('consent_requests')
          .where('patientId', isEqualTo: patientId)
          .where('status', isEqualTo: 'pending')
          .orderBy('requestDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ConsentRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ CONSENT: Failed to get patient pending requests: $e');
      throw Exception('Failed to get pending requests: $e');
    }
  }

  /// Get all consent requests for patient (pending, approved, denied)
  static Future<List<ConsentRequest>> getPatientConsentHistory(
    String patientId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('consent_requests')
          .where('patientId', isEqualTo: patientId)
          .get();

      final requests = snapshot.docs
          .map((doc) => ConsentRequest.fromFirestore(doc))
          .toList();

      // Sort by request date (newest first)
      requests.sort((a, b) => b.requestDate.compareTo(a.requestDate));

      return requests;
    } catch (e) {
      print('❌ CONSENT: Failed to get patient consent history: $e');
      throw Exception('Failed to get consent history: $e');
    }
  }

  /// Get doctor's consent requests
  static Future<List<ConsentRequest>> getDoctorConsentRequests(
    String doctorId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('consent_requests')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      final requests = snapshot.docs
          .map((doc) => ConsentRequest.fromFirestore(doc))
          .toList();

      // Sort by request date (newest first)
      requests.sort((a, b) => b.requestDate.compareTo(a.requestDate));

      return requests;
    } catch (e) {
      print('❌ CONSENT: Failed to get doctor consent requests: $e');
      throw Exception('Failed to get consent requests: $e');
    }
  }

  /// Get active consent information for any approved consent
  static Future<Map<String, dynamic>> getActiveConsentInfo(
    String doctorId,
    String patientId,
  ) async {
    try {
      print(
        '🔐 CONSENT: Getting active consent info for Dr. $doctorId -> Patient $patientId',
      );

      final now = DateTime.now();

      final snapshot = await _firestore
          .collection('consent_requests')
          .where('doctorId', isEqualTo: doctorId)
          .where('patientId', isEqualTo: patientId)
          .where('status', isEqualTo: 'approved')
          .get();

      // Find any active consent (not expired)
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();

        if (expiresAt.isAfter(now)) {
          return {
            'hasConsent': true,
            'consentRequestId': data['requestId'],
            'requestType': data['requestType'],
            'purpose': data['purpose'],
            'expiresAt': expiresAt,
          };
        }
      }

      return {'hasConsent': false};
    } catch (e) {
      print('❌ CONSENT: Error getting active consent info: $e');
      return {'hasConsent': false, 'error': e.toString()};
    }
  }

  /// Check if doctor has active consent for patient records
  static Future<bool> hasActiveConsent(
    String doctorId,
    String patientId,
    String recordType,
  ) async {
    try {
      print(
        '🔐 CONSENT: Checking consent for Dr. $doctorId -> Patient $patientId ($recordType)',
      );

      final now = DateTime.now();

      final snapshot = await _firestore
          .collection('consent_requests')
          .where('doctorId', isEqualTo: doctorId)
          .where('patientId', isEqualTo: patientId)
          .where('requestType', isEqualTo: recordType)
          .where('status', isEqualTo: 'approved')
          .get();

      for (var doc in snapshot.docs) {
        final request = ConsentRequest.fromFirestore(doc);
        if (request.expiryDate != null && request.expiryDate!.isAfter(now)) {
          print(
            '✅ CONSENT: Active consent found (expires: ${request.expiryDate})',
          );
          return true;
        }
      }

      // Check for 'full_history' consent if specific type not found
      if (recordType != 'full_history') {
        final fullHistorySnapshot = await _firestore
            .collection('consent_requests')
            .where('doctorId', isEqualTo: doctorId)
            .where('patientId', isEqualTo: patientId)
            .where('requestType', isEqualTo: 'full_history')
            .where('status', isEqualTo: 'approved')
            .get();

        for (var doc in fullHistorySnapshot.docs) {
          final request = ConsentRequest.fromFirestore(doc);
          if (request.expiryDate != null && request.expiryDate!.isAfter(now)) {
            print(
              '✅ CONSENT: Full history consent found (expires: ${request.expiryDate})',
            );
            return true;
          }
        }
      }

      print('❌ CONSENT: No active consent found');
      return false;
    } catch (e) {
      print('❌ CONSENT: Error checking consent: $e');
      return false;
    }
  }

  /// Get accessible patient records for doctor with consent verification
  static Future<Map<String, dynamic>> getAccessiblePatientRecords(
    String doctorId,
    String patientId,
    String consentRequestId,
    String purpose,
  ) async {
    try {
      print(
        '🔐 CONSENT: Getting accessible records for Dr. $doctorId -> Patient $patientId',
      );

      final records = <String, dynamic>{
        'appointments': <Appointment>[],
        'labReports': <LabReport>[],
        'prescriptions': <Prescription>[],
        'hasLabReportsAccess': false,
        'hasPrescriptionsAccess': false,
        'hasFullHistoryAccess': false,
      };

      // Check specific consents
      final hasLabConsent = await hasActiveConsent(
        doctorId,
        patientId,
        'lab_reports',
      );
      final hasPrescriptionConsent = await hasActiveConsent(
        doctorId,
        patientId,
        'prescriptions',
      );
      final hasFullConsent = await hasActiveConsent(
        doctorId,
        patientId,
        'full_history',
      );

      records['hasLabReportsAccess'] = hasLabConsent || hasFullConsent;
      records['hasPrescriptionsAccess'] =
          hasPrescriptionConsent || hasFullConsent;
      records['hasFullHistoryAccess'] = hasFullConsent;

      // Get appointments (always accessible for treating doctor)
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .where('doctorId', isEqualTo: doctorId)
          .get();

      final appointments = appointmentsSnapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .toList();
      appointments.sort(
        (a, b) => b.appointmentDate.compareTo(a.appointmentDate),
      );
      records['appointments'] = appointments;

      // Get lab reports if consent exists
      if (records['hasLabReportsAccess']) {
        final labReportsSnapshot = await _firestore
            .collection('lab_reports')
            .where('patientId', isEqualTo: patientId)
            .get();

        final labReports = labReportsSnapshot.docs
            .map((doc) => LabReport.fromFirestore(doc))
            .toList();
        labReports.sort((a, b) => b.testDate.compareTo(a.testDate));
        records['labReports'] = labReports;

        // Log access
        for (var report in labReports) {
          await logMedicalRecordAccess(
            doctorId: doctorId,
            patientId: patientId,
            recordType: 'lab_report',
            recordId: report.id,
            consentRequestId: consentRequestId,
            purpose: purpose,
          );
        }
      }

      // Get prescriptions if consent exists
      if (records['hasPrescriptionsAccess']) {
        final prescriptionsSnapshot = await _firestore
            .collection('prescriptions')
            .where('patientId', isEqualTo: patientId)
            .get();

        final prescriptions = prescriptionsSnapshot.docs
            .map((doc) => Prescription.fromFirestore(doc))
            .toList();
        prescriptions.sort(
          (a, b) => b.prescribedDate.compareTo(a.prescribedDate),
        );
        records['prescriptions'] = prescriptions;

        // Log access
        for (var prescription in prescriptions) {
          await logMedicalRecordAccess(
            doctorId: doctorId,
            patientId: patientId,
            recordType: 'prescription',
            recordId: prescription.id,
            consentRequestId: consentRequestId,
            purpose: purpose,
          );
        }
      }

      print('✅ CONSENT: Retrieved accessible records successfully');
      return records;
    } catch (e) {
      print('❌ CONSENT: Failed to get accessible records: $e');
      throw Exception('Failed to get accessible patient records: $e');
    }
  }

  /// Log medical record access for audit trail
  static Future<void> logMedicalRecordAccess({
    required String doctorId,
    required String patientId,
    required String recordType,
    required String recordId,
    required String consentRequestId,
    required String purpose,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Get doctor and patient names
      final doctorDoc = await _firestore
          .collection('users')
          .doc(doctorId)
          .get();
      final patientDoc = await _firestore
          .collection('users')
          .doc(patientId)
          .get();

      final doctorName = doctorDoc.data()?['fullName'] ?? 'Unknown Doctor';
      final patientName = patientDoc.data()?['name'] ?? 'Unknown Patient';

      final accessLog = MedicalRecordAccess(
        id: '',
        doctorId: doctorId,
        doctorName: doctorName,
        patientId: patientId,
        patientName: patientName,
        recordType: recordType,
        recordId: recordId,
        accessTime: DateTime.now(),
        consentRequestId: consentRequestId,
        purpose: purpose,
        ipAddress: 'mobile_app', // In a real app, you'd get actual IP
        metadata: metadata,
      );

      await _firestore
          .collection('medical_record_access_log')
          .add(accessLog.toMap());

      print('✅ CONSENT: Access logged for $recordType:$recordId');
    } catch (e) {
      print('❌ CONSENT: Failed to log access: $e');
      // Don't throw here as logging failure shouldn't block access
    }
  }

  /// Auto-expire old consent requests and approvals
  static Future<void> expireOldConsentRequests() async {
    try {
      final now = DateTime.now();

      // Expire pending requests older than 7 days
      final oldPendingSnapshot = await _firestore
          .collection('consent_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      final batch = _firestore.batch();
      int expiredCount = 0;

      for (var doc in oldPendingSnapshot.docs) {
        final request = ConsentRequest.fromFirestore(doc);
        final daysSinceRequest = now.difference(request.requestDate).inDays;

        if (daysSinceRequest > 7) {
          batch.update(doc.reference, {'status': 'expired'});
          expiredCount++;
        }
      }

      // Expire approved consents past their expiry date
      final expiredApprovedSnapshot = await _firestore
          .collection('consent_requests')
          .where('status', isEqualTo: 'approved')
          .get();

      for (var doc in expiredApprovedSnapshot.docs) {
        final request = ConsentRequest.fromFirestore(doc);
        if (request.expiryDate != null && now.isAfter(request.expiryDate!)) {
          batch.update(doc.reference, {'status': 'expired'});
          expiredCount++;
        }
      }

      await batch.commit();
      print('✅ CONSENT: Expired $expiredCount old consent requests');
    } catch (e) {
      print('❌ CONSENT: Failed to expire old requests: $e');
    }
  }

  /// Revoke active consent
  static Future<void> revokeConsent(String requestId) async {
    try {
      await _firestore.collection('consent_requests').doc(requestId).update({
        'status': 'revoked',
        'responseDate': Timestamp.now(),
      });

      print('✅ CONSENT: Consent $requestId revoked successfully');
    } catch (e) {
      print('❌ CONSENT: Failed to revoke consent: $e');
      throw Exception('Failed to revoke consent: $e');
    }
  }

  // ============ PATIENT CONSENT SETTINGS ============

  /// Get patient consent settings
  static Future<PatientConsentSettings?> getPatientConsentSettings(
    String patientId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('patient_consent_settings')
          .where('patientId', isEqualTo: patientId)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return PatientConsentSettings.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('❌ CONSENT: Failed to get patient settings: $e');
      return null;
    }
  }

  /// Update patient consent settings
  static Future<void> updatePatientConsentSettings(
    PatientConsentSettings settings,
  ) async {
    try {
      final existingSnapshot = await _firestore
          .collection('patient_consent_settings')
          .where('patientId', isEqualTo: settings.patientId)
          .get();

      if (existingSnapshot.docs.isEmpty) {
        await _firestore
            .collection('patient_consent_settings')
            .add(settings.toMap());
      } else {
        await _firestore
            .collection('patient_consent_settings')
            .doc(existingSnapshot.docs.first.id)
            .update(settings.toMap());
      }

      print('✅ CONSENT: Patient settings updated successfully');
    } catch (e) {
      print('❌ CONSENT: Failed to update patient settings: $e');
      throw Exception('Failed to update consent settings: $e');
    }
  }

  // ============ NOTIFICATION HELPERS ============

  static Future<void> _sendConsentRequestNotification({
    required String patientId,
    required String doctorName,
    required String requestType,
    required String purpose,
    required String requestId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'recipientId': patientId,
        'recipientType': 'patient',
        'title': 'Medical Records Access Request',
        'message':
            'Dr. $doctorName has requested access to your ${_getRequestTypeDisplayName(requestType)} for: $purpose',
        'type': 'consent_request',
        'relatedId': requestId,
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('❌ CONSENT: Failed to send notification: $e');
    }
  }

  static Future<void> _sendConsentResponseNotification({
    required String doctorId,
    required String patientName,
    required String response,
    required String requestType,
  }) async {
    try {
      final title = response == 'approved'
          ? 'Medical Records Access Approved'
          : 'Medical Records Access Denied';

      final message =
          '$patientName has ${response} your request to access their ${_getRequestTypeDisplayName(requestType)}';

      await _firestore.collection('notifications').add({
        'recipientId': doctorId,
        'recipientType': 'doctor',
        'title': title,
        'message': message,
        'type': 'consent_response',
        'relatedId': '',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('❌ CONSENT: Failed to send response notification: $e');
    }
  }

  static String _getRequestTypeDisplayName(String requestType) {
    switch (requestType) {
      case 'lab_reports':
        return 'lab reports';
      case 'prescriptions':
        return 'prescriptions';
      case 'full_history':
        return 'medical history';
      default:
        return requestType;
    }
  }
}
