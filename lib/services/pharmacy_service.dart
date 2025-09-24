import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PharmacyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's pharmacy ID
  String? get currentPharmacyId => _auth.currentUser?.uid;

  /// Get current order number for the pharmacy
  Future<String> getCurrentOrderNumber() async {
    try {
      final today = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(today);

      final orderDoc = await _firestore
          .collection('pharmacy_orders')
          .doc(currentPharmacyId)
          .collection('daily_orders')
          .doc(dateKey)
          .get();

      if (orderDoc.exists) {
        final data = orderDoc.data()!;
        return (data['currentOrderNumber'] ?? 1).toString().padLeft(3, '0');
      } else {
        // Initialize for today
        await _firestore
            .collection('pharmacy_orders')
            .doc(currentPharmacyId)
            .collection('daily_orders')
            .doc(dateKey)
            .set({'currentOrderNumber': 1, 'date': today, 'totalOrders': 0});
        return '001';
      }
    } catch (e) {
      print('Error getting order number: $e');
      return '001';
    }
  }

  /// Increment order number
  Future<void> incrementOrderNumber() async {
    try {
      final today = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(today);

      final orderDocRef = _firestore
          .collection('pharmacy_orders')
          .doc(currentPharmacyId)
          .collection('daily_orders')
          .doc(dateKey);

      await _firestore.runTransaction((transaction) async {
        final orderDoc = await transaction.get(orderDocRef);

        if (orderDoc.exists) {
          final currentNumber = orderDoc.data()!['currentOrderNumber'] ?? 0;
          transaction.update(orderDocRef, {
            'currentOrderNumber': currentNumber + 1,
            'totalOrders': FieldValue.increment(1),
          });
        } else {
          transaction.set(orderDocRef, {
            'currentOrderNumber': 2,
            'date': today,
            'totalOrders': 1,
          });
        }
      });
    } catch (e) {
      print('Error incrementing order number: $e');
    }
  }

  // Get prescriptions for pharmacy
  Future<List<PharmacyPrescription>> getPrescriptions() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where(
            'pharmacyId',
            isEqualTo: FirebaseAuth.instance.currentUser?.uid,
          )
          .get();

      final prescriptions = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return PharmacyPrescription(
          id: doc.id,
          orderNumber: data['orderNumber'] ?? 0,
          pharmacyId: data['pharmacyId'] ?? '',
          timestamp:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          patientInfo: PatientInfo(
            id: data['patientId'] ?? '',
            name: data['patientName'] ?? '',
            phone: data['patientPhone'] ?? '',
            email: data['patientEmail'] ?? '',
            age: data['patientAge'] ?? 0,
          ),
          doctorInfo: DoctorInfo(
            id: data['doctorId'] ?? '',
            name: data['doctorName'] ?? '',
            specialization: data['doctorSpecialization'] ?? '',
            hospital: data['doctorHospital'] ?? '',
          ),
          medicines: (data['medicines'] as List<dynamic>? ?? [])
              .map(
                (med) => Medicine(
                  id: med['id'] ?? '',
                  name: med['name'] ?? '',
                  dosage: med['dosage'] ?? '',
                  quantity: med['quantity'] ?? 0,
                  price: (med['price'] ?? 0).toDouble(),
                  instructions: med['instructions'] ?? '',
                ),
              )
              .toList(),
          prescriptionDate:
              (data['prescriptionDate'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          totalAmount: (data['totalAmount'] ?? 0).toDouble(),
          status: data['status'] ?? 'pending',
        );
      }).toList();

      // Sort by timestamp in descending order (newest first)
      prescriptions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return prescriptions;
    } catch (e) {
      print('Error getting prescriptions: $e');
      return [];
    }
  }

  // Get prescriptions stream for real-time updates
  Stream<List<PharmacyPrescription>> getPrescriptionsStream() {
    return FirebaseFirestore.instance
        .collection('prescriptions')
        .where('pharmacyId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .snapshots()
        .map((snapshot) {
          final prescriptions = snapshot.docs.map((doc) {
            final data = doc.data();
            return PharmacyPrescription(
              id: doc.id,
              orderNumber: data['orderNumber'] ?? 0,
              pharmacyId: data['pharmacyId'] ?? '',
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              patientInfo: PatientInfo(
                id: data['patientId'] ?? '',
                name: data['patientName'] ?? '',
                phone: data['patientPhone'] ?? '',
                email: data['patientEmail'] ?? '',
                age: data['patientAge'] ?? 0,
              ),
              doctorInfo: DoctorInfo(
                id: data['doctorId'] ?? '',
                name: data['doctorName'] ?? '',
                specialization: data['doctorSpecialization'] ?? '',
                hospital: data['doctorHospital'] ?? '',
              ),
              medicines: (data['medicines'] as List<dynamic>? ?? [])
                  .map(
                    (med) => Medicine(
                      id: med['id'] ?? '',
                      name: med['name'] ?? '',
                      dosage: med['dosage'] ?? '',
                      quantity: med['quantity'] ?? 0,
                      price: (med['price'] ?? 0).toDouble(),
                      instructions: med['instructions'] ?? '',
                    ),
                  )
                  .toList(),
              prescriptionDate:
                  (data['prescriptionDate'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              totalAmount: (data['totalAmount'] ?? 0).toDouble(),
              status: data['status'] ?? 'pending',
            );
          }).toList();

          // Sort by timestamp in descending order (newest first)
          prescriptions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return prescriptions;
        });
  }

  // Get inventory stream
  Stream<QuerySnapshot> getInventoryStream() {
    return _firestore
        .collection('pharmacy_inventory')
        .doc(currentPharmacyId)
        .collection('medicines')
        .snapshots();
  }

  /// Update prescription status
  Future<void> updatePrescriptionStatus(
    String prescriptionId,
    String status,
  ) async {
    try {
      await _firestore.collection('prescriptions').doc(prescriptionId).update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating prescription status: $e');
    }
  }

  /// Generate bill
  Future<PharmacyBill> generateBill(PharmacyPrescription prescription) async {
    try {
      final billId = _firestore.collection('pharmacy_bills').doc().id;
      final billNumber = 'BILL${DateTime.now().millisecondsSinceEpoch}';
      final subtotal = prescription.medicines.fold(
        0.0,
        (sum, medicine) =>
            sum +
            (medicine.price *
                (medicine.availableQuantity ?? medicine.quantity)),
      );
      final tax = subtotal * 0.08; // 8% tax
      final total = subtotal + tax;
      final now = DateTime.now();

      final billData = {
        'id': billId,
        'billNumber': billNumber,
        'orderNumber': prescription.orderNumber.toString(),
        'pharmacyId': currentPharmacyId,
        'patientName': prescription.patientInfo.name,
        'medicines': prescription.medicines.map((m) => m.toMap()).toList(),
        'patientInfo': prescription.patientInfo.toMap(),
        'subtotal': subtotal,
        'tax': tax,
        'totalAmount': total,
        'billDate': Timestamp.fromDate(now),
        'timestamp': Timestamp.fromDate(now),
        'status': 'issued',
      };

      // Save to Firestore with server timestamp
      await _firestore.collection('pharmacy_bills').doc(billId).set({
        ...billData,
        'billDate': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      return PharmacyBill.fromMap(billData);
    } catch (e) {
      print('Error generating bill: $e');
      throw e;
    }
  }

  /// Update inventory after sale
  Future<void> updateInventoryAfterSale(List<Medicine> medicines) async {
    try {
      final batch = _firestore.batch();

      for (final medicine in medicines) {
        final inventoryRef = _firestore
            .collection('pharmacy_inventory')
            .doc(currentPharmacyId)
            .collection('medicines')
            .doc(medicine.id);

        batch.update(inventoryRef, {
          'quantity': FieldValue.increment(
            -(medicine.availableQuantity ?? medicine.quantity),
          ),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error updating inventory: $e');
    }
  }

  /// Get inventory
  Future<List<Medicine>> getInventory() async {
    try {
      final querySnapshot = await _firestore
          .collection('pharmacy_inventory')
          .doc(currentPharmacyId)
          .collection('medicines')
          .get();

      return querySnapshot.docs
          .map((doc) => Medicine.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting inventory: $e');
      return [];
    }
  }

  /// Add medicine to inventory
  Future<void> addMedicine({
    required String name,
    required String category,
    required int quantity,
    required double unitPrice,
    required DateTime expiryDate,
    required String batchNumber,
    required String supplier,
    required int minStock,
    String? dosage,
    String? instructions,
  }) async {
    try {
      // Generate a unique ID for the medicine
      final medicineRef = _firestore
          .collection('pharmacy_inventory')
          .doc(currentPharmacyId)
          .collection('medicines')
          .doc();

      await medicineRef.set({
        'name': name,
        'category': category,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'batchNumber': batchNumber,
        'supplier': supplier,
        'minStock': minStock,
        'dosage': dosage,
        'instructions': instructions,
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Medicine added successfully: $name');
    } catch (e) {
      print('❌ Error adding medicine: $e');
      throw e;
    }
  }

  /// Update medicine in inventory
  Future<void> updateMedicine({
    required String medicineId,
    required String name,
    required String category,
    required int quantity,
    required double unitPrice,
    required DateTime expiryDate,
    required String batchNumber,
    required String supplier,
    required int minStock,
    String? dosage,
    String? instructions,
  }) async {
    try {
      final medicineRef = _firestore
          .collection('pharmacy_inventory')
          .doc(currentPharmacyId)
          .collection('medicines')
          .doc(medicineId);

      await medicineRef.update({
        'name': name,
        'category': category,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'batchNumber': batchNumber,
        'supplier': supplier,
        'minStock': minStock,
        'dosage': dosage,
        'instructions': instructions,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Medicine updated successfully: $name');
    } catch (e) {
      print('❌ Error updating medicine: $e');
      throw e;
    }
  }

  /// Restock medicine inventory
  Future<void> restockMedicine({
    required String medicineId,
    required int additionalQuantity,
    String? newBatchNumber,
    DateTime? newExpiryDate,
  }) async {
    try {
      final medicineRef = _firestore
          .collection('pharmacy_inventory')
          .doc(currentPharmacyId)
          .collection('medicines')
          .doc(medicineId);

      final updateData = <String, dynamic>{
        'quantity': FieldValue.increment(additionalQuantity),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (newBatchNumber != null) {
        updateData['batchNumber'] = newBatchNumber;
      }

      if (newExpiryDate != null) {
        updateData['expiryDate'] = Timestamp.fromDate(newExpiryDate);
      }

      await medicineRef.update(updateData);

      print('✅ Medicine restocked successfully: +$additionalQuantity units');
    } catch (e) {
      print('❌ Error restocking medicine: $e');
      throw e;
    }
  }

  /// Delete medicine from inventory
  Future<void> deleteMedicine(String medicineId) async {
    try {
      final medicineRef = _firestore
          .collection('pharmacy_inventory')
          .doc(currentPharmacyId)
          .collection('medicines')
          .doc(medicineId);

      await medicineRef.delete();

      print('✅ Medicine deleted successfully');
    } catch (e) {
      print('❌ Error deleting medicine: $e');
      throw e;
    }
  }

  /// Initialize sample data for testing
  Future<void> initializeSampleData() async {
    try {
      // Create sample prescriptions for the current pharmacy
      final samplePrescriptions = [
        {
          'id': 'prescription_001',
          'orderNumber': 1001,
          'pharmacyId': currentPharmacyId,
          'patientId': 'patient_001',
          'patientName': 'John Doe',
          'patientPhone': '+1234567890',
          'patientEmail': 'john.doe@email.com',
          'patientAge': 45,
          'doctorId': 'doctor_001',
          'doctorName': 'Dr. Sarah Wilson',
          'doctorSpecialization': 'Cardiology',
          'doctorHospital': 'City General Hospital',
          'medicines': [
            {
              'id': 'med_001',
              'name': 'Amoxicillin 500mg',
              'quantity': 21,
              'dosage': '1 tablet 3x daily',
              'instructions': 'Take with food',
              'price': 15.00,
            },
            {
              'id': 'med_002',
              'name': 'Ibuprofen 400mg',
              'quantity': 30,
              'dosage': '1 tablet 2x daily',
              'instructions': 'Take after meals',
              'price': 8.50,
            },
          ],
          'status': 'pending',
          'prescriptionDate': FieldValue.serverTimestamp(),
          'totalAmount': 23.50,
          'timestamp': FieldValue.serverTimestamp(),
        },
        {
          'id': 'prescription_002',
          'orderNumber': 1002,
          'pharmacyId': currentPharmacyId,
          'patientId': 'patient_002',
          'patientName': 'Jane Smith',
          'patientPhone': '+1234567891',
          'patientEmail': 'jane.smith@email.com',
          'patientAge': 32,
          'doctorId': 'doctor_002',
          'doctorName': 'Dr. Michael Brown',
          'doctorSpecialization': 'General Medicine',
          'doctorHospital': 'Metro Medical Center',
          'medicines': [
            {
              'id': 'med_003',
              'name': 'Lisinopril 10mg',
              'quantity': 30,
              'dosage': '1 tablet daily',
              'instructions': 'Take in the morning',
              'price': 12.75,
            },
          ],
          'status': 'ready',
          'prescriptionDate': FieldValue.serverTimestamp(),
          'totalAmount': 12.75,
          'timestamp': FieldValue.serverTimestamp(),
        },
        {
          'id': 'prescription_003',
          'orderNumber': 1003,
          'pharmacyId': currentPharmacyId,
          'patientId': 'patient_003',
          'patientName': 'Robert Johnson',
          'patientPhone': '+1234567892',
          'patientEmail': 'robert.johnson@email.com',
          'patientAge': 58,
          'doctorId': 'doctor_003',
          'doctorName': 'Dr. Emily Davis',
          'doctorSpecialization': 'Endocrinology',
          'doctorHospital': 'Regional Medical Center',
          'medicines': [
            {
              'id': 'med_004',
              'name': 'Metformin 500mg',
              'quantity': 60,
              'dosage': '1 tablet 2x daily',
              'instructions': 'Take with meals',
              'price': 18.25,
            },
            {
              'id': 'med_005',
              'name': 'Insulin Glargine',
              'quantity': 1,
              'dosage': '10 units daily',
              'instructions': 'Inject subcutaneously',
              'price': 45.00,
            },
          ],
          'status': 'delivered',
          'prescriptionDate': FieldValue.serverTimestamp(),
          'totalAmount': 63.25,
          'timestamp': FieldValue.serverTimestamp(),
        },
      ];

      // Add prescriptions to Firestore
      for (final prescription in samplePrescriptions) {
        await _firestore
            .collection('prescriptions')
            .doc(prescription['id'] as String)
            .set(prescription);
      }

      // Create sample inventory
      final sampleInventory = [
        {
          'id': 'inv_001',
          'name': 'Amoxicillin 500mg',
          'quantity': 100,
          'minThreshold': 20,
          'price': 15.00,
          'category': 'Antibiotic',
          'pharmacyId': currentPharmacyId,
        },
        {
          'id': 'inv_002',
          'name': 'Ibuprofen 400mg',
          'quantity': 150,
          'minThreshold': 30,
          'price': 8.50,
          'category': 'Pain Relief',
          'pharmacyId': currentPharmacyId,
        },
        {
          'id': 'inv_003',
          'name': 'Lisinopril 10mg',
          'quantity': 8, // Low stock example
          'minThreshold': 15,
          'price': 12.75,
          'category': 'Cardiovascular',
          'pharmacyId': currentPharmacyId,
        },
        {
          'id': 'inv_004',
          'name': 'Metformin 500mg',
          'quantity': 75,
          'minThreshold': 25,
          'price': 18.25,
          'category': 'Diabetes',
          'pharmacyId': currentPharmacyId,
        },
        {
          'id': 'inv_005',
          'name': 'Insulin Glargine',
          'quantity': 12,
          'minThreshold': 5,
          'price': 45.00,
          'category': 'Diabetes',
          'pharmacyId': currentPharmacyId,
        },
      ];

      // Add inventory to Firestore
      for (final item in sampleInventory) {
        await _firestore
            .collection('pharmacy_inventory')
            .doc(currentPharmacyId)
            .collection('medicines')
            .doc(item['id'] as String)
            .set({...item, 'lastUpdated': FieldValue.serverTimestamp()});
      }

      print('✅ Sample pharmacy data created successfully');
    } catch (e) {
      print('❌ Error creating sample pharmacy data: $e');
    }
  }

  /// Create sample data for testing
  Future<void> createSampleData() async {
    try {
      // Create sample prescriptions
      final samplePrescriptions = [
        {
          'id': 'prescription_001',
          'pharmacyId': currentPharmacyId,
          'patientInfo': {
            'name': 'John Doe',
            'age': 45,
            'phone': '+1234567890',
            'email': 'john.doe@email.com',
          },
          'doctorInfo': {
            'name': 'Dr. Sarah Wilson',
            'specialization': 'Cardiology',
            'hospital': 'City General Hospital',
          },
          'medicines': [
            {
              'id': 'med_001',
              'name': 'Amoxicillin 500mg',
              'quantity': 21,
              'dosage': '1 tablet 3x daily',
              'instructions': 'Take with food',
              'price': 15.00,
              'availability': 'pending',
            },
            {
              'id': 'med_002',
              'name': 'Ibuprofen 400mg',
              'quantity': 30,
              'dosage': '1 tablet 2x daily',
              'instructions': 'Take after meals',
              'price': 8.50,
              'availability': 'pending',
            },
          ],
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        },
        {
          'id': 'prescription_002',
          'pharmacyId': currentPharmacyId,
          'patientInfo': {
            'name': 'Jane Smith',
            'age': 32,
            'phone': '+1234567891',
            'email': 'jane.smith@email.com',
          },
          'doctorInfo': {
            'name': 'Dr. Michael Brown',
            'specialization': 'General Medicine',
            'hospital': 'Metro Medical Center',
          },
          'medicines': [
            {
              'id': 'med_003',
              'name': 'Lisinopril 10mg',
              'quantity': 30,
              'dosage': '1 tablet daily',
              'instructions': 'Take in the morning',
              'price': 12.75,
              'availability': 'pending',
            },
          ],
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        },
      ];

      // Add prescriptions to Firestore
      for (final prescription in samplePrescriptions) {
        await _firestore
            .collection('prescriptions')
            .doc(prescription['id'] as String)
            .set(prescription);
      }

      // Create sample inventory
      final sampleInventory = [
        {
          'id': 'med_001',
          'name': 'Amoxicillin 500mg',
          'category': 'Antibiotics',
          'quantity': 150,
          'unitPrice': 0.71,
          'expiryDate': DateTime.now().add(const Duration(days: 365)),
          'batchNumber': 'AMX2024001',
          'supplier': 'MedSupply Co.',
          'minStock': 20,
        },
        {
          'id': 'med_002',
          'name': 'Ibuprofen 400mg',
          'category': 'Pain Relief',
          'quantity': 5, // Low stock for testing
          'unitPrice': 0.28,
          'expiryDate': DateTime.now().add(const Duration(days: 180)),
          'batchNumber': 'IBU2024001',
          'supplier': 'PharmaCorp',
          'minStock': 10,
        },
        {
          'id': 'med_003',
          'name': 'Lisinopril 10mg',
          'category': 'Cardiovascular',
          'quantity': 75,
          'unitPrice': 0.425,
          'expiryDate': DateTime.now().add(const Duration(days: 300)),
          'batchNumber': 'LIS2024001',
          'supplier': 'MedSupply Co.',
          'minStock': 15,
        },
      ];

      // Add inventory to Firestore
      for (final medicine in sampleInventory) {
        await _firestore
            .collection('pharmacy_inventory')
            .doc(currentPharmacyId)
            .collection('medicines')
            .doc(medicine['id'] as String)
            .set({...medicine, 'lastUpdated': FieldValue.serverTimestamp()});
      }

      print('✅ Sample data created successfully');
    } catch (e) {
      print('❌ Error creating sample data: $e');
    }
  }
}

// Data Models
class PharmacyPrescription {
  final String id;
  final int orderNumber;
  final String pharmacyId;
  final PatientInfo patientInfo;
  final DoctorInfo doctorInfo;
  final List<Medicine> medicines;
  final String status;
  final DateTime timestamp;
  final DateTime prescriptionDate;
  final double totalAmount;

  PharmacyPrescription({
    required this.id,
    required this.orderNumber,
    required this.pharmacyId,
    required this.patientInfo,
    required this.doctorInfo,
    required this.medicines,
    required this.status,
    required this.timestamp,
    required this.prescriptionDate,
    required this.totalAmount,
  });

  factory PharmacyPrescription.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return PharmacyPrescription(
      id: id,
      orderNumber: data['orderNumber'] ?? 0,
      pharmacyId: data['pharmacyId'] ?? '',
      patientInfo: PatientInfo.fromMap(data['patientInfo'] ?? {}),
      doctorInfo: DoctorInfo.fromMap(data['doctorInfo'] ?? {}),
      medicines: (data['medicines'] as List<dynamic>? ?? [])
          .map((m) => Medicine.fromMap(m))
          .toList(),
      status: data['status'] ?? 'pending',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      prescriptionDate:
          (data['prescriptionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
    );
  }
}

class PatientInfo {
  final String id;
  final String name;
  final int age;
  final String phone;
  final String email;

  PatientInfo({
    required this.id,
    required this.name,
    required this.age,
    required this.phone,
    required this.email,
  });

  factory PatientInfo.fromMap(Map<String, dynamic> data) {
    return PatientInfo(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'age': age, 'phone': phone, 'email': email};
  }
}

class DoctorInfo {
  final String id;
  final String name;
  final String specialization;
  final String hospital;

  DoctorInfo({
    required this.id,
    required this.name,
    required this.specialization,
    required this.hospital,
  });

  factory DoctorInfo.fromMap(Map<String, dynamic> data) {
    return DoctorInfo(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      specialization: data['specialization'] ?? '',
      hospital: data['hospital'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'specialization': specialization,
      'hospital': hospital,
    };
  }
}

class Medicine {
  final String id;
  final String name;
  final int quantity;
  final String dosage;
  final String instructions;
  final double price;
  String availability;
  int? availableQuantity;

  Medicine({
    required this.id,
    required this.name,
    required this.quantity,
    required this.dosage,
    required this.instructions,
    required this.price,
    this.availability = 'pending',
    this.availableQuantity,
  });

  factory Medicine.fromMap(Map<String, dynamic> data) {
    return Medicine(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      quantity: data['quantity'] ?? 0,
      dosage: data['dosage'] ?? '',
      instructions: data['instructions'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      availability: data['availability'] ?? 'pending',
      availableQuantity: data['availableQuantity'],
    );
  }

  factory Medicine.fromFirestore(Map<String, dynamic> data, String id) {
    return Medicine(
      id: id,
      name: data['name'] ?? '',
      quantity: data['quantity'] ?? 0,
      dosage: data['dosage'] ?? '',
      instructions: data['instructions'] ?? '',
      price: (data['unitPrice'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': availableQuantity ?? quantity,
      'dosage': dosage,
      'instructions': instructions,
      'price': price,
      'availability': availability,
    };
  }
}

class PharmacyBill {
  final String id;
  final String billNumber;
  final String orderNumber;
  final String pharmacyId;
  final String patientName;
  final List<Medicine> medicines;
  final PatientInfo? patientInfo;
  final double subtotal;
  final double tax;
  final double totalAmount;
  final DateTime billDate;
  final DateTime timestamp;
  final String status;

  PharmacyBill({
    required this.id,
    required this.billNumber,
    required this.orderNumber,
    required this.pharmacyId,
    required this.patientName,
    required this.medicines,
    this.patientInfo,
    required this.subtotal,
    required this.tax,
    required this.totalAmount,
    required this.billDate,
    required this.timestamp,
    required this.status,
  });

  factory PharmacyBill.fromMap(Map<String, dynamic> data) {
    return PharmacyBill(
      id: data['id'] ?? '',
      billNumber: data['billNumber'] ?? '',
      orderNumber: data['orderNumber'] ?? '',
      pharmacyId: data['pharmacyId'] ?? '',
      patientName: data['patientName'] ?? '',
      medicines: (data['medicines'] as List<dynamic>? ?? [])
          .map((m) => Medicine.fromMap(m))
          .toList(),
      patientInfo: data['patientInfo'] != null
          ? PatientInfo.fromMap(data['patientInfo'])
          : null,
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      tax: (data['tax'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      billDate: (data['billDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'issued',
    );
  }
}
