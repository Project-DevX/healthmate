import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/shared_models.dart';
import '../lib/services/interconnect_service.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  print('Testing appointment booking functionality...');

  try {
    // Test data - using existing test users from the app
    final patientId = '5rPUtkiWTOZPP53Zg7eo0CPfLyq2'; // John Doe patient
    final doctorId = '8FLajrsoGGP1nKaxIT8t7nkX5fU2'; // Dr. Sarah Wilson

    // Create a test appointment
    final appointment = Appointment(
      id: '',
      patientId: patientId,
      patientName: 'John Doe',
      patientEmail: 'john.doe.patient@gmail.com',
      doctorId: doctorId,
      doctorName: 'Dr. Sarah Wilson',
      doctorSpecialty: 'Cardiology',
      hospitalId: 'test-hospital-id',
      hospitalName: 'City General Hospital',
      appointmentDate: DateTime.now().add(const Duration(days: 1)),
      timeSlot: '10:00 AM',
      status: 'scheduled',
      reason: 'Regular checkup',
      symptoms: 'Mild chest pain',
      createdAt: DateTime.now(),
      caregiverId: null,
    );

    print('Booking appointment...');
    final appointmentId = await InterconnectService.bookAppointment(
      appointment,
    );
    print('✅ Appointment booked successfully with ID: $appointmentId');

    // Wait a moment for Firestore to update
    await Future.delayed(const Duration(seconds: 2));

    // Verify appointment appears in doctor's appointments
    print('Verifying appointment appears in doctor\'s appointments...');
    final doctorAppointments = await InterconnectService.getUserAppointments(
      doctorId,
      'doctor',
    );

    final bookedAppointment = doctorAppointments.firstWhere(
      (appt) => appt.id == appointmentId,
      orElse: () => throw Exception('Appointment not found in doctor\'s list'),
    );

    print('✅ Appointment found in doctor\'s appointments');
    print('   Patient: ${bookedAppointment.patientName}');
    print('   Date: ${bookedAppointment.appointmentDate}');
    print('   Time: ${bookedAppointment.timeSlot}');
    print('   Status: ${bookedAppointment.status}');
    print('   Reason: ${bookedAppointment.reason}');

    // Verify appointment appears in patient's appointments
    print('Verifying appointment appears in patient\'s appointments...');
    final patientAppointments = await InterconnectService.getUserAppointments(
      patientId,
      'patient',
    );

    final patientBookedAppointment = patientAppointments.firstWhere(
      (appt) => appt.id == appointmentId,
      orElse: () => throw Exception('Appointment not found in patient\'s list'),
    );

    print('✅ Appointment found in patient\'s appointments');
    print('   Doctor: ${patientBookedAppointment.doctorName}');
    print('   Specialty: ${patientBookedAppointment.doctorSpecialty}');
    print('   Hospital: ${patientBookedAppointment.hospitalName}');

    print('\n🎉 All appointment booking tests passed!');
  } catch (e) {
    print('❌ Test failed: $e');
    rethrow;
  }
}
