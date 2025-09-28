// Test script for doctor creating prescription that should appear in patient profile
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> testPrescriptionFlow() async {
  final firestore = FirebaseFirestore.instance;

  try {
    print('🧪 Testing prescription creation flow...');

    // First, let's check what patient IDs exist
    final users = await firestore
        .collection('users')
        .where('userType', isEqualTo: 'patient')
        .limit(3)
        .get();

    print('📋 Found ${users.docs.length} patient users:');
    for (final user in users.docs) {
      final data = user.data();
      print('   - ID: ${user.id}');
      print('     Name: ${data['fullName'] ?? 'No name'}');
      print('     Email: ${data['email'] ?? 'No email'}');
    }

    // Now let's check existing prescriptions
    final prescriptions = await firestore
        .collection('prescriptions')
        .limit(5)
        .get();

    print('\n📋 Found ${prescriptions.docs.length} total prescriptions:');
    for (final prescription in prescriptions.docs) {
      final data = prescription.data();
      print('   - ID: ${prescription.id}');
      print('     Patient ID: ${data['patientId']}');
      print('     Patient Name: ${data['patientName']}');
      print('     Doctor Name: ${data['doctorName']}');
      print('     Status: ${data['status']}');
      print('     Pharmacy Status: ${data['pharmacyStatus']}');
      print('     Created: ${data['createdAt']}');
      print('     Has prescribedDate: ${data['prescribedDate'] != null}');
    }

    // Test querying prescriptions for a specific patient
    if (users.docs.isNotEmpty) {
      final testPatientId = users.docs.first.id;
      print('\n🔍 Testing prescription query for patient: $testPatientId');

      final patientPrescriptions = await firestore
          .collection('prescriptions')
          .where('patientId', isEqualTo: testPatientId)
          .get();

      print(
        '📋 Found ${patientPrescriptions.docs.length} prescriptions for this patient',
      );
    }
  } catch (e) {
    print('❌ Error during test: $e');
  }
}

void main() async {
  await testPrescriptionFlow();
}
