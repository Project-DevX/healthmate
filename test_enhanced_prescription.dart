import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';
import 'lib/services/prescription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('🧪 Testing Enhanced Prescription Creation with Patient Details...');

  try {
    // Authenticate as doctor
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'dr.sarah.wilson@gmail.com',
      password: 'admin123',
    );
    print('✅ Authenticated as doctor');

    final doctorId = FirebaseAuth.instance.currentUser!.uid;
    final patientId = 'jb88OHVxtQPWgckyiBqTSqUUpsU2'; // Known patient ID

    print('🔍 Testing patient info lookup for ID: $patientId');

    // Test patient info retrieval
    final patientDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .get();

    if (patientDoc.exists) {
      final patientData = patientDoc.data()!;
      print('✅ Patient found: ${patientData['fullName']}');
      print('   Email: ${patientData['email']}');
      print('   Phone: ${patientData['phoneNumber'] ?? 'Not provided'}');
      print('   Date of Birth: ${patientData['dateOfBirth']}');
    } else {
      print('❌ Patient not found');
      return;
    }

    print('\n🧪 Testing prescription creation with enhanced details...');

    // Create prescription with enhanced patient/doctor details
    final prescriptionId =
        await PrescriptionService.createAndDistributePrescription(
          doctorId: doctorId,
          doctorName: 'Dr. Sarah Wilson',
          patientId: patientId,
          patientName:
              'Test Patient', // This should be enhanced with actual data
          patientEmail: 'himeth.w@gmail.com',
          medicines: [
            {
              'name': 'Test Medicine Enhanced',
              'dosage': '500mg',
              'frequency': '2 times daily',
              'duration': '7 days',
              'quantity': 14,
              'instructions': 'Take with food',
              'timing': 'After Food',
              // No price - dynamic pricing
            },
          ],
          diagnosis: 'Testing enhanced prescription creation',
          notes:
              'This prescription tests the enhanced patient/doctor details feature',
          appointmentId: 'test_appointment_123',
        );

    print('✅ Prescription created with ID: $prescriptionId');

    // Verify the prescription was created with enhanced details
    final prescriptionDoc = await FirebaseFirestore.instance
        .collection('prescriptions')
        .doc(prescriptionId)
        .get();

    if (prescriptionDoc.exists) {
      final prescriptionData = prescriptionDoc.data()!;
      print('\n📋 Created prescription details:');
      print('   Patient Name: ${prescriptionData['patientName']}');
      print('   Patient Email: ${prescriptionData['patientEmail']}');
      print('   Patient Phone: ${prescriptionData['patientPhone']}');
      print('   Patient Age: ${prescriptionData['patientAge']}');
      print('   Doctor Name: ${prescriptionData['doctorName']}');
      print(
        '   Doctor Specialization: ${prescriptionData['doctorSpecialization']}',
      );
      print('   Doctor Hospital: ${prescriptionData['doctorHospital']}');
      print(
        '   Medicine Count: ${(prescriptionData['medicines'] as List).length}',
      );
      print('   Total Amount: ${prescriptionData['totalAmount']}');
    }

    print('\n✅ Test completed successfully!');
  } catch (e) {
    print('❌ Test failed: $e');
  }
}
