import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetailedPrescription {
  final String id;
  final String doctorId;
  final String doctorName;
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String? appointmentId;
  final List<PrescriptionMedicine> medicines;
  final String diagnosis;
  final String notes;
  final DateTime prescriptionDate;
  final String status;
  final String pharmacyId;
  final String pharmacyEmail;

  DetailedPrescription({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    this.appointmentId,
    required this.medicines,
    required this.diagnosis,
    required this.notes,
    required this.prescriptionDate,
    required this.status,
    required this.pharmacyId,
    required this.pharmacyEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientId': patientId,
      'patientName': patientName,
      'patientEmail': patientEmail,
      'appointmentId': appointmentId,
      'medicines': medicines.map((m) => m.toMap()).toList(),
      'diagnosis': diagnosis,
      'notes': notes,
      'prescriptionDate': Timestamp.fromDate(prescriptionDate),
      'status': status,
      'pharmacyId': pharmacyId,
      'pharmacyEmail': pharmacyEmail,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class PrescriptionMedicine {
  final TextEditingController nameController;
  final TextEditingController dosageController;
  final TextEditingController frequencyController;
  final TextEditingController durationController;
  final TextEditingController instructionsController;
  final TextEditingController quantityController;
  String? timing;

  PrescriptionMedicine({
    String? name,
    String? dosage,
    String? frequency,
    String? duration,
    String? instructions,
    String? quantity,
    this.timing,
  }) : nameController = TextEditingController(text: name),
       dosageController = TextEditingController(text: dosage),
       frequencyController = TextEditingController(text: frequency),
       durationController = TextEditingController(text: duration),
       instructionsController = TextEditingController(text: instructions),
       quantityController = TextEditingController(text: quantity);

  int calculateQuantity() {
    try {
      // Extract number from frequency (e.g., "3 times daily" -> 3, "twice daily" -> 2)
      final frequencyText = frequencyController.text.trim().toLowerCase();
      int timesPerDay = 1;

      if (frequencyText.contains('once') || frequencyText.contains('1')) {
        timesPerDay = 1;
      } else if (frequencyText.contains('twice') ||
          frequencyText.contains('2')) {
        timesPerDay = 2;
      } else if (frequencyText.contains('3') ||
          frequencyText.contains('thrice')) {
        timesPerDay = 3;
      } else if (frequencyText.contains('4')) {
        timesPerDay = 4;
      } else if (frequencyText.contains('5')) {
        timesPerDay = 5;
      } else if (frequencyText.contains('6')) {
        timesPerDay = 6;
      }

      // Extract number of days from duration (e.g., "7 days" -> 7, "2 weeks" -> 14)
      final durationText = durationController.text.trim().toLowerCase();
      int days = 1;

      if (durationText.contains('week')) {
        final weekMatch = RegExp(r'(\d+)').firstMatch(durationText);
        if (weekMatch != null) {
          days = int.parse(weekMatch.group(1)!) * 7;
        }
      } else {
        final dayMatch = RegExp(r'(\d+)').firstMatch(durationText);
        if (dayMatch != null) {
          days = int.parse(dayMatch.group(1)!);
        }
      }

      return timesPerDay * days;
    } catch (e) {
      return 1; // Default fallback
    }
  }

  void updateQuantity() {
    final calculatedQuantity = calculateQuantity();
    quantityController.text = calculatedQuantity.toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nameController.text.trim(),
      'dosage': dosageController.text.trim(),
      'frequency': frequencyController.text.trim(),
      'duration': durationController.text.trim(),
      'timing': timing ?? '',
      'instructions': instructionsController.text.trim(),
      'quantity':
          int.tryParse(quantityController.text.trim()) ?? calculateQuantity(),
      'price': 0.0, // Will be updated by pharmacy
    };
  }

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    instructionsController.dispose();
    quantityController.dispose();
  }
}
