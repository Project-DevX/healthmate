import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

void main() async {
  print('🧪 Testing bills stream query...');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final firestore = FirebaseFirestore.instance;
    final pharmacyId = 'YsjRywptjvXmX7Hn2ckSI5eu5Rs1';

    print('📡 Testing direct Firestore query...');

    // Test the exact query from getBillsStream
    final snapshot = await firestore
        .collection('pharmacy_bills')
        .where('pharmacyId', isEqualTo: pharmacyId)
        .get();

    print('✅ Query succeeded! Found ${snapshot.docs.length} bills');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      print('📋 Bill: ${data['billNumber']} - ${data['timestamp']}');
    }
  } catch (e) {
    print('❌ Query failed: $e');
  }
}
