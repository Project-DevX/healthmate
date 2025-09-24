import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

void main() async {
  print('📝 Creating Test Bill...');

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
      final pharmacyId = credential.user!.uid;
      print('✅ Authentication successful for pharmacyId: $pharmacyId');

      // Create a simple test bill
      final billData = {
        'id': 'test_bill_001',
        'billNumber': 'BILL-20250924-TEST',
        'prescriptionId': 'test_prescription_001',
        'pharmacyId': pharmacyId,
        'patientName': 'Test Patient',
        'patientInfo': {
          'id': 'test_patient_001',
          'name': 'Test Patient',
          'phone': '+1234567890',
        },
        'doctorInfo': {'id': 'test_doctor_001', 'name': 'Dr. Test'},
        'medicines': [
          {
            'name': 'Test Medicine',
            'dosage': '500mg',
            'quantity': 30,
            'price': 25.99,
            'instructions': 'Take as needed',
          },
        ],
        'subtotal': 25.99,
        'tax': 2.60,
        'totalAmount': 28.59,
        'billDate': Timestamp.fromDate(DateTime.now()),
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'status': 'paid',
      };

      print('💰 Creating test bill in Firestore...');
      await FirebaseFirestore.instance
          .collection('pharmacy_bills')
          .doc('test_bill_001')
          .set(billData);

      print('✅ Test bill created successfully!');

      // Verify it exists
      print('🔍 Verifying bill exists...');
      final doc = await FirebaseFirestore.instance
          .collection('pharmacy_bills')
          .doc('test_bill_001')
          .get();

      if (doc.exists) {
        print('✅ Bill verified: ${doc.data()!['billNumber']}');
      } else {
        print('❌ Bill not found');
      }
    } else {
      print('❌ Authentication failed');
    }
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
  }
}
