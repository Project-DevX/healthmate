import 'package:cloud_firestore/cloud_firestore.dart';

class PrescriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<String> createAndDistributePrescription({
    required String doctorId,
    required String doctorName,
    required String patientId,
    required String patientName,
    required String patientEmail,
    required List<Map<String, dynamic>> medicines,
    required String diagnosis,
    required String notes,
    String? appointmentId,
  }) async {
    try {
      // Default pharmacy configuration (digital assignment within system)
      const defaultPharmacyEmail = 'contact.healthcarepharm@gmail.com';

      // Get pharmacy details
      final pharmacyQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: defaultPharmacyEmail)
          .where('userType', isEqualTo: 'pharmacy')
          .get();

      String pharmacyId = '';
      String pharmacyName = 'HealthCare Pharmacy';

      if (pharmacyQuery.docs.isNotEmpty) {
        final pharmacyData = pharmacyQuery.docs.first.data();
        pharmacyId = pharmacyQuery.docs.first.id;
        pharmacyName = pharmacyData['institutionName'] ?? pharmacyName;
      }

      // Fetch detailed patient information
      Map<String, dynamic> patientDetails = {
        'name': patientName,
        'email': patientEmail,
        'phone': '',
        'age': 0,
      };

      try {
        final patientDoc = await _firestore
            .collection('users')
            .doc(patientId)
            .get();
        if (patientDoc.exists) {
          final patientData = patientDoc.data()!;
          patientDetails = {
            'name': patientData['fullName'] ?? patientName,
            'email': patientData['email'] ?? patientEmail,
            'phone': patientData['phoneNumber'] ?? '',
            'age': _calculateAge(patientData['dateOfBirth']),
          };
          print('✅ PRESCRIPTION SERVICE: Enhanced patient details fetched');
        }
      } catch (e) {
        print(
          '⚠️ PRESCRIPTION SERVICE: Could not fetch enhanced patient details: $e',
        );
      }

      // Fetch detailed doctor information
      Map<String, dynamic> doctorDetails = {
        'name': doctorName,
        'specialization': 'General Medicine',
        'hospital': 'Unknown Hospital',
      };

      try {
        final doctorDoc = await _firestore
            .collection('users')
            .doc(doctorId)
            .get();
        if (doctorDoc.exists) {
          final doctorData = doctorDoc.data()!;
          doctorDetails = {
            'name': doctorData['fullName'] ?? doctorName,
            'specialization':
                doctorData['specialization'] ?? 'General Medicine',
            'hospital':
                doctorData['hospitalName'] ??
                doctorData['institution'] ??
                'Unknown Hospital',
          };
          print('✅ PRESCRIPTION SERVICE: Enhanced doctor details fetched');
        }
      } catch (e) {
        print(
          '⚠️ PRESCRIPTION SERVICE: Could not fetch enhanced doctor details: $e',
        );
      }

      // Generate order number for pharmacy tracking
      final orderNumber = await _generateOrderNumber();

      // Debug log the details we're about to save
      print('💊 PRESCRIPTION SERVICE: About to save prescription with:');
      print('  - Patient Name: "${patientDetails['name']}"');
      print('  - Patient Email: "${patientDetails['email']}"');
      print('  - Patient Age: ${patientDetails['age']}');
      print('  - Doctor Name: "${doctorDetails['name']}"');
      print('  - Doctor Specialization: "${doctorDetails['specialization']}"');
      print('  - Doctor Hospital: "${doctorDetails['hospital']}"');

      // Create prescription document with enhanced patient/doctor details
      final prescriptionData = {
        'doctorId': doctorId,
        'doctorName': doctorDetails['name'],
        'doctorSpecialization': doctorDetails['specialization'],
        'doctorHospital': doctorDetails['hospital'],
        'patientId': patientId,
        'patientName': patientDetails['name'],
        'patientEmail': patientDetails['email'],
        'patientPhone': patientDetails['phone'],
        'patientAge': patientDetails['age'],
        'appointmentId': appointmentId,
        'medicines': medicines,
        'diagnosis': diagnosis,
        'notes': notes,
        'status':
            'prescribed', // For patient dashboard compatibility: prescribed -> filled
        'pharmacyStatus':
            'pending', // For pharmacy workflow: pending -> processing -> ready -> delivered
        'pharmacyId': pharmacyId,
        'pharmacyEmail': defaultPharmacyEmail,
        'pharmacyName': pharmacyName,
        'orderNumber': orderNumber,
        'prescribedDate':
            FieldValue.serverTimestamp(), // For patient dashboard compatibility
        'prescriptionDate':
            FieldValue.serverTimestamp(), // For pharmacy compatibility
        'createdAt': FieldValue.serverTimestamp(),
        'totalAmount': 0.0, // Will be calculated by pharmacy
        'timestamp': FieldValue.serverTimestamp(), // For pharmacy compatibility
      };

      // Save prescription to Firestore
      final prescriptionRef = await _firestore
          .collection('prescriptions')
          .add(prescriptionData);

      // Update patient's prescription list
      await _firestore.collection('users').doc(patientId).update({
        'prescriptions': FieldValue.arrayUnion([prescriptionRef.id]),
      });

      // Send notifications to patient and pharmacy
      await _sendNotifications(
        prescriptionId: prescriptionRef.id,
        patientId: patientId,
        patientName: patientName,
        doctorName: doctorName,
        pharmacyId: pharmacyId,
        orderNumber: orderNumber,
      );

      return prescriptionRef.id;
    } catch (e) {
      throw Exception('Failed to create prescription: $e');
    }
  }

  static Future<int> _generateOrderNumber() async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

    final counterRef = _firestore
        .collection('counters')
        .doc('prescription_orders_$dateStr');

    return await _firestore.runTransaction((transaction) async {
      final counterDoc = await transaction.get(counterRef);

      if (!counterDoc.exists) {
        transaction.set(counterRef, {'count': 1});
        return 1;
      } else {
        final currentCount = counterDoc.data()?['count'] ?? 0;
        final newCount = currentCount + 1;
        transaction.update(counterRef, {'count': newCount});
        return newCount;
      }
    });
  }

  static Future<void> _sendNotifications({
    required String prescriptionId,
    required String patientId,
    required String patientName,
    required String doctorName,
    required String pharmacyId,
    required int orderNumber,
  }) async {
    final batch = _firestore.batch();

    // Notification to patient
    final patientNotificationRef = _firestore.collection('notifications').doc();
    batch.set(patientNotificationRef, {
      'recipientId': patientId,
      'recipientType': 'patient',
      'title': 'New Prescription Available',
      'message':
          'Dr. $doctorName has prescribed medications for you. Order #${orderNumber.toString().padLeft(3, '0')} has been sent to the pharmacy.',
      'type': 'prescription',
      'relatedId': prescriptionId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notification to pharmacy (if pharmacy account exists)
    if (pharmacyId.isNotEmpty) {
      final pharmacyNotificationRef = _firestore
          .collection('notifications')
          .doc();
      batch.set(pharmacyNotificationRef, {
        'recipientId': pharmacyId,
        'recipientType': 'pharmacy',
        'title': 'New Prescription Received',
        'message':
            'New prescription Order #${orderNumber.toString().padLeft(3, '0')} from Dr. $doctorName for patient $patientName',
        'type': 'prescription',
        'relatedId': prescriptionId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Get prescriptions stream for pharmacy dashboard
  static Stream<List<Map<String, dynamic>>> getPrescriptionsForPharmacy(
    String pharmacyId,
  ) {
    // Option 1: Use simple query without orderBy to avoid index requirement
    return _firestore
        .collection('prescriptions')
        .where('pharmacyId', isEqualTo: pharmacyId)
        .snapshots()
        .map((snapshot) {
          final prescriptions = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort manually by createdAt timestamp (client-side sorting)
          prescriptions.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });

          return prescriptions;
        });
  }

  // Alternative method using limit to avoid complex indexing
  static Stream<List<Map<String, dynamic>>> getPrescriptionsForPharmacyLimited(
    String pharmacyId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('prescriptions')
        .where('pharmacyId', isEqualTo: pharmacyId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Update prescription status
  static Future<void> updatePrescriptionStatus(
    String prescriptionId,
    String newStatus,
  ) async {
    await _firestore.collection('prescriptions').doc(prescriptionId).update({
      'status': newStatus,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Get prescription details
  static Future<Map<String, dynamic>?> getPrescriptionDetails(
    String prescriptionId,
  ) async {
    final doc = await _firestore
        .collection('prescriptions')
        .doc(prescriptionId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    }
    return null;
  }

  // Helper method to calculate age from date of birth
  static int _calculateAge(dynamic dateOfBirth) {
    if (dateOfBirth == null) return 0;

    try {
      DateTime birthDate;
      if (dateOfBirth is Timestamp) {
        birthDate = dateOfBirth.toDate();
      } else if (dateOfBirth is String) {
        birthDate = DateTime.parse(dateOfBirth);
      } else {
        return 0;
      }

      final now = DateTime.now();
      int age = now.year - birthDate.year;

      // Adjust if birthday hasn't occurred this year
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }

      return age > 0 ? age : 0;
    } catch (e) {
      print('⚠️ Error calculating age: $e');
      return 0;
    }
  }
}
