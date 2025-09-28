import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Initialize Firestore (this won't work without proper Firebase setup but shows the logic)
  final firestore = FirebaseFirestore.instance;

  print('🔍 DEBUG: Checking prescriptions and bills data...');

  try {
    // Check prescriptions collection
    print('\n📋 PRESCRIPTIONS:');
    final prescriptionsQuery = await firestore
        .collection('prescriptions')
        .limit(3)
        .get();

    for (final doc in prescriptionsQuery.docs) {
      final data = doc.data();
      print('Prescription ID: ${doc.id}');
      print('  - Patient Name: ${data['patientName'] ?? 'NOT FOUND'}');
      print('  - Doctor Name: ${data['doctorName'] ?? 'NOT FOUND'}');
      print(
        '  - Doctor Specialization: ${data['doctorSpecialization'] ?? 'NOT FOUND'}',
      );
      print('  - Doctor Hospital: ${data['doctorHospital'] ?? 'NOT FOUND'}');
      print('  - Patient Age: ${data['patientAge'] ?? 'NOT FOUND'}');
      print('  - Patient Phone: ${data['patientPhone'] ?? 'NOT FOUND'}');
      print('  ---');
    }

    // Check bills collection
    print('\n💰 BILLS:');
    final billsQuery = await firestore
        .collection('pharmacy_bills')
        .limit(3)
        .get();

    for (final doc in billsQuery.docs) {
      final data = doc.data();
      print('Bill ID: ${doc.id}');
      print('  - Bill Number: ${data['billNumber'] ?? 'NOT FOUND'}');
      print('  - Patient Name: ${data['patientName'] ?? 'NOT FOUND'}');

      // Check patientInfo object
      final patientInfo = data['patientInfo'] as Map<String, dynamic>?;
      if (patientInfo != null) {
        print('  - PatientInfo.name: ${patientInfo['name'] ?? 'NOT FOUND'}');
        print('  - PatientInfo.age: ${patientInfo['age'] ?? 'NOT FOUND'}');
        print('  - PatientInfo.phone: ${patientInfo['phone'] ?? 'NOT FOUND'}');
      } else {
        print('  - PatientInfo: NULL');
      }

      // Check doctorInfo object
      final doctorInfo = data['doctorInfo'] as Map<String, dynamic>?;
      if (doctorInfo != null) {
        print('  - DoctorInfo.name: ${doctorInfo['name'] ?? 'NOT FOUND'}');
        print(
          '  - DoctorInfo.specialization: ${doctorInfo['specialization'] ?? 'NOT FOUND'}',
        );
        print(
          '  - DoctorInfo.hospital: ${doctorInfo['hospital'] ?? 'NOT FOUND'}',
        );
      } else {
        print('  - DoctorInfo: NULL');
      }
      print('  ---');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
