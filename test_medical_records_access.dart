// Test Medical Records Access After Consent Approval
// This script helps test the complete consent-to-access workflow

import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('🧪 TESTING: Medical Records Access After Consent');
  await testMedicalRecordsAccess();
}

Future<void> testMedicalRecordsAccess() async {
  try {
    // Test parameters - update these with your actual IDs
    const doctorId = '8FLajrsoGGP1nKaxIT8t7nkX5fU2'; // Dr. Sarah Wilson
    const patientId = 'jb88OHVxtQPWgckyiBqTSqUUpsU2'; // Test patient

    print('🔐 Testing consent access for:');
    print('   Doctor ID: $doctorId');
    print('   Patient ID: $patientId');

    // 1. Check if there are any approved consent requests
    print('\n1️⃣ Checking for approved consent requests...');
    final approvedConsents = await FirebaseFirestore.instance
        .collection('consent_requests')
        .where('doctorId', isEqualTo: doctorId)
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'approved')
        .get();

    print('   Found ${approvedConsents.docs.length} approved consent requests');

    for (var doc in approvedConsents.docs) {
      final data = doc.data();
      print('   - Request ID: ${data['requestId']}');
      print('   - Type: ${data['requestType']}');
      print('   - Status: ${data['status']}');
      print('   - Expiry: ${data['expiryDate']}');
      print('   - Purpose: ${data['purpose']}');
    }

    // 2. Test getActiveConsentInfo method
    print('\n2️⃣ Testing getActiveConsentInfo method...');
    final now = DateTime.now();

    for (final doc in approvedConsents.docs) {
      final data = doc.data();
      final expiryDate = data['expiryDate'] != null
          ? (data['expiryDate'] as Timestamp).toDate()
          : null;

      if (expiryDate != null && expiryDate.isAfter(now)) {
        print('   ✅ Active consent found:');
        print('      - Request ID: ${data['requestId']}');
        print('      - Type: ${data['requestType']}');
        print('      - Expires: $expiryDate');
        print('      - Purpose: ${data['purpose']}');
      } else {
        print('   ❌ Expired consent:');
        print('      - Request ID: ${data['requestId']}');
        print('      - Expired: $expiryDate');
      }
    }

    // 3. Check for specific consent types
    print('\n3️⃣ Checking specific consent types...');
    final consentTypes = ['lab_reports', 'prescriptions', 'full_history'];

    for (String type in consentTypes) {
      final hasConsent = await checkActiveConsentForType(
        doctorId,
        patientId,
        type,
      );
      print('   - $type: ${hasConsent ? "✅ GRANTED" : "❌ NOT GRANTED"}');
    }

    // 4. Test medical records queries
    print('\n4️⃣ Testing medical records queries...');

    // Test appointments query
    final appointmentsSnapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .where('doctorId', isEqualTo: doctorId)
        .get();
    print('   - Appointments available: ${appointmentsSnapshot.docs.length}');

    // Test lab reports query
    final labReportsSnapshot = await FirebaseFirestore.instance
        .collection('lab_reports')
        .where('patientId', isEqualTo: patientId)
        .get();
    print('   - Lab reports available: ${labReportsSnapshot.docs.length}');

    // Test prescriptions query
    final prescriptionsSnapshot = await FirebaseFirestore.instance
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .get();
    print('   - Prescriptions available: ${prescriptionsSnapshot.docs.length}');

    print('\n🎯 DIAGNOSIS:');
    if (approvedConsents.docs.isNotEmpty) {
      print('✅ Consent requests are being approved successfully');
      print('✅ Doctor should be able to access medical records');
      print('🔍 If doctor still can\'t see records, check:');
      print('   1. Are consent requests properly approved?');
      print('   2. Are expiryDate fields set correctly?');
      print('   3. Is PatientMedicalRecordsScreen loading properly?');
      print('   4. Are Firebase queries working in ConsentService?');
    } else {
      print('❌ No approved consent requests found');
      print('🔍 Patient needs to approve consent requests first');
    }
  } catch (e) {
    print('❌ Test failed: $e');
  }
}

Future<bool> checkActiveConsentForType(
  String doctorId,
  String patientId,
  String recordType,
) async {
  try {
    final now = DateTime.now();

    final snapshot = await FirebaseFirestore.instance
        .collection('consent_requests')
        .where('doctorId', isEqualTo: doctorId)
        .where('patientId', isEqualTo: patientId)
        .where('requestType', isEqualTo: recordType)
        .where('status', isEqualTo: 'approved')
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final expiryDate = data['expiryDate'] != null
          ? (data['expiryDate'] as Timestamp).toDate()
          : null;

      if (expiryDate != null && expiryDate.isAfter(now)) {
        return true;
      }
    }

    return false;
  } catch (e) {
    print('Error checking consent for $recordType: $e');
    return false;
  }
}
