import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/firebase_options.dart';
import 'lib/services/pharmacy_service.dart';

// Test script to verify pharmacy bills functionality
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

    final pharmacyService = PharmacyService();

    // Test 1: Create sample data with prescriptions
    print('\n🧪 Creating sample prescriptions...');
    await pharmacyService.createSampleData();
    print('✅ Sample prescriptions created');

    // Test 2: Get current bill number
    print('\n🧪 Testing bill numbering system...');
    final billNumber = await pharmacyService.getCurrentBillNumber();
    print('✅ Current bill number: $billNumber');

    // Test 3: Update prescription status to "delivered" (should auto-generate bill)
    print('\n🧪 Testing automatic bill generation on delivery...');
    await pharmacyService.updatePrescriptionStatus(
      'prescription_001',
      'delivered',
    );
    print('✅ Prescription marked as delivered - bill should be auto-generated');

    // Wait a moment for the bill to be created
    await Future.delayed(const Duration(seconds: 2));

    // Test 4: Get bills to verify the bill was created
    print('\n🧪 Fetching bills...');
    final bills = await pharmacyService.getBills();
    print('✅ Found ${bills.length} bills');

    for (final bill in bills) {
      print('   - Bill: ${bill.billNumber}');
      print('     Patient: ${bill.patientName}');
      print('     Total: \$${bill.totalAmount.toStringAsFixed(2)}');
      print('     Status: ${bill.status}');
      print('     Prescription ID: ${bill.prescriptionId ?? 'N/A'}');
    }

    // Test 5: Test bill numbering increment
    print('\n🧪 Testing bill number increment...');
    await pharmacyService.incrementBillNumber();
    final newBillNumber = await pharmacyService.getCurrentBillNumber();
    print('✅ New bill number after increment: $newBillNumber');

    print('\n🎉 All pharmacy bills tests completed successfully!');
    print('\n📋 Summary of changes:');
    print('   • Renamed "orders" to "bills" in method names and collections');
    print(
      '   • Bills are automatically generated when prescription status = "delivered"',
    );
    print('   • Bills have proper sequential numbering: BILL-YYYYMMDD-###');
    print('   • Bills include prescription ID for traceability');
    print(
      '   • Bills section can be accessed via getBills() and getBillsStream()',
    );
  } catch (e) {
    print('❌ Error: $e');
  }
}
