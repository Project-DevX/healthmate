import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/firebase_options.dart';
import 'lib/services/pharmacy_service.dart';

// Test script to verify pharmacy fixes
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Authenticate as a test pharmacy user
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'contact.healthcarepharm@gmail.com',
      password: 'testpassword',
    );

    print('✅ Authenticated as pharmacy user');

    // Test the fixes
    final pharmacyService = PharmacyService();

    // Test 1: Update prescription status (should use 'prescriptions' collection)
    print('\n🧪 Testing prescription status update...');
    await pharmacyService.updatePrescriptionStatus('prescription_001', 'ready');
    print('✅ Prescription status update completed (no errors expected)');

    // Test 2: Try to generate a bill (should handle FieldValue properly)
    print('\n🧪 Testing bill generation...');
    try {
      // Create a mock prescription
      final mockPrescription = PharmacyPrescription(
        id: 'test_001',
        orderNumber: 1001,
        pharmacyId: pharmacyService.currentPharmacyId ?? '',
        patientInfo: PatientInfo(
          id: 'patient_001',
          name: 'Test Patient',
          age: 30,
          phone: '+1234567890',
          email: 'test@example.com',
        ),
        doctorInfo: DoctorInfo(
          id: 'doctor_001',
          name: 'Dr. Test',
          specialization: 'General',
          hospital: 'Test Hospital',
        ),
        medicines: [
          Medicine(
            id: 'med_001',
            name: 'Test Medicine',
            quantity: 1,
            dosage: '1 tablet',
            instructions: 'Test instructions',
            price: 10.0,
            duration: '7 days',
          ),
        ],
        status: 'ready',
        timestamp: DateTime.now(),
        prescriptionDate: DateTime.now(),
        totalAmount: 10.0,
      );

      final bill = await pharmacyService.generateBill(mockPrescription);
      print('✅ Bill generated successfully: ${bill.billNumber}');
    } catch (e) {
      print('❌ Bill generation error: $e');
    }

    // Test 3: Create sample data (should use correct collections)
    print('\n🧪 Testing sample data creation...');
    await pharmacyService.createSampleData();
    print('✅ Sample data creation completed');

    print('\n🎉 All tests completed!');
  } catch (e) {
    print('❌ Authentication error: $e');
  }
}
