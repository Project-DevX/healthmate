// Simple test script to book an appointment for Dr. Sarah Wilson
// Run this with: flutter run -t test_appointment_simple.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AppointmentTester(),
    );
  }
}

class AppointmentTester extends StatefulWidget {
  @override
  _AppointmentTesterState createState() => _AppointmentTesterState();
}

class _AppointmentTesterState extends State<AppointmentTester> {
  String status = 'Ready to test...';
  List<Map<String, dynamic>> appointments = [];

  final String doctorId = '8FLajrsoGGP1nKaxIT8t7nkX5fU2'; // Dr. Sarah Wilson's ID
  final String patientId = 'test-patient-123';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Appointment Flow Tester')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $status', style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: checkExistingAppointments,
              child: Text('1. Check Existing Appointments'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: bookTestAppointment,
              child: Text('2. Book Test Appointment'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: verifyAppointmentExists,
              child: Text('3. Verify Appointment in Database'),
            ),
            SizedBox(height: 20),
            Text('Appointments found:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: appointments.length,
                itemBuilder: (context, index) {
                  final appt = appointments[index];
                  return Card(
                    child: ListTile(
                      title: Text('${appt['patientName']} - ${appt['timeSlot']}'),
                      subtitle: Text('${appt['appointmentDate']} - Status: ${appt['status']}'),
                      trailing: Text('ID: ${appt['id']}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> checkExistingAppointments() async {
    setState(() => status = 'Checking existing appointments...');
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .get();
      
      setState(() {
        appointments = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        status = 'Found ${appointments.length} existing appointments for doctor $doctorId';
      });
      
      print('🔍 Found ${appointments.length} appointments:');
      for (var appt in appointments) {
        print('   - ${appt['patientName']} at ${appt['timeSlot']} on ${appt['appointmentDate']}');
      }
    } catch (e) {
      setState(() => status = 'Error checking appointments: $e');
      print('❌ Error: $e');
    }
  }

  Future<void> bookTestAppointment() async {
    setState(() => status = 'Booking test appointment...');
    
    try {
      // Create appointment for tomorrow at 10:00 AM
      final tomorrow = DateTime.now().add(Duration(days: 1));
      final appointmentDateTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);
      
      final appointmentData = {
        'patientId': patientId,
        'patientName': 'Test Patient',
        'patientEmail': 'test.patient@example.com',
        'doctorId': doctorId,
        'doctorName': 'Dr. Sarah Wilson',
        'doctorSpecialty': 'Cardiology',
        'hospitalId': 'test-hospital-123',
        'hospitalName': 'City General Hospital',
        'appointmentDate': Timestamp.fromDate(appointmentDateTime),
        'timeSlot': '10:00 AM',
        'status': 'scheduled',
        'reason': 'Test appointment for debugging',
        'symptoms': 'Testing appointment flow',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'caregiverId': null,
      };
      
      final docRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);
      
      setState(() => status = 'Test appointment booked with ID: ${docRef.id}');
      print('✅ Appointment booked: ${docRef.id}');
      
      // Refresh the appointments list
      await checkExistingAppointments();
      
    } catch (e) {
      setState(() => status = 'Error booking appointment: $e');
      print('❌ Error booking: $e');
    }
  }

  Future<void> verifyAppointmentExists() async {
    setState(() => status = 'Verifying appointments in database...');
    
    await checkExistingAppointments();
    
    if (appointments.isNotEmpty) {
      setState(() => status = 'SUCCESS: ${appointments.length} appointments found in database!');
    } else {
      setState(() => status = 'ISSUE: No appointments found for doctor $doctorId');
    }
  }
}