import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/interconnect_service.dart';
import 'lib/models/shared_models.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  print('🔍 Starting appointment flow debugging...');

  // Doctor ID we're testing with
  const doctorId = '8FLajrsoGGP1nKaxIT8t7nkX5fU2';
  const patientId = 'test-patient-id';

  print('🔍 Step 1: Check existing appointments for doctor $doctorId');

  try {
    final existingAppointments = await FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    print(
      '📋 Found ${existingAppointments.docs.length} existing appointments:',
    );
    for (var doc in existingAppointments.docs) {
      final data = doc.data();
      print('   - ID: ${doc.id}');
      print('     Patient: ${data['patientName']}');
      print('     Date: ${data['appointmentDate']}');
      print('     Status: ${data['status']}');
      print('     Time: ${data['timeSlot']}');
      print('');
    }

    print('🔍 Step 2: Book a new test appointment');

    final testAppointment = Appointment(
      id: '',
      patientId: patientId,
      patientName: 'Test Patient',
      patientEmail: 'test.patient@example.com',
      doctorId: doctorId,
      doctorName: 'Dr. Sarah Wilson',
      doctorSpecialty: 'Cardiology',
      hospitalId: 'test-hospital-id',
      hospitalName: 'City General Hospital',
      appointmentDate: DateTime.now().add(const Duration(hours: 2)),
      timeSlot: '10:00 AM',
      status: 'scheduled',
      reason: 'Test appointment for debugging',
      symptoms: 'Debug test',
      createdAt: DateTime.now(),
      caregiverId: null,
    );

    final appointmentId = await InterconnectService.bookAppointment(
      testAppointment,
    );
    print('✅ Test appointment booked with ID: $appointmentId');

    // Wait a moment for Firestore to update
    await Future.delayed(const Duration(seconds: 2));

    print('🔍 Step 3: Verify appointment appears in doctor\'s appointments');

    final updatedAppointments = await FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    print(
      '📋 Found ${updatedAppointments.docs.length} appointments after booking:',
    );
    for (var doc in updatedAppointments.docs) {
      final data = doc.data();
      print('   - ID: ${doc.id}');
      print('     Patient: ${data['patientName']}');
      print('     Date: ${data['appointmentDate']}');
      print('     Status: ${data['status']}');
      print('     Time: ${data['timeSlot']}');
      if (doc.id == appointmentId) {
        print('     ✅ THIS IS THE NEW APPOINTMENT');
      }
      print('');
    }

    // Check if appointment appears in getUserAppointments
    print('🔍 Step 4: Test InterconnectService.getUserAppointments');
    final serviceAppointments = await InterconnectService.getUserAppointments(
      doctorId,
      'doctor',
    );

    print(
      '📋 InterconnectService returned ${serviceAppointments.length} appointments:',
    );
    for (var appt in serviceAppointments) {
      print('   - ID: ${appt.id}');
      print('     Patient: ${appt.patientName}');
      print('     Date: ${appt.appointmentDate}');
      print('     Status: ${appt.status}');
      print('     Time: ${appt.timeSlot}');
      print('');
    }
  } catch (e) {
    print('❌ Error during debugging: $e');
  }
}
