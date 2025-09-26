// Quick Test: Consent Notification System Verification
// Run this after Firebase index creation to test the notification system

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  print('🧪 TESTING: Consent Notification System');

  // Test the exact query that was failing
  await testConsentNotificationQuery();
}

Future<void> testConsentNotificationQuery() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No authenticated user found');
      return;
    }

    print('🔐 Testing consent notifications for user: ${user.uid}');

    // This is the exact query from patientDashboard.dart that needs the index
    final query = FirebaseFirestore.instance
        .collection('consent_requests')
        .where('patientId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestDate', descending: true)
        .limit(50);

    print('🚀 Executing query...');
    final querySnapshot = await query.get();

    print('✅ Query successful!');
    print('📊 Found ${querySnapshot.docs.length} pending consent requests');

    if (querySnapshot.docs.isNotEmpty) {
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        print(
          '🔔 Pending request: ${data['requestType']} from Dr. ${data['doctorName']}',
        );
        print('   📅 Requested: ${data['requestDate']}');
        print('   💬 Purpose: ${data['purpose']}');
      }
    } else {
      print('📭 No pending consent requests found');
    }

    // Test the count query for notification badge
    final countSnapshot = await FirebaseFirestore.instance
        .collection('consent_requests')
        .where('patientId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    print('🏷️ Notification badge count: ${countSnapshot.docs.length}');
  } catch (e) {
    if (e.toString().contains('failed-precondition')) {
      print('❌ Index still not ready. Error: $e');
      print('⏱️ Wait 2-3 more minutes for index building to complete');
    } else {
      print('❌ Unexpected error: $e');
    }
  }
}

// Test function to be called from the app
Future<int> getConsentNotificationCount() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final snapshot = await FirebaseFirestore.instance
        .collection('consent_requests')
        .where('patientId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    return snapshot.docs.length;
  } catch (e) {
    print('Error getting notification count: $e');
    return 0;
  }
}
