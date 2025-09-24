import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

void main() async {
  print('🔍 Checking Bills Database...');

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

      // Check pharmacy_bills collection
      print('📋 Checking pharmacy_bills collection...');
      final billsSnapshot = await FirebaseFirestore.instance
          .collection('pharmacy_bills')
          .where('pharmacyId', isEqualTo: pharmacyId)
          .get();

      print('📊 Found ${billsSnapshot.docs.length} bills in database');

      for (final doc in billsSnapshot.docs) {
        final data = doc.data();
        print(
          '💳 Bill: ${data['billNumber']} - Patient: ${data['patientName']} - Amount: \$${data['totalAmount']}',
        );
      }

      // Check prescriptions collection
      print('\n📋 Checking prescriptions collection...');
      final prescriptionsSnapshot = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where('pharmacyId', isEqualTo: pharmacyId)
          .get();

      print(
        '📊 Found ${prescriptionsSnapshot.docs.length} prescriptions in database',
      );

      for (final doc in prescriptionsSnapshot.docs) {
        final data = doc.data();
        print(
          '💊 Prescription: ${doc.id} - Patient: ${data['patientName']} - Status: ${data['status']}',
        );
      }
    } else {
      print('❌ Authentication failed');
    }
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
  }
}
