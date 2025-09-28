// Quick debug script to check prescription visibility
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> debugPrescriptionVisibility() async {
  final firestore = FirebaseFirestore.instance;

  try {
    print('🔍 DEBUG: Checking prescriptions collection...');

    // Get all prescriptions to see what's there
    final allPrescriptions = await firestore.collection('prescriptions').get();
    print('📋 Found ${allPrescriptions.docs.length} total prescriptions');

    for (final doc in allPrescriptions.docs.take(3)) {
      final data = doc.data();
      print('🔍 Prescription ${doc.id}:');
      print('  - patientId: ${data['patientId']}');
      print('  - patientName: ${data['patientName']}');
      print('  - status: ${data['status']}');
      print('  - pharmacyStatus: ${data['pharmacyStatus']}');
      print('  - doctorName: ${data['doctorName']}');
      print('  - medicines: ${(data['medicines'] as List?)?.length ?? 0}');
      print('  - createdAt: ${data['createdAt']}');
      print('  - prescribedDate: ${data['prescribedDate']}');
    }

    // Test a specific patient ID query
    print('\n🔍 Testing patient-specific query...');
    final patientPrescriptions = await firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: 'test_patient_id')
        .get();
    print(
      '📋 Found ${patientPrescriptions.docs.length} prescriptions for test_patient_id',
    );
  } catch (e) {
    print('❌ Error during debug: $e');
  }
}

void main() async {
  await debugPrescriptionVisibility();
}
