// Create Sample Medical Records for Testing
// This script creates sample lab reports and prescriptions for testing medical records access

import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('🧪 CREATING: Sample medical records for testing');
  await createSampleMedicalRecords();
}

Future<void> createSampleMedicalRecords() async {
  try {
    const patientId = 'jb88OHVxtQPWgckyiBqTSqUUpsU2'; // Test patient
    const doctorId = '8FLajrsoGGP1nKaxIT8t7nkX5fU2'; // Dr. Sarah Wilson

    print('📋 Creating sample medical records for patient: $patientId');

    final firestore = FirebaseFirestore.instance;

    // 1. Create sample lab reports
    print('\n1️⃣ Creating sample lab reports...');

    final labReport1 = {
      'id': 'lab_${DateTime.now().millisecondsSinceEpoch}_1',
      'patientId': patientId,
      'doctorId': doctorId,
      'testName': 'Complete Blood Count (CBC)',
      'testType': 'Blood Test',
      'testDate': Timestamp.now(),
      'result': 'Normal',
      'status': 'completed',
      'notes': 'All values within normal range',
      'createdAt': Timestamp.now(),
      'reportUrl': null,
    };

    final labReport2 = {
      'id': 'lab_${DateTime.now().millisecondsSinceEpoch}_2',
      'patientId': patientId,
      'doctorId': doctorId,
      'testName': 'Lipid Panel',
      'testType': 'Blood Test',
      'testDate': Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: 30)),
      ),
      'result': 'Slightly Elevated Cholesterol',
      'status': 'completed',
      'notes': 'Total cholesterol: 210 mg/dL (slightly high)',
      'createdAt': Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: 30)),
      ),
      'reportUrl': null,
    };

    await firestore.collection('lab_reports').add(labReport1);
    await firestore.collection('lab_reports').add(labReport2);
    print('   ✅ Created 2 lab reports');

    // 2. Create sample prescriptions
    print('\n2️⃣ Creating sample prescriptions...');

    final prescription1 = {
      'id': 'rx_${DateTime.now().millisecondsSinceEpoch}_1',
      'patientId': patientId,
      'doctorId': doctorId,
      'medicationName': 'Atorvastatin',
      'dosage': '20mg',
      'frequency': 'Once daily',
      'duration': '3 months',
      'prescribedDate': Timestamp.now(),
      'status': 'active',
      'instructions': 'Take with food in the evening',
      'createdAt': Timestamp.now(),
    };

    final prescription2 = {
      'id': 'rx_${DateTime.now().millisecondsSinceEpoch}_2',
      'patientId': patientId,
      'doctorId': doctorId,
      'medicationName': 'Lisinopril',
      'dosage': '10mg',
      'frequency': 'Once daily',
      'duration': '6 months',
      'prescribedDate': Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: 15)),
      ),
      'status': 'active',
      'instructions': 'Take in the morning with water',
      'createdAt': Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: 15)),
      ),
    };

    await firestore.collection('prescriptions').add(prescription1);
    await firestore.collection('prescriptions').add(prescription2);
    print('   ✅ Created 2 prescriptions');

    // 3. Verify appointment exists
    print('\n3️⃣ Checking existing appointments...');
    final appointmentsSnapshot = await firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .where('doctorId', isEqualTo: doctorId)
        .get();

    print('   📅 Found ${appointmentsSnapshot.docs.length} appointments');

    if (appointmentsSnapshot.docs.isEmpty) {
      // Create a sample appointment
      final appointment = {
        'id': 'apt_${DateTime.now().millisecondsSinceEpoch}',
        'patientId': patientId,
        'doctorId': doctorId,
        'patientName': 'Test Patient',
        'doctorName': 'Dr. Sarah Wilson',
        'appointmentDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: 7)),
        ),
        'timeSlot': '2:00 PM',
        'status': 'scheduled',
        'reason': 'Follow-up consultation',
        'createdAt': Timestamp.now(),
      };

      await firestore.collection('appointments').add(appointment);
      print('   ✅ Created 1 sample appointment');
    }

    print('\n🎯 SAMPLE DATA CREATED SUCCESSFULLY!');
    print('📋 Medical records now available for testing:');
    print('   - 2 Lab Reports (CBC, Lipid Panel)');
    print('   - 2 Prescriptions (Atorvastatin, Lisinopril)');
    print(
      '   - ${appointmentsSnapshot.docs.length > 0 ? appointmentsSnapshot.docs.length : 1} Appointment(s)',
    );
    print('\n🚀 Now test the consent approval workflow:');
    print('   1. Doctor requests consent for lab_reports or full_history');
    print('   2. Patient approves the consent request');
    print('   3. Doctor should be able to view medical records');
  } catch (e) {
    print('❌ Failed to create sample data: $e');
  }
}
