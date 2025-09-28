import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PharmacyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's pharmacy ID
  String? get currentPharmacyId => _auth.currentUser?.uid;

  /// Get current bill number for the pharmacy
  Future<String> getCurrentBillNumber() async {
    try {
      final today = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(today);

      final billDoc = await _firestore
          .collection('pharmacy_bills_counter')
          .doc(currentPharmacyId)
          .collection('daily_bills')
          .doc(dateKey)
          .get();

      if (billDoc.exists) {
        final data = billDoc.data()!;
        return (data['currentBillNumber'] ?? 1).toString().padLeft(3, '0');
      } else {
        // Initialize for today
        await _firestore
            .collection('pharmacy_bills_counter')
            .doc(currentPharmacyId)
            .collection('daily_bills')
            .doc(dateKey)
            .set({'currentBillNumber': 1, 'date': today, 'totalBills': 0});
        return '001';
      }
    } catch (e) {
      print('Error getting bill number: $e');
      return '001';
    }
  }

  /// Increment bill number
  Future<void> incrementBillNumber() async {
    try {
      final today = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(today);

      final billDocRef = _firestore
          .collection('pharmacy_bills_counter')
          .doc(currentPharmacyId)
          .collection('daily_bills')
          .doc(dateKey);

      await _firestore.runTransaction((transaction) async {
        final billDoc = await transaction.get(billDocRef);

        if (billDoc.exists) {
          final currentNumber = billDoc.data()!['currentBillNumber'] ?? 0;
          transaction.update(billDocRef, {
            'currentBillNumber': currentNumber + 1,
            'totalBills': FieldValue.increment(1),
          });
        } else {
          transaction.set(billDocRef, {
            'currentBillNumber': 2,
            'date': today,
            'totalBills': 1,
          });
        }
      });
    } catch (e) {
      print('Error incrementing bill number: $e');
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
                  duration: med['duration'] ?? '7 days',
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
                      duration: med['duration'] ?? '',
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

  // Get bills for pharmacy
  Future<List<PharmacyBill>> getBills() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('pharmacy_bills')
          .where('pharmacyId', isEqualTo: currentPharmacyId)
          .get();

      final bills = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return PharmacyBill.fromMap(data);
      }).toList();

      // Sort bills by timestamp, newest first
      bills.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return bills;
    } catch (e) {
      print('Error getting bills: $e');
      return [];
    }
  }

  // Get bills stream for real-time updates
  Stream<List<PharmacyBill>> getBillsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user found');
      return Stream.value([]);
    }

    final pharmacyId = user.uid;
    print('🔍 getBillsStream called with pharmacyId: $pharmacyId');
    print(
      '🔧 Creating FIXED query without orderBy: collection(pharmacy_bills).where(pharmacyId, ==, $pharmacyId)',
    );

    final query = FirebaseFirestore.instance
        .collection('pharmacy_bills')
        .where('pharmacyId', isEqualTo: pharmacyId);

    print('✅ Query created successfully, starting snapshots listener');

    return query
        .snapshots()
        .map((snapshot) {
          print(
            '📡 Stream received ${snapshot.docs.length} bills for pharmacy: $pharmacyId',
          );

          if (snapshot.docs.isEmpty) {
            print('📭 No bills found in snapshot');
          }

          final bills = <PharmacyBill>[];

          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              print(
                '📋 Processing bill: ${data['billNumber']} for pharmacy: ${data['pharmacyId']}',
              );
              final bill = PharmacyBill.fromMap(data);
              bills.add(bill);
            } catch (e) {
              print('❌ Error parsing bill ${doc.id}: $e');
              print('❌ Bill data: ${doc.data()}');
            }
          }

          // Sort bills by timestamp, newest first
          bills.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          print('✅ Returning ${bills.length} processed bills');
          return bills;
        })
        .handleError((error) {
          print('❌ Stream error: $error');
          return <PharmacyBill>[];
        });
  }

  /// Check inventory availability for prescription medicines
  Future<Map<String, dynamic>> checkInventoryAvailability(
    List<Medicine> medicines,
  ) async {
    try {
      print(
        '🔍 INVENTORY: Checking availability for ${medicines.length} medicines',
      );
      print('🔍 INVENTORY: Current pharmacy ID: $currentPharmacyId');

      List<Medicine> availableMedicines = [];
      List<Medicine> unavailableMedicines = [];
      List<String> warnings = [];

      for (final medicine in medicines) {
        print(
          '🔍 INVENTORY: Checking medicine: ${medicine.name} (need ${medicine.quantity})',
        );

        // Query inventory for this medicine by name (case-insensitive matching)
        final querySnapshot = await _firestore
            .collection('pharmacy_inventory')
            .doc(currentPharmacyId)
            .collection('medicines')
            .get(); // Get all medicines first, then filter locally for case-insensitive match

        print(
          '🔍 INVENTORY: Retrieved ${querySnapshot.docs.length} total medicines from inventory',
        );

        // Find medicine with case-insensitive name matching
        final matchingDocs = querySnapshot.docs.where((doc) {
          final docName = (doc.data()['name'] ?? '').toString().toLowerCase();
          final searchName = medicine.name.toLowerCase();
          return docName == searchName;
        }).toList();

        print(
          '🔍 INVENTORY: Found ${matchingDocs.length} matching records for "${medicine.name}"',
        );

        if (matchingDocs.isNotEmpty) {
          final inventoryDoc = matchingDocs.first;
          final inventoryData = inventoryDoc.data();
          final availableQuantity = inventoryData['quantity'] ?? 0;
          final requiredQuantity = medicine.quantity;

          print(
            '🔍 INVENTORY: ${medicine.name} - Available: $availableQuantity, Required: $requiredQuantity',
          );

          // Get price from inventory
          final inventoryPrice = (inventoryData['unitPrice'] ?? 0.0).toDouble();

          print(
            '🔍 INVENTORY: ${medicine.name} inventory data keys: ${inventoryData.keys.toList()}',
          );
          print(
            '🔍 INVENTORY: ${medicine.name} full inventory data: $inventoryData',
          );
          print(
            '🔍 INVENTORY: Raw unitPrice value: ${inventoryData['unitPrice']} (type: ${inventoryData['unitPrice'].runtimeType})',
          );
          print('🔍 INVENTORY: Extracted price: \$${inventoryPrice}');

          if (availableQuantity >= requiredQuantity) {
            // Sufficient stock - create new medicine with inventory price
            final updatedMedicine = Medicine(
              id: medicine.id,
              name: medicine.name,
              quantity: medicine.quantity,
              dosage: medicine.dosage,
              duration: medicine.duration,
              instructions: medicine.instructions,
              price: inventoryPrice, // Use inventory price
              availability: medicine.availability,
              availableQuantity: requiredQuantity,
            );
            availableMedicines.add(updatedMedicine);
            print(
              '✅ INVENTORY: ${medicine.name} - Sufficient stock at \$${inventoryPrice}',
            );
          } else if (availableQuantity > 0) {
            // Partial stock - create new medicine with inventory price
            final updatedMedicine = Medicine(
              id: medicine.id,
              name: medicine.name,
              quantity: medicine.quantity,
              dosage: medicine.dosage,
              duration: medicine.duration,
              instructions: medicine.instructions,
              price: inventoryPrice, // Use inventory price
              availability: medicine.availability,
              availableQuantity: availableQuantity,
            );
            availableMedicines.add(updatedMedicine);
            final warning =
                '${medicine.name}: Only $availableQuantity available (requested: $requiredQuantity)';
            warnings.add(warning);
            print(
              '⚠️ INVENTORY: ${medicine.name} - Partial stock: $warning at \$${inventoryPrice}',
            );
          } else {
            // No stock
            unavailableMedicines.add(medicine);
            final warning =
                '${medicine.name}: Out of stock (requested: $requiredQuantity)';
            warnings.add(warning);
            print('❌ INVENTORY: ${medicine.name} - Out of stock: $warning');
          }
        } else {
          // Medicine not found in inventory
          unavailableMedicines.add(medicine);
          final warning = '${medicine.name}: Not found in inventory';
          warnings.add(warning);
          print('❌ INVENTORY: ${medicine.name} - Not found in inventory');
        }
      }

      final result = {
        'availableMedicines': availableMedicines,
        'unavailableMedicines': unavailableMedicines,
        'warnings': warnings,
        'hasUnavailable': unavailableMedicines.isNotEmpty,
        'hasPartialStock': warnings.any(
          (w) => w.contains('Only') && w.contains('available'),
        ),
      };

      print(
        '🔍 INVENTORY: Final result - Available: ${availableMedicines.length}, Unavailable: ${unavailableMedicines.length}, Warnings: ${warnings.length}',
      );

      return result;
    } catch (e) {
      print('❌ INVENTORY: Error checking inventory availability: $e');
      throw e;
    }
  }

  /// Update prescription status with inventory check
  Future<Map<String, dynamic>> updatePrescriptionStatusWithInventoryCheck(
    String prescriptionId,
    String status,
    List<Medicine> medicines,
  ) async {
    try {
      print(
        '🔍 SERVICE: Checking prescription $prescriptionId for status $status with ${medicines.length} medicines',
      );

      // If changing to 'ready' or 'delivered', check inventory availability first
      if (status.toLowerCase() == 'ready' ||
          status.toLowerCase() == 'delivered') {
        print(
          '🔍 SERVICE: Status is $status, checking inventory availability...',
        );
        final inventoryCheck = await checkInventoryAvailability(medicines);

        print('🔍 SERVICE: Inventory check result: $inventoryCheck');

        if (inventoryCheck['hasUnavailable'] ||
            inventoryCheck['hasPartialStock']) {
          print('🔍 SERVICE: Inventory issues found, requiring confirmation');
          // Return inventory check results for UI to handle
          return {
            'success': false,
            'requiresConfirmation': true,
            'inventoryCheck': inventoryCheck,
          };
        }
        print('🔍 SERVICE: Inventory check passed, proceeding with update');
      }

      // Update prescription pharmacy status
      await _firestore.collection('prescriptions').doc(prescriptionId).update({
        'pharmacyStatus': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // If status is delivered, automatically generate and save a bill
      if (status.toLowerCase() == 'delivered') {
        await _generateBillForDeliveredPrescription(prescriptionId);
        // Also reduce inventory when dispensed - use ALL medicines since inventory check passed
        await updateInventoryAfterSale(medicines);
      }

      print('✅ SERVICE: Prescription status updated to: $status');
      return {'success': true};
    } catch (e) {
      print('❌ SERVICE: Error updating prescription status: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update prescription status with partial quantities (for available medicines only)
  Future<void> updatePrescriptionStatusWithPartialQuantities(
    String prescriptionId,
    String status,
    List<Medicine> availableMedicines,
  ) async {
    try {
      print(
        '🔍 PARTIAL UPDATE: Updating prescription $prescriptionId to status "$status" with ${availableMedicines.length} available medicines',
      );

      // Update prescription status
      await _firestore.collection('prescriptions').doc(prescriptionId).update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // If status is delivered, generate bill with available medicines and update inventory
      if (status.toLowerCase() == 'delivered') {
        print(
          '🔍 PARTIAL UPDATE: Processing delivery with available medicines only',
        );

        // Get the original prescription data
        final prescriptionDoc = await _firestore
            .collection('prescriptions')
            .doc(prescriptionId)
            .get();

        if (prescriptionDoc.exists) {
          final prescriptionData = prescriptionDoc.data()!;
          final originalPrescription = PharmacyPrescription.fromFirestore(
            prescriptionData,
            prescriptionId,
          );

          // Create a modified prescription with available medicines only
          final modifiedPrescription = PharmacyPrescription(
            id: originalPrescription.id,
            orderNumber: originalPrescription.orderNumber,
            pharmacyId: originalPrescription.pharmacyId,
            patientInfo: originalPrescription.patientInfo,
            doctorInfo: originalPrescription.doctorInfo,
            medicines: availableMedicines, // Use only available medicines
            status: status,
            timestamp: originalPrescription.timestamp,
            prescriptionDate: originalPrescription.prescriptionDate,
            totalAmount: 0, // Will be recalculated in generateBill
          );

          // Generate bill with modified prescription (available medicines only)
          final bill = await generateBill(modifiedPrescription);
          await incrementBillNumber();

          // Update inventory with available medicines only
          await updateInventoryAfterSale(availableMedicines);

          print(
            '✅ PARTIAL UPDATE: Bill generated with partial quantities: ${bill.billNumber}',
          );
          print(
            '🔍 PARTIAL UPDATE: Bill includes ${modifiedPrescription.medicines.length} medicines with available quantities',
          );
        }
      } else {
        print(
          '🔍 PARTIAL UPDATE: Status updated to "$status" - no billing or inventory update needed',
        );
      }
    } catch (e) {
      print(
        '❌ PARTIAL UPDATE: Error updating prescription status with partial quantities: $e',
      );
      throw e;
    }
  }

  /// Update prescription status and generate bill if delivered
  Future<void> updatePrescriptionStatus(
    String prescriptionId,
    String status,
  ) async {
    try {
      await _firestore.collection('prescriptions').doc(prescriptionId).update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // If status is delivered, automatically generate and save a bill
      if (status.toLowerCase() == 'delivered') {
        await _generateBillForDeliveredPrescription(prescriptionId);
      }
    } catch (e) {
      print('Error updating prescription status: $e');
    }
  }

  /// Generate bill for delivered prescription
  Future<void> _generateBillForDeliveredPrescription(
    String prescriptionId,
  ) async {
    try {
      // Get the prescription details
      final prescriptionDoc = await _firestore
          .collection('prescriptions')
          .doc(prescriptionId)
          .get();

      if (!prescriptionDoc.exists) {
        print('Prescription not found: $prescriptionId');
        return;
      }

      // Convert prescription data to PharmacyPrescription object
      final prescriptionData = prescriptionDoc.data()!;
      final prescription = PharmacyPrescription.fromFirestore(
        prescriptionData,
        prescriptionId,
      );

      // Generate and save bill
      final bill = await generateBill(prescription);

      // Increment bill counter
      await incrementBillNumber();

      print('✅ Bill generated for delivered prescription: ${bill.billNumber}');
    } catch (e) {
      print('Error generating bill for delivered prescription: $e');
    }
  }

  /// Generate bill with dynamic pricing from inventory
  Future<PharmacyBill> generateBill(PharmacyPrescription prescription) async {
    try {
      final billId = _firestore.collection('pharmacy_bills').doc().id;

      // Get current bill number for proper sequential numbering
      final currentBillNumber = await getCurrentBillNumber();
      final billNumber =
          'BILL-${DateFormat('yyyyMMdd').format(DateTime.now())}-$currentBillNumber';

      print('💰 BILL: Generating bill with dynamic pricing from inventory...');

      // CRUCIAL FIX: Fetch fresh prescription data from Firestore to get accurate patient/doctor names
      print(
        '🔍 BILL: Fetching fresh prescription data from Firestore for ID: ${prescription.id}',
      );
      final freshPrescriptionDoc = await _firestore
          .collection('prescriptions')
          .doc(prescription.id)
          .get();

      String patientName = 'Unknown Patient';
      String doctorName = 'Unknown Doctor';
      String doctorSpecialization = 'General Medicine';
      String doctorHospital = 'Unknown Hospital';
      String patientEmail = '';
      String patientPhone = '';
      int patientAge = 0;

      if (freshPrescriptionDoc.exists) {
        final freshData = freshPrescriptionDoc.data()!;
        patientName = freshData['patientName'] ?? 'Unknown Patient';
        doctorName = freshData['doctorName'] ?? 'Unknown Doctor';
        doctorSpecialization =
            freshData['doctorSpecialization'] ?? 'General Medicine';
        doctorHospital = freshData['doctorHospital'] ?? 'Unknown Hospital';
        patientEmail = freshData['patientEmail'] ?? '';
        patientPhone = freshData['patientPhone'] ?? '';
        patientAge = freshData['patientAge'] ?? 0;

        print(
          '✅ BILL: Fresh data fetched - Patient: "$patientName", Doctor: "$doctorName"',
        );
      } else {
        print(
          '⚠️ BILL: Could not fetch fresh prescription data, using fallback values',
        );
      }

      // Get medicines with current inventory pricing
      final medicinesWithCurrentPricing = <Medicine>[];
      double subtotal = 0.0;

      for (final medicine in prescription.medicines) {
        // Fetch current price from inventory
        final inventoryQuery = await _firestore
            .collection('pharmacy_inventory')
            .doc(currentPharmacyId)
            .collection('medicines')
            .get();

        Medicine? medicineWithPrice;

        for (final inventoryDoc in inventoryQuery.docs) {
          final inventoryData = inventoryDoc.data();
          final inventoryName = inventoryData['name'] ?? '';

          // Case-insensitive medicine matching
          if (inventoryName.toLowerCase() == medicine.name.toLowerCase()) {
            final currentPrice = (inventoryData['unitPrice'] ?? 0.0).toDouble();
            final quantityToUse =
                medicine.availableQuantity ?? medicine.quantity;

            print(
              '💰 BILL: Found ${medicine.name} in inventory - Current price: \$${currentPrice}, Using quantity: $quantityToUse',
            );

            medicineWithPrice = Medicine(
              id: medicine.id,
              name: medicine.name,
              dosage: medicine.dosage,
              quantity: quantityToUse,
              price: currentPrice, // Use current inventory price
              instructions: medicine.instructions,
              duration: medicine.duration,
              availableQuantity: medicine.availableQuantity,
            );

            // Calculate line total
            final lineTotal = currentPrice * quantityToUse;
            subtotal += lineTotal;
            print(
              '💰 BILL: ${medicine.name} line total: \$${lineTotal.toStringAsFixed(2)} (${quantityToUse} × \$${currentPrice})',
            );
            break;
          }
        }

        if (medicineWithPrice != null) {
          medicinesWithCurrentPricing.add(medicineWithPrice);
        } else {
          print(
            '⚠️ BILL: Medicine ${medicine.name} not found in inventory - using fallback price of \$0.00',
          );
          // Fallback: add medicine with zero price if not found in inventory
          medicinesWithCurrentPricing.add(
            Medicine(
              id: medicine.id,
              name: medicine.name,
              dosage: medicine.dosage,
              quantity: medicine.availableQuantity ?? medicine.quantity,
              price: 0.0, // Zero price for unavailable items
              instructions: medicine.instructions,
              duration: medicine.duration,
              availableQuantity: medicine.availableQuantity,
            ),
          );
        }
      }

      final tax = subtotal * 0.08; // 8% tax
      final total = subtotal + tax;
      final now = DateTime.now();

      print(
        '💰 BILL: Calculated totals - Subtotal: \$${subtotal.toStringAsFixed(2)}, Tax: \$${tax.toStringAsFixed(2)}, Total: \$${total.toStringAsFixed(2)}',
      );

      // Create fresh PatientInfo and DoctorInfo objects with the correct data
      final freshPatientInfo = PatientInfo(
        id: prescription.patientInfo.id,
        name: patientName,
        age: patientAge,
        phone: patientPhone,
        email: patientEmail,
      );

      final freshDoctorInfo = DoctorInfo(
        id: prescription.doctorInfo.id,
        name: doctorName,
        specialization: doctorSpecialization,
        hospital: doctorHospital,
      );

      // Debug patient and doctor info with fresh data
      print(
        '💰 BILL: Using Fresh Patient Info - Name: "$patientName", Age: $patientAge, Phone: "$patientPhone"',
      );
      print(
        '💰 BILL: Using Fresh Doctor Info - Name: "$doctorName", Specialization: "$doctorSpecialization", Hospital: "$doctorHospital"',
      );

      final billData = {
        'id': billId,
        'billNumber': billNumber,
        'prescriptionId': prescription.id,
        'pharmacyId': currentPharmacyId,
        'patientName': patientName, // Use fresh patient name directly
        'doctorName': doctorName, // Add doctor name directly to bill
        'medicines': medicinesWithCurrentPricing.map((m) => m.toMap()).toList(),
        'patientInfo': freshPatientInfo.toMap(), // Use fresh patient info
        'doctorInfo': freshDoctorInfo.toMap(), // Use fresh doctor info
        'subtotal': subtotal,
        'tax': tax,
        'totalAmount': total,
        'billDate': Timestamp.fromDate(now),
        'timestamp': Timestamp.fromDate(now),
        'status': 'paid',
      };

      // Save to Firestore with server timestamp
      await _firestore.collection('pharmacy_bills').doc(billId).set({
        ...billData,
        'billDate': Timestamp.fromDate(DateTime.now()),
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });

      print(
        '✅ BILL: Generated bill ${billNumber} with current inventory pricing',
      );
      return PharmacyBill.fromMap(billData);
    } catch (e) {
      print('❌ BILL: Error generating bill: $e');
      throw e;
    }
  }

  /// Update inventory after sale
  Future<void> updateInventoryAfterSale(List<Medicine> medicines) async {
    try {
      print(
        '🔍 INVENTORY UPDATE: Updating inventory for ${medicines.length} medicines',
      );

      for (final medicine in medicines) {
        print(
          '🔍 INVENTORY UPDATE: Processing ${medicine.name} - reducing by ${medicine.availableQuantity ?? medicine.quantity}',
        );

        // Find inventory document by medicine name (not ID)
        final querySnapshot = await _firestore
            .collection('pharmacy_inventory')
            .doc(currentPharmacyId)
            .collection('medicines')
            .where('name', isEqualTo: medicine.name)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final inventoryDoc = querySnapshot.docs.first;
          final currentQuantity = inventoryDoc.data()['quantity'] ?? 0;
          final reductionAmount =
              medicine.availableQuantity ?? medicine.quantity;
          final newQuantity = currentQuantity - reductionAmount;

          print(
            '🔍 INVENTORY UPDATE: ${medicine.name} - Current: $currentQuantity, Reducing: $reductionAmount, New: $newQuantity',
          );

          await inventoryDoc.reference.update({
            'quantity': newQuantity,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          print(
            '✅ INVENTORY UPDATE: ${medicine.name} inventory updated successfully',
          );
        } else {
          print('❌ INVENTORY UPDATE: ${medicine.name} not found in inventory');
        }
      }
    } catch (e) {
      print('❌ INVENTORY UPDATE: Error updating inventory: $e');
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
              'duration': '7 days',
              'instructions': 'Take with food',
              // No price - will be calculated from inventory
            },
            {
              'id': 'med_002',
              'name': 'Ibuprofen 400mg',
              'quantity': 30,
              'dosage': '1 tablet 2x daily',
              'duration': '15 days',
              'instructions': 'Take after meals',
              // No price - will be calculated from inventory
            },
          ],
          'status': 'pending',
          'prescriptionDate': FieldValue.serverTimestamp(),
          'totalAmount': 0.0, // Will be calculated dynamically
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
              'duration': '30 days',
              'instructions': 'Take in the morning',
              // No price - will be calculated from inventory
            },
          ],
          'status': 'ready',
          'prescriptionDate': FieldValue.serverTimestamp(),
          'totalAmount': 0.0, // Will be calculated dynamically
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
              'duration': '30 days',
              'instructions': 'Take with meals',
              // No price - will be calculated from inventory
            },
            {
              'id': 'med_005',
              'name': 'Insulin Glargine',
              'quantity': 1,
              'dosage': '10 units daily',
              'duration': '30 days',
              'instructions': 'Inject subcutaneously',
              // No price - will be calculated from inventory
            },
          ],
          'status': 'delivered',
          'prescriptionDate': FieldValue.serverTimestamp(),
          'totalAmount': 0.0, // Will be calculated dynamically
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
              'duration': '7 days',
              'instructions': 'Take with food',
              // No price - will be calculated from inventory
              'availability': 'pending',
            },
            {
              'id': 'med_002',
              'name': 'Ibuprofen 400mg',
              'quantity': 30,
              'dosage': '1 tablet 2x daily',
              'duration': '15 days',
              'instructions': 'Take after meals',
              // No price - will be calculated from inventory
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
              'duration': '30 days',
              'instructions': 'Take in the morning',
              // No price - will be calculated from inventory
              'availability': 'pending',
            },
          ],
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        },
        // TEST CASE: Low stock warning prescription
        {
          'id': 'prescription_003_low_stock_test',
          'pharmacyId': currentPharmacyId,
          'patientInfo': {
            'name': 'Alice Johnson',
            'age': 28,
            'phone': '+1234567892',
            'email': 'alice.johnson@email.com',
          },
          'doctorInfo': {
            'name': 'Dr. Emily Davis',
            'specialization': 'Family Medicine',
            'hospital': 'Community Health Center',
          },
          'medicines': [
            {
              'id': 'med_002_test',
              'name': 'Ibuprofen 400mg',
              'quantity':
                  20, // Requesting 20, but only 5 available - should trigger warning
              'dosage': '1 tablet 3x daily',
              'duration': '7 days',
              'instructions': 'Take with food to reduce stomach irritation',
              // No price - will be calculated from inventory
              'availability': 'pending',
            },
          ],
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        },
        // TEST CASE: Out of stock prescription
        {
          'id': 'prescription_004_out_of_stock_test',
          'pharmacyId': currentPharmacyId,
          'patientInfo': {
            'name': 'Bob Wilson',
            'age': 45,
            'phone': '+1234567893',
            'email': 'bob.wilson@email.com',
          },
          'doctorInfo': {
            'name': 'Dr. Sarah Johnson',
            'specialization': 'Internal Medicine',
            'hospital': 'Regional Medical Center',
          },
          'medicines': [
            {
              'id': 'med_unavailable_test',
              'name':
                  'Metformin 500mg', // This medicine is NOT in inventory - should trigger not found warning
              'quantity': 30,
              'dosage': '1 tablet 2x daily',
              'duration': '30 days',
              'instructions': 'Take with meals',
              // No price - will be calculated from inventory
              'availability': 'pending',
            },
          ],
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        },
        // TEST CASE: Mixed availability prescription
        {
          'id': 'prescription_005_mixed_test',
          'pharmacyId': currentPharmacyId,
          'patientInfo': {
            'name': 'Carol Martinez',
            'age': 38,
            'phone': '+1234567894',
            'email': 'carol.martinez@email.com',
          },
          'doctorInfo': {
            'name': 'Dr. James Wilson',
            'specialization': 'Cardiology',
            'hospital': 'Heart Care Institute',
          },
          'medicines': [
            {
              'id': 'med_001_mixed',
              'name': 'Amoxicillin 500mg',
              'quantity': 10, // Available (150 in stock)
              'dosage': '1 tablet 3x daily',
              'duration': '5 days',
              'instructions': 'Complete full course',
              // No price - will be calculated from inventory
              'availability': 'pending',
            },
            {
              'id': 'med_002_mixed',
              'name': 'Ibuprofen 400mg',
              'quantity': 15, // Partial stock (only 5 available)
              'dosage': '1 tablet 2x daily',
              'duration': '10 days',
              'instructions': 'Take after meals',
              // No price - will be calculated from inventory
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
          'expiryDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 365)),
          ),
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
          'expiryDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 180)),
          ),
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
          'expiryDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 300)),
          ),
          'batchNumber': 'LIS2024001',
          'supplier': 'MedSupply Co.',
          'minStock': 15,
        },
      ];

      // Add inventory to Firestore
      print(
        '🔍 SAMPLE DATA: Creating ${sampleInventory.length} inventory items for pharmacy $currentPharmacyId',
      );
      for (final medicine in sampleInventory) {
        final medicineData = {
          ...medicine,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        print(
          '🔍 SAMPLE DATA: Creating inventory for ${medicine['name']} with quantity ${medicine['quantity']}',
        );
        await _firestore
            .collection('pharmacy_inventory')
            .doc(currentPharmacyId)
            .collection('medicines')
            .doc(medicine['id'] as String)
            .set(medicineData);
      }

      print('✅ Sample data created successfully');

      // Test inventory retrieval
      print('🔍 SAMPLE DATA: Testing inventory retrieval...');
      final testInventory = await getInventory();
      print(
        '🔍 SAMPLE DATA: Retrieved ${testInventory.length} inventory items',
      );
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
    // Create PatientInfo from flat fields in prescription document
    final patientInfo = PatientInfo(
      id: data['patientId'] ?? '',
      name: data['patientName'] ?? '', // Direct from prescription field
      age: data['patientAge'] ?? 0, // Direct from prescription field
      phone: data['patientPhone'] ?? '', // Direct from prescription field
      email: data['patientEmail'] ?? '', // Direct from prescription field
    );

    // Create DoctorInfo from flat fields in prescription document
    final doctorInfo = DoctorInfo(
      id: data['doctorId'] ?? '',
      name: data['doctorName'] ?? '', // Direct from prescription field
      specialization:
          data['doctorSpecialization'] ??
          'General Medicine', // Direct from prescription field
      hospital:
          data['doctorHospital'] ??
          'Unknown Hospital', // Direct from prescription field
    );

    return PharmacyPrescription(
      id: id,
      orderNumber: data['orderNumber'] ?? 0,
      pharmacyId: data['pharmacyId'] ?? '',
      patientInfo: patientInfo, // Use constructed PatientInfo
      doctorInfo: doctorInfo, // Use constructed DoctorInfo
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
  final String duration; // e.g., "7 days", "2 weeks", "1 month"
  final String instructions;
  final double price;
  String availability;
  int? availableQuantity;

  Medicine({
    required this.id,
    required this.name,
    required this.quantity,
    required this.dosage,
    required this.duration,
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
      duration: data['duration'] ?? '7 days', // Default duration
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
      duration: data['duration'] ?? '7 days', // Default duration
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
      'duration': duration,
      'instructions': instructions,
      'price': price,
      'availability': availability,
    };
  }
}

class PharmacyBill {
  final String id;
  final String billNumber;
  final String? prescriptionId;
  final String pharmacyId;
  final String patientName;
  final List<Medicine> medicines;
  final PatientInfo? patientInfo;
  final DoctorInfo? doctorInfo;
  final double subtotal;
  final double tax;
  final double totalAmount;
  final DateTime billDate;
  final DateTime timestamp;
  final String status;

  PharmacyBill({
    required this.id,
    required this.billNumber,
    this.prescriptionId,
    required this.pharmacyId,
    required this.patientName,
    required this.medicines,
    this.patientInfo,
    this.doctorInfo,
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
      prescriptionId: data['prescriptionId'],
      pharmacyId: data['pharmacyId'] ?? '',
      patientName: data['patientName'] ?? '',
      medicines: (data['medicines'] as List<dynamic>? ?? [])
          .map((m) => Medicine.fromMap(m))
          .toList(),
      patientInfo: data['patientInfo'] != null
          ? PatientInfo.fromMap(data['patientInfo'])
          : null,
      doctorInfo: data['doctorInfo'] != null
          ? DoctorInfo.fromMap(data['doctorInfo'])
          : null,
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      tax: (data['tax'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      billDate: (data['billDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'paid',
    );
  }
}
