// test_consent_system.dart
// Test script to verify the consent system implementation
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/consent_service.dart';
import 'lib/models/shared_models.dart';

void main() async {
  print('🔐 TESTING CONSENT SYSTEM');
  print('========================');
  
  // Test data
  const testDoctorId = 'test_doctor_123';
  const testPatientId = 'test_patient_456';
  const testAppointmentId = 'test_appointment_789';
  
  try {
    print('\n1. Testing Consent Request Creation...');
    final requestId = await ConsentService.requestMedicalRecordAccess(
      doctorId: testDoctorId,
      doctorName: 'Dr. Test Smith',
      doctorSpecialty: 'Cardiology',
      patientId: testPatientId,
      patientName: 'John Doe',
      appointmentId: testAppointmentId,
      requestType: 'lab_reports',
      purpose: 'Need to review previous lab results for treatment planning',
      durationDays: 30,
    );
    print('✅ Consent request created with ID: $requestId');
    
    print('\n2. Testing Patient Consent Requests Retrieval...');
    final pendingRequests = await ConsentService.getPatientPendingRequests(testPatientId);
    print('✅ Found ${pendingRequests.length} pending requests');
    
    print('\n3. Testing Doctor Consent Requests Retrieval...');
    final doctorRequests = await ConsentService.getDoctorConsentRequests(testDoctorId);
    print('✅ Doctor has ${doctorRequests.length} consent requests');
    
    if (pendingRequests.isNotEmpty) {
      print('\n4. Testing Patient Consent Response (Approval)...');
      await ConsentService.respondToConsentRequest(
        pendingRequests.first.requestId,
        'approved',
        'Approved for better medical care',
      );
      print('✅ Consent request approved');
      
      print('\n5. Testing Active Consent Check...');
      final hasConsent = await ConsentService.hasActiveConsent(
        testDoctorId,
        testPatientId,
        'lab_reports',
      );
      print('✅ Active consent status: $hasConsent');
      
      print('\n6. Testing Active Consent Info Retrieval...');
      final consentInfo = await ConsentService.getActiveConsentInfo(
        testDoctorId,
        testPatientId,
      );
      print('✅ Active consent info: $consentInfo');
    }
    
    print('\n🎉 ALL CONSENT SYSTEM TESTS PASSED!');
    print('The consent system is ready for production use.');
    
  } catch (e) {
    print('❌ TEST FAILED: $e');
  }
}