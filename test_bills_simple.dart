import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/pharmacy_service.dart';
import 'lib/firebase_options.dart';

void main() async {
  print('🚀 Starting Bill Management Test...');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Authenticate as pharmacy user
    const email = 'contact.healthcarepharm@gmail.com';
    const password = 'admin123';

    print('🔐 Authenticating user...');
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      print('✅ Authentication successful');

      final pharmacyService = PharmacyService();

      // Step 1: Create a test prescription
      print('📝 Creating test prescription...');
      final prescriptionId =
          'test_prescription_${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance
          .collection('prescriptions')
          .doc(prescriptionId)
          .set({
            'prescriptionId': prescriptionId,
            'pharmacyId': FirebaseAuth.instance.currentUser!.uid,
            'patientId': 'test_patient_001',
            'patientName': 'John Doe Test',
            'patientPhone': '+1234567890',
            'doctorId': 'test_doctor_001',
            'doctorName': 'Dr. Smith Test',
            'medicines': [
              {
                'name': 'Aspirin',
                'dosage': '500mg',
                'quantity': 30,
                'price': 15.99,
                'instructions': 'Take one daily',
              },
              {
                'name': 'Vitamin D',
                'dosage': '1000IU',
                'quantity': 60,
                'price': 12.50,
                'instructions': 'Take one daily with food',
              },
            ],
            'totalAmount': 28.49,
            'status': 'pending',
            'prescriptionDate': Timestamp.fromDate(DateTime.now()),
            'timestamp': Timestamp.fromDate(DateTime.now()),
          });

      print('✅ Test prescription created with ID: $prescriptionId');

      // Step 2: Update prescription status to 'delivered' to trigger bill generation
      print('📋 Updating prescription status to delivered...');
      await pharmacyService.updatePrescriptionStatus(
        prescriptionId,
        'delivered',
      );

      // Step 3: Wait a moment for the operation to complete
      await Future.delayed(const Duration(seconds: 2));

      // Step 4: Check if bill was generated
      print('🔍 Checking for generated bills...');
      final bills = await pharmacyService.getBills();

      print('📊 Found ${bills.length} bills');

      if (bills.isNotEmpty) {
        final latestBill = bills.first;
        print('💰 Latest Bill Details:');
        print('   Bill Number: ${latestBill.billNumber}');
        print('   Patient: ${latestBill.patientName}');
        print(
          '   Total Amount: \$${latestBill.totalAmount.toStringAsFixed(2)}',
        );
        print('   Prescription ID: ${latestBill.prescriptionId}');
        print('   Medicines: ${latestBill.medicines.length} items');

        // Step 5: Test bills stream
        print('🔄 Testing bills stream...');
        final stream = pharmacyService.getBillsStream();
        await for (final billsList in stream.take(1)) {
          print('📡 Stream returned ${billsList.length} bills');
          break;
        }

        print('✅ Bill management system working correctly!');
      } else {
        print(
          '❌ No bills found - there might be an issue with bill generation',
        );
      }

      // Cleanup: Remove test prescription
      print('🧹 Cleaning up test data...');
      await FirebaseFirestore.instance
          .collection('prescriptions')
          .doc(prescriptionId)
          .delete();

      print('✅ Test completed successfully!');
    } else {
      print('❌ Authentication failed');
    }
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
  }
}
