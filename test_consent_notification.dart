// Quick Test Script for Consent Notifications
// Run this in your app to create a test consent request

void createTestConsentRequest() async {
  try {
    print('🔐 Creating test consent request...');

    // Test data - replace with actual user IDs from your Firebase Auth
    const doctorId =
        '8FLajrsoGGP1nKaxIT8t7nkX5fU2'; // Dr. Sarah Wilson from your log
    const patientId = 'REPLACE_WITH_PATIENT_USER_ID'; // Patient user ID

    final requestId = await ConsentService.requestMedicalRecordAccess(
      doctorId: doctorId,
      doctorName: 'Dr. Sarah Wilson',
      doctorSpecialty: 'Cardiology',
      patientId: patientId,
      patientName: 'Test Patient',
      appointmentId: 'test_appointment_123',
      requestType: 'lab_reports',
      purpose:
          'Testing consent notification system - need to review lab results',
      durationDays: 30,
    );

    print('✅ Test consent request created successfully!');
    print('📋 Request ID: $requestId');
    print('👤 From: Dr. Sarah Wilson');
    print('🎯 To: Patient ID $patientId');
    print('📄 Type: Lab Reports');
    print('⏰ Duration: 30 days');

    print('\n🔔 Now check the patient dashboard for notifications!');
  } catch (e) {
    print('❌ Error creating test consent request: $e');
  }
}

// Instructions:
// 1. Replace REPLACE_WITH_PATIENT_USER_ID with the actual patient user ID
// 2. Make sure both doctor and patient accounts exist in Firebase Auth
// 3. Call this function from anywhere in your app (like a button press)
// 4. Check the patient dashboard for the notification
