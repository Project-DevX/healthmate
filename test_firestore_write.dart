import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

void main() async {
  print('🧪 Testing Firestore write to appointments collection...');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('🧪 Firebase initialized successfully');

    final firestore = FirebaseFirestore.instance;

    // Test data
    final testAppointment = {
      'patientId': 'test-patient-id',
      'patientName': 'Test Patient',
      'patientEmail': 'test@example.com',
      'doctorId': 'test-doctor-id',
      'doctorName': 'Test Doctor',
      'doctorSpecialty': 'Test Specialty',
      'hospitalId': 'test-hospital-id',
      'hospitalName': 'Test Hospital',
      'appointmentDate': Timestamp.now(),
      'timeSlot': '10:00 AM',
      'status': 'scheduled',
      'reason': 'Test appointment',
      'createdAt': Timestamp.now(),
    };

    print('🧪 Attempting to write test appointment...');
    final docRef = await firestore
        .collection('appointments')
        .add(testAppointment);

    print('🧪 ✅ SUCCESS! Test appointment created with ID: ${docRef.id}');

    // Verify it was written
    final doc = await docRef.get();
    if (doc.exists) {
      print('🧪 ✅ Verified: Document exists and can be read back');
      print('🧪 Data: ${doc.data()}');
    } else {
      print('🧪 ❌ ERROR: Document was not found after creation');
    }

    // Clean up - delete the test document
    await docRef.delete();
    print('🧪 🧹 Test document cleaned up');
  } catch (e) {
    print('🧪 ❌ ERROR: $e');
    print('🧪 Stack trace: ${StackTrace.current}');
  }

  exit(0);
}
