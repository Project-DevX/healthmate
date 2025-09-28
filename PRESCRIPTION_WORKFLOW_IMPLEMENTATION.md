# HealthMate Prescription Workflow Implementation Guide

## Overview
This document provides detailed instructions for implementing a complete prescription workflow system connecting doctors, patients, and pharmacies. The implementation includes appointment management, prescription creation, automatic distribution to pharmacies, and pharmacy dashboard integration.

## 🚨 Important Clarification
**Digital Assignment, NOT Email**: When we mention "sending prescriptions to contact.healthcarepharm@gmail.com", this refers to **digital assignment within the system** to the pharmacy account that uses this email address. No physical emails are sent. The prescription data is stored in Firestore and assigned to the pharmacy's account for display in their dashboard.

---

## 🎯 Features to Implement

### 1. **Pharmacy Logout Section**
### 2. **Doctor Appointment Actions (Create Prescription & Assign Lab Report)**
### 3. **Prescription Creation Form**
### 4. **Automatic Prescription Distribution**
### 5. **Pharmacy Prescriptions Dashboard**

---

## 📋 Implementation Plan

## Feature 1: Add Logout Section for Pharmacy

### **Location**: `lib/screens/pharmacy_dashboard_new.dart`

#### **Current State Analysis**
- The current pharmacy dashboard has a settings icon in the AppBar but no explicit logout functionality
- There's a profile page with basic options but needs a proper logout section

#### **Implementation Steps**

##### **Step 1.1: Update Settings Menu**
Add a dedicated settings dialog with logout option:

```dart
void _showSettings(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile Settings'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to profile settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notification Settings'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to notification settings
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showLogoutDialog();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showLogoutDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await _performLogout();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
}

Future<void> _performLogout() async {
  try {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logout failed: $e')),
    );
  }
}
```

##### **Step 1.2: Update Profile Page**
Modify the `_buildProfilePage()` method to include a prominent logout section:

```dart
Widget _buildProfilePage() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        // Profile header
        const CircleAvatar(radius: 50, child: Icon(Icons.local_pharmacy, size: 50)),
        const SizedBox(height: 16),
        const Text(
          'HealthCare Pharmacy',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Text('License: #PHM12345'),
        const SizedBox(height: 24),
        
        // Profile options
        _buildProfileOption('Edit Profile', Icons.edit, () {}),
        _buildProfileOption('Business Hours', Icons.schedule, () {}),
        _buildProfileOption('Notifications', Icons.notifications, () {}),
        _buildProfileOption('Reports', Icons.analytics, () {}),
        _buildProfileOption('Settings', Icons.settings, () {}),
        _buildProfileOption('Help & Support', Icons.help, () {}),
        
        const SizedBox(height: 16),
        
        // Logout Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.logout, color: Colors.red, size: 32),
              const SizedBox(height: 8),
              const Text(
                'Logout',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _showLogoutDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

---

## Feature 2: Doctor Appointment Actions

### **Location**: `lib/screens/doctor_appointments_screen.dart`

#### **Implementation Steps**

##### **Step 2.1: Modify Upcoming Appointments Card**
Update the appointment card to show action buttons for upcoming appointments:

```dart
Widget _buildAppointmentCard(QueryDocumentSnapshot appointment) {
  final data = appointment.data() as Map<String, dynamic>;
  final appointmentDate = (data['appointmentDate'] as Timestamp).toDate();
  final status = data['status'] ?? 'scheduled';
  final now = DateTime.now();
  final isUpcoming = appointmentDate.isAfter(now) && status == 'scheduled';
  
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Existing appointment details...
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['patientName'] ?? 'Unknown Patient',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text('Time: ${data['timeSlot'] ?? 'Not specified'}'),
                    Text('Reason: ${data['reason'] ?? 'General consultation'}'),
                  ],
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          
          // Action buttons for upcoming appointments
          if (isUpcoming) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPrescriptionOption(appointment),
                    icon: const Icon(Icons.medication, size: 18),
                    label: const Text('Create Prescription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showLabReportOption(appointment),
                    icon: const Icon(Icons.science, size: 18),
                    label: const Text('Assign Lab Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.infoBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
```

##### **Step 2.2: Add Action Methods**

```dart
void _showPrescriptionOption(QueryDocumentSnapshot appointment) {
  final data = appointment.data() as Map<String, dynamic>;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create Prescription'),
      content: Text('Create a new prescription for ${data['patientName']}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _navigateToPrescriptionForm(appointment);
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

void _showLabReportOption(QueryDocumentSnapshot appointment) {
  final data = appointment.data() as Map<String, dynamic>;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Assign Lab Report'),
      content: Text('Assign lab tests for ${data['patientName']}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _navigateToLabReportForm(appointment);
          },
          child: const Text('Assign'),
        ),
      ],
    ),
  );
}

void _navigateToPrescriptionForm(QueryDocumentSnapshot appointment) {
  final data = appointment.data() as Map<String, dynamic>;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PrescriptionsScreen(
        doctorId: widget.doctorId,
        patientId: data['patientId'],
        patientName: data['patientName'],
        appointmentId: appointment.id,
      ),
    ),
  );
}

void _navigateToLabReportForm(QueryDocumentSnapshot appointment) {
  final data = appointment.data() as Map<String, dynamic>;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => LabReportsScreen(
        doctorId: widget.doctorId,
        patientId: data['patientId'],
        patientName: data['patientName'],
        appointmentId: appointment.id,
      ),
    ),
  );
}
```

---

## Feature 3: Enhanced Prescription Creation Form

### **Location**: `lib/screens/prescriptions_screen.dart`

#### **Implementation Steps**

##### **Step 3.1: Update Prescription Data Model**
Create a comprehensive prescription model in `lib/models/prescription_models.dart`:

```dart
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

  PrescriptionMedicine({
    String? name,
    String? dosage,
    String? frequency,
    String? duration,
    String? instructions,
    String? quantity,
  }) : 
    nameController = TextEditingController(text: name),
    dosageController = TextEditingController(text: dosage),
    frequencyController = TextEditingController(text: frequency),
    durationController = TextEditingController(text: duration),
    instructionsController = TextEditingController(text: instructions),
    quantityController = TextEditingController(text: quantity);

  Map<String, dynamic> toMap() {
    return {
      'name': nameController.text.trim(),
      'dosage': dosageController.text.trim(),
      'frequency': frequencyController.text.trim(),
      'duration': durationController.text.trim(),
      'instructions': instructionsController.text.trim(),
      'quantity': int.tryParse(quantityController.text.trim()) ?? 1,
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
```

##### **Step 3.2: Update Prescription Form**
Enhance the prescription form in `_savePrescription()` method:

```dart
Future<void> _savePrescription() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    // Get doctor details
    final doctorDoc = await _firestore.collection('users').doc(widget.doctorId).get();
    final doctorData = doctorDoc.data();
    final doctorName = doctorData?['fullName'] ?? 'Doctor';

    // Get patient details 
    final patientDoc = await _firestore.collection('users').doc(_patientIdController.text.trim()).get();
    final patientData = patientDoc.data();
    final patientEmail = patientData?['email'] ?? '';

    // Default pharmacy (digital assignment, not email delivery)
    const pharmacyEmail = 'contact.healthcarepharm@gmail.com';
    
    // Get pharmacy ID from email to assign prescription to their account
    final pharmacyQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: pharmacyEmail)
        .where('userType', isEqualTo: 'pharmacy')
        .get();
    
    String pharmacyId = '';
    if (pharmacyQuery.docs.isNotEmpty) {
      pharmacyId = pharmacyQuery.docs.first.id;
    }

    final prescriptionData = {
      'doctorId': widget.doctorId,
      'doctorName': doctorName,
      'patientId': _patientIdController.text.trim(),
      'patientName': _patientNameController.text.trim(),
      'patientEmail': patientEmail,
      'appointmentId': widget.appointmentId,
      'diagnosis': _diagnosisController.text.trim(),
      'notes': _notesController.text.trim(),
      'medicines': _medications.map((med) => med.toMap()).toList(),
      'prescriptionDate': FieldValue.serverTimestamp(),
      'status': 'prescribed',
      'pharmacyId': pharmacyId,
      'pharmacyEmail': pharmacyEmail,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Save to prescriptions collection
    final prescriptionRef = await _firestore.collection('prescriptions').add(prescriptionData);

    // Add prescription to patient's profile
    await _firestore.collection('users').doc(_patientIdController.text.trim()).update({
      'prescriptions': FieldValue.arrayUnion([prescriptionRef.id]),
    });

    // Send notification to patient
    await _sendNotificationToPatient(
      patientId: _patientIdController.text.trim(),
      patientName: _patientNameController.text.trim(),
      doctorName: doctorName,
      prescriptionId: prescriptionRef.id,
    );

    // Send notification to pharmacy
    await _sendNotificationToPharmacy(
      pharmacyId: pharmacyId,
      patientName: _patientNameController.text.trim(),
      doctorName: doctorName,
      prescriptionId: prescriptionRef.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription created and sent successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating prescription: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

Future<void> _sendNotificationToPatient({
  required String patientId,
  required String patientName,
  required String doctorName,
  required String prescriptionId,
}) async {
  await _firestore.collection('notifications').add({
    'recipientId': patientId,
    'recipientType': 'patient',
    'title': 'New Prescription',
    'message': 'Dr. $doctorName has prescribed medications for you',
    'type': 'prescription',
    'relatedId': prescriptionId,
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _sendNotificationToPharmacy({
  required String pharmacyId,
  required String patientName,
  required String doctorName,
  required String prescriptionId,
}) async {
  await _firestore.collection('notifications').add({
    'recipientId': pharmacyId,
    'recipientType': 'pharmacy',
    'title': 'New Prescription',
    'message': 'Dr. $doctorName has sent a prescription for $patientName',
    'type': 'prescription',
    'relatedId': prescriptionId,
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
```

##### **Step 3.3: Enhanced Medicine Form Fields**
Update the medication form to match pharmacy samples:

```dart
Widget _buildMedicationFields(int index) {
  final medication = _medications[index];
  
  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Medication ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (index > 0)
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () => _removeMedicationField(index),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Medicine Name (with suggestions)
          TextFormField(
            controller: medication.nameController,
            decoration: const InputDecoration(
              labelText: 'Medicine Name *',
              hintText: 'e.g., Amoxicillin, Paracetamol',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Medicine name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          
          // Dosage and Quantity row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: medication.dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage *',
                    hintText: 'e.g., 500mg, 10ml',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Dosage is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: medication.quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity *',
                    hintText: '30',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Quantity required';
                    }
                    if (int.tryParse(value!) == null) {
                      return 'Enter valid number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Frequency and Duration row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: medication.frequencyController,
                  decoration: const InputDecoration(
                    labelText: 'Frequency *',
                    hintText: '3 times daily',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Frequency is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: medication.durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration *',
                    hintText: '7 days',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Duration is required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Special Instructions
          TextFormField(
            controller: medication.instructionsController,
            decoration: const InputDecoration(
              labelText: 'Special Instructions',
              hintText: 'Take with food, after meals, etc.',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
    ),
  );
}
```

---

## Feature 4: Automatic Prescription Distribution

### **Location**: Create new service `lib/services/prescription_service.dart`

#### **Implementation Steps**

##### **Step 4.1: Create Prescription Service**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrescriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static Future<String> createAndDistributePrescription({
    required String doctorId,
    required String doctorName,
    required String patientId,
    required String patientName,
    required String patientEmail,
    required List<Map<String, dynamic>> medicines,
    required String diagnosis,
    required String notes,
    String? appointmentId,
  }) async {
    try {
      // Default pharmacy configuration
      const defaultPharmacyEmail = 'contact.healthcarepharm@gmail.com';
      
      // Get pharmacy details
      final pharmacyQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: defaultPharmacyEmail)
          .where('userType', isEqualTo: 'pharmacy')
          .get();
      
      String pharmacyId = '';
      String pharmacyName = 'HealthCare Pharmacy';
      
      if (pharmacyQuery.docs.isNotEmpty) {
        final pharmacyData = pharmacyQuery.docs.first.data();
        pharmacyId = pharmacyQuery.docs.first.id;
        pharmacyName = pharmacyData['institutionName'] ?? pharmacyName;
      }

      // Generate order number for pharmacy
      final orderNumber = await _generateOrderNumber();

      // Create prescription document
      final prescriptionData = {
        'doctorId': doctorId,
        'doctorName': doctorName,
        'patientId': patientId,
        'patientName': patientName,
        'patientEmail': patientEmail,
        'patientPhone': '', // Can be fetched from patient document if needed
        'patientAge': 0, // Can be calculated from patient data
        'appointmentId': appointmentId,
        'medicines': medicines,
        'diagnosis': diagnosis,
        'notes': notes,
        'status': 'pending',
        'pharmacyId': pharmacyId,
        'pharmacyEmail': defaultPharmacyEmail,
        'pharmacyName': pharmacyName,
        'orderNumber': orderNumber,
        'prescriptionDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'totalAmount': 0.0, // Will be calculated by pharmacy
      };

      // Save prescription
      final prescriptionRef = await _firestore
          .collection('prescriptions')
          .add(prescriptionData);

      // Update patient's prescription list
      await _firestore.collection('users').doc(patientId).update({
        'prescriptions': FieldValue.arrayUnion([prescriptionRef.id]),
      });

      // Send notifications
      await _sendNotifications(
        prescriptionId: prescriptionRef.id,
        patientId: patientId,
        patientName: patientName,
        doctorName: doctorName,
        pharmacyId: pharmacyId,
      );

      return prescriptionRef.id;
    } catch (e) {
      throw Exception('Failed to create prescription: $e');
    }
  }

  static Future<int> _generateOrderNumber() async {
    final today = DateTime.now();
    final dateStr = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    
    final counterRef = _firestore.collection('counters').doc('prescription_orders_$dateStr');
    
    return await _firestore.runTransaction((transaction) async {
      final counterDoc = await transaction.get(counterRef);
      
      if (!counterDoc.exists) {
        transaction.set(counterRef, {'count': 1});
        return 1;
      } else {
        final currentCount = counterDoc.data()?['count'] ?? 0;
        final newCount = currentCount + 1;
        transaction.update(counterRef, {'count': newCount});
        return newCount;
      }
    });
  }

  static Future<void> _sendNotifications({
    required String prescriptionId,
    required String patientId,
    required String patientName,
    required String doctorName,
    required String pharmacyId,
  }) async {
    final batch = _firestore.batch();

    // Notification to patient
    final patientNotificationRef = _firestore.collection('notifications').doc();
    batch.set(patientNotificationRef, {
      'recipientId': patientId,
      'recipientType': 'patient',
      'title': 'New Prescription Available',
      'message': 'Dr. $doctorName has prescribed medications for you. Your prescription has been sent to the pharmacy.',
      'type': 'prescription',
      'relatedId': prescriptionId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notification to pharmacy
    if (pharmacyId.isNotEmpty) {
      final pharmacyNotificationRef = _firestore.collection('notifications').doc();
      batch.set(pharmacyNotificationRef, {
        'recipientId': pharmacyId,
        'recipientType': 'pharmacy',
        'title': 'New Prescription Received',
        'message': 'New prescription from Dr. $doctorName for patient $patientName',
        'type': 'prescription',
        'relatedId': prescriptionId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  static Stream<List<Map<String, dynamic>>> getPrescriptionsForPharmacy(String pharmacyId) {
    return _firestore
        .collection('prescriptions')
        .where('pharmacyId', isEqualTo: pharmacyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}
```

---

## Feature 5: Pharmacy Prescriptions Dashboard Integration

### **Location**: `lib/screens/pharmacy_dashboard_new.dart`

#### **Implementation Steps**

##### **Step 5.1: Update Prescriptions Stream**
Modify the prescriptions page to show real-time prescriptions:

```dart
Widget _buildPrescriptionsPage() {
  return Column(
    children: [
      // Search and Filter Section
      Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search prescriptions, patients, doctors...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  _buildFilterChip('Pending', 'pending'),
                  _buildFilterChip('Processing', 'processing'),
                  _buildFilterChip('Ready', 'ready'),
                  _buildFilterChip('Delivered', 'delivered'),
                ],
              ),
            ),
          ],
        ),
      ),
      
      // Prescriptions List
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: PrescriptionService.getPrescriptionsForPharmacy(
            FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final allPrescriptions = snapshot.data ?? [];
            final filteredPrescriptions = _filterPrescriptions(allPrescriptions);

            if (filteredPrescriptions.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.medical_services, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No prescriptions found'),
                    Text('Prescriptions will appear here when doctors send them'),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredPrescriptions.length,
              itemBuilder: (context, index) {
                final prescription = filteredPrescriptions[index];
                return _buildEnhancedPrescriptionCard(prescription);
              },
            );
          },
        ),
      ),
    ],
  );
}

List<Map<String, dynamic>> _filterPrescriptions(List<Map<String, dynamic>> prescriptions) {
  return prescriptions.where((prescription) {
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final patientName = (prescription['patientName'] ?? '').toLowerCase();
      final doctorName = (prescription['doctorName'] ?? '').toLowerCase();
      final orderNumber = (prescription['orderNumber'] ?? 0).toString();
      
      if (!patientName.contains(_searchQuery) && 
          !doctorName.contains(_searchQuery) && 
          !orderNumber.contains(_searchQuery)) {
        return false;
      }
    }
    
    // Filter by status
    if (_selectedFilter != 'all') {
      final status = prescription['status'] ?? 'pending';
      if (status != _selectedFilter) {
        return false;
      }
    }
    
    return true;
  }).toList();
}

Widget _buildEnhancedPrescriptionCard(Map<String, dynamic> prescription) {
  final status = prescription['status'] ?? 'pending';
  final medicines = prescription['medicines'] as List<dynamic>? ?? [];
  final prescriptionDate = prescription['prescriptionDate'] as Timestamp?;
  final orderNumber = prescription['orderNumber'] ?? 0;

  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with order number and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${orderNumber.toString().padLeft(3, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          
          // Patient and Doctor Info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '👤 ${prescription['patientName'] ?? 'Unknown Patient'}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text('👨‍⚕️ Dr. ${prescription['doctorName'] ?? 'Unknown Doctor'}'),
                    if (prescriptionDate != null)
                      Text(
                        '📅 ${DateFormat('MMM dd, yyyy - hh:mm a').format(prescriptionDate.toDate())}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Medicines List
          const Text(
            'Prescribed Medicines:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...medicines.take(3).map((medicine) {
            return Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text('• ${medicine['name']} (${medicine['dosage']}) - Qty: ${medicine['quantity']}'),
            );
          }),
          if (medicines.length > 3)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                '... and ${medicines.length - 3} more medicines',
                style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == 'pending')
                ElevatedButton(
                  onPressed: () => _updatePrescriptionStatus(
                    prescription['id'],
                    'processing',
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Start Processing'),
                ),
              if (status == 'processing')
                ElevatedButton(
                  onPressed: () => _updatePrescriptionStatus(
                    prescription['id'],
                    'ready',
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Mark Ready'),
                ),
              if (status == 'ready')
                ElevatedButton(
                  onPressed: () => _updatePrescriptionStatus(
                    prescription['id'],
                    'delivered',
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Mark Delivered'),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () => _showPrescriptionDetails(prescription),
              ),
              IconButton(
                icon: const Icon(Icons.receipt),
                onPressed: () => _generateBill(prescription),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildStatusChip(String status) {
  Color backgroundColor;
  Color textColor;
  String displayText;

  switch (status.toLowerCase()) {
    case 'pending':
      backgroundColor = Colors.orange.withOpacity(0.2);
      textColor = Colors.orange[800]!;
      displayText = 'Pending';
      break;
    case 'processing':
      backgroundColor = Colors.blue.withOpacity(0.2);
      textColor = Colors.blue[800]!;
      displayText = 'Processing';
      break;
    case 'ready':
      backgroundColor = Colors.purple.withOpacity(0.2);
      textColor = Colors.purple[800]!;
      displayText = 'Ready';
      break;
    case 'delivered':
      backgroundColor = Colors.green.withOpacity(0.2);
      textColor = Colors.green[800]!;
      displayText = 'Delivered';
      break;
    default:
      backgroundColor = Colors.grey.withOpacity(0.2);
      textColor = Colors.grey[800]!;
      displayText = status.toUpperCase();
  }

  return Chip(
    label: Text(
      displayText,
      style: TextStyle(color: textColor, fontSize: 12),
    ),
    backgroundColor: backgroundColor,
  );
}

Future<void> _updatePrescriptionStatus(String prescriptionId, String newStatus) async {
  try {
    await FirebaseFirestore.instance
        .collection('prescriptions')
        .doc(prescriptionId)
        .update({
      'status': newStatus,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Prescription status updated to $newStatus'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error updating status: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void _showPrescriptionDetails(Map<String, dynamic> prescription) {
  final medicines = prescription['medicines'] as List<dynamic>? ?? [];
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Prescription #${prescription['orderNumber']}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Patient: ${prescription['patientName']}'),
            Text('Doctor: Dr. ${prescription['doctorName']}'),
            if (prescription['diagnosis'] != null && prescription['diagnosis'].isNotEmpty)
              Text('Diagnosis: ${prescription['diagnosis']}'),
            const SizedBox(height: 16),
            const Text('Medicines:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...medicines.map((medicine) {
              return Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ${medicine['name']} (${medicine['dosage']})'),
                    Text('  Quantity: ${medicine['quantity']}'),
                    Text('  Frequency: ${medicine['frequency']}'),
                    Text('  Duration: ${medicine['duration']}'),
                    if (medicine['instructions'] != null && medicine['instructions'].isNotEmpty)
                      Text('  Instructions: ${medicine['instructions']}'),
                  ],
                ),
              );
            }),
            if (prescription['notes'] != null && prescription['notes'].isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(prescription['notes']),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
```

---

## 🔧 Additional Configuration Steps

### **Step 1: Update Firebase Security Rules**
Add these rules to Firestore to ensure proper access:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Prescriptions collection
    match /prescriptions/{prescriptionId} {
      allow read, write: if request.auth != null && (
        request.auth.uid == resource.data.doctorId ||
        request.auth.uid == resource.data.patientId ||
        request.auth.uid == resource.data.pharmacyId
      );
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.doctorId;
    }
    
    // Notifications collection
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.recipientId;
      allow create: if request.auth != null;
    }
    
    // Counters collection
    match /counters/{counterId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### **Step 2: Update Dependencies**
Add to `pubspec.yaml`:

```yaml
dependencies:
  intl: ^0.19.0
  uuid: ^4.0.0
```

### **Step 3: Test Data Setup**
Create test script `lib/utils/create_test_prescriptions.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/prescription_service.dart';

Future<void> createTestPrescriptions() async {
  // Sample test data for testing the prescription workflow
  final sampleMedicines = [
    {
      'name': 'Amoxicillin',
      'dosage': '500mg',
      'frequency': '3 times daily',
      'duration': '7 days',
      'quantity': 21,
      'instructions': 'Take with food',
    },
    {
      'name': 'Paracetamol',
      'dosage': '500mg',
      'frequency': '4 times daily',
      'duration': '5 days',
      'quantity': 20,
      'instructions': 'Take as needed for fever',
    },
  ];

  try {
    await PrescriptionService.createAndDistributePrescription(
      doctorId: 'doctor_test_id',
      doctorName: 'Dr. Sarah Wilson',
      patientId: 'patient_test_id',
      patientName: 'John Doe',
      patientEmail: 'john.doe@example.com',
      medicines: sampleMedicines,
      diagnosis: 'Upper respiratory tract infection',
      notes: 'Follow up in 1 week if symptoms persist',
    );
    
    print('✅ Test prescription created successfully');
  } catch (e) {
    print('❌ Error creating test prescription: $e');
  }
}
```

---

## 🚀 Testing Guide

### **Testing Checklist**

1. **Pharmacy Logout**
   - [ ] Settings button shows logout option
   - [ ] Logout dialog appears with confirmation
   - [ ] Successful logout redirects to login page
   - [ ] Profile page shows logout section

2. **Doctor Appointment Actions**
   - [ ] Upcoming appointments show action buttons
   - [ ] "Create Prescription" button appears for scheduled appointments
   - [ ] "Assign Lab Report" button appears for scheduled appointments
   - [ ] Buttons navigate to respective forms

3. **Prescription Creation**
   - [ ] Form pre-fills patient information from appointment
   - [ ] Medicine fields validate required information
   - [ ] Form saves prescription to Firestore
   - [ ] Notifications sent to patient and pharmacy
   - [ ] Success message displayed

4. **Automatic Distribution**
   - [ ] Prescription appears in pharmacy dashboard
   - [ ] Order number generated correctly
   - [ ] Patient receives notification
   - [ ] Pharmacy receives notification

5. **Pharmacy Dashboard**
   - [ ] Real-time prescription updates
   - [ ] Status filtering works
   - [ ] Search functionality works
   - [ ] Status updates work correctly
   - [ ] Bill generation works

---

## 🛟 Troubleshooting

### **Common Issues & Solutions**

1. **Prescription not appearing in pharmacy dashboard**
   - Verify pharmacy email exists in users collection
   - Check Firestore security rules
   - Ensure pharmacyId is correctly set

2. **Notifications not working**
   - Verify notifications collection exists
   - Check recipient IDs are correct
   - Ensure proper user types in database

3. **Order number not generating**
   - Check counters collection permissions
   - Verify date formatting in counter document ID

4. **Status updates failing**
   - Verify Firestore rules allow updates
   - Check prescription document exists
   - Ensure proper error handling

---

## 📝 Questions for Clarification

1. **Pharmacy Selection**: Currently set to digitally assign all prescriptions to the pharmacy account with email `contact.healthcarepharm@gmail.com`. Should doctors be able to select from multiple pharmacies?

2. **Lab Report Integration**: The assign lab report feature navigates to `LabReportsScreen`. Should this integrate with existing lab facilities or create a new workflow?

3. **Prescription Pricing**: Should the system include medicine pricing, or will pharmacies handle all pricing?

4. **Patient Notifications**: Should patients receive notifications via email, SMS, or just in-app notifications?

5. **Prescription Approval**: Should prescriptions require patient approval before being sent to pharmacy?

6. **Multiple Pharmacies**: Should the system support sending prescriptions to multiple pharmacies for price comparison?

Would you like me to modify any part of this implementation or clarify any of these questions?