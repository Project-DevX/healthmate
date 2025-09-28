// Test script to verify prescription visibility in patient profiles
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/prescription_service.dart';
import 'lib/services/interconnect_service.dart';

Future<void> testPrescriptionVisibility() async {
  try {
    print('🧪 Testing prescription visibility for patients...');

    // Test prescription data
    final testMedicines = [
      {
        'name': 'Amoxicillin',
        'dosage': '500mg',
        'quantity': 21,
        'frequency': '3 times daily',
        'duration': '7 days',
        'instructions': 'Take with food',
        'price': 0.0, // Will be updated by pharmacy
      },
    ];

    print('📝 Creating test prescription...');

    // Create a prescription
    final prescriptionId =
        await PrescriptionService.createAndDistributePrescription(
          doctorId: 'test_doctor_id',
          doctorName: 'Dr. Test Wilson',
          patientId: 'test_patient_id',
          patientName: 'John Test Patient',
          patientEmail: 'test.patient@example.com',
          medicines: testMedicines,
          diagnosis: 'Upper respiratory infection',
          notes: 'Test prescription for visibility check',
        );

    print('✅ Prescription created with ID: $prescriptionId');

    // Wait a moment for data to propagate
    await Future.delayed(Duration(seconds: 2));

    print('🔍 Checking if prescription appears in patient profile...');

    // Fetch patient prescriptions
    final prescriptions = await InterconnectService.getUserPrescriptions(
      'test_patient_id',
      'patient',
    );

    print('📋 Found ${prescriptions.length} prescriptions for patient');

    // Check if our test prescription is there
    final testPrescription = prescriptions
        .where((p) => p.id == prescriptionId)
        .firstOrNull;

    if (testPrescription != null) {
      print('✅ SUCCESS: Prescription found in patient profile!');
      print('   - ID: ${testPrescription.id}');
      print('   - Doctor: ${testPrescription.doctorName}');
      print('   - Status: ${testPrescription.status}');
      print('   - Medicines: ${testPrescription.medicines.length}');
    } else {
      print('❌ FAILURE: Prescription not found in patient profile');
      print(
        'Available prescription IDs: ${prescriptions.map((p) => p.id).join(', ')}',
      );
    }
  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}

void main() async {
  await testPrescriptionVisibility();
}
