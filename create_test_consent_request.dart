// create_test_consent_request.dart
// Quick script to create a test consent request for testing

import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('🔐 Creating test consent request...');

  try {
    final firestore = FirebaseFirestore.instance;

    // Create a test consent request (replace with your actual user IDs)
    final testConsentRequest = {
      'requestId': 'CR_TEST_${DateTime.now().millisecondsSinceEpoch}',
      'doctorId':
          '8FLajrsoGGP1nKaxIT8t7nkX5fU2', // Dr. Sarah Wilson (from your log)
      'doctorName': 'Dr. Sarah Wilson',
      'doctorSpecialty': 'Cardiology',
      'patientId':
          'YOUR_PATIENT_USER_ID_HERE', // Replace with actual patient ID
      'patientName': 'Test Patient',
      'requestType': 'lab_reports',
      'purpose': 'Need to review lab results for consultation',
      'appointmentId': 'test_appointment_123',
      'status': 'pending',
      'requestDate': Timestamp.now(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'specificRecordIds': null,
      'durationDays': 30,
    };

    await firestore.collection('consent_requests').add(testConsentRequest);

    print('✅ Test consent request created successfully!');
    print('📋 Request details:');
    print('   - Doctor: ${testConsentRequest['doctorName']}');
    print('   - Patient: ${testConsentRequest['patientName']}');
    print('   - Type: ${testConsentRequest['requestType']}');
    print('   - Status: ${testConsentRequest['status']}');
  } catch (e) {
    print('❌ Error creating test consent request: $e');
  }
}
