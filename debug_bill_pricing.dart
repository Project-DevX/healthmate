import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  print('🔍 Fetching recent bills to check pricing...');

  try {
    // Get recent bills
    final billsQuery = await firestore
        .collection('pharmacy_bills')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();

    print('📋 Found ${billsQuery.docs.length} recent bills');

    for (final billDoc in billsQuery.docs) {
      final billData = billDoc.data();
      final billNumber = billData['billNumber'] ?? 'Unknown';
      final patientName = billData['patientName'] ?? 'Unknown';
      final subtotal = billData['subtotal'] ?? 0.0;
      final totalAmount = billData['totalAmount'] ?? 0.0;

      print('\\n📄 Bill: $billNumber');
      print('   Patient: $patientName');
      print('   Subtotal: \$${subtotal.toStringAsFixed(2)}');
      print('   Total: \$${totalAmount.toStringAsFixed(2)}');

      // Check medicines in the bill
      final medicines = billData['medicines'] as List<dynamic>? ?? [];
      print('   Medicines:');

      for (final medData in medicines) {
        final medMap = medData as Map<String, dynamic>;
        final name = medMap['name'] ?? 'Unknown';
        final quantity = medMap['quantity'] ?? 0;
        final price = (medMap['price'] ?? 0.0).toDouble();
        final lineTotal = price * quantity;

        print(
          '     - $name: $quantity × \$${price.toStringAsFixed(2)} = \$${lineTotal.toStringAsFixed(2)}',
        );
      }
    }

    print('\\n🔍 Now checking inventory prices...');

    // Check current inventory prices
    final inventoryQuery = await firestore
        .collection('pharmacy_inventory')
        .get();

    for (final pharmacyDoc in inventoryQuery.docs) {
      final pharmacyId = pharmacyDoc.id;
      print('\\n🏥 Pharmacy: $pharmacyId');

      final medicinesQuery = await firestore
          .collection('pharmacy_inventory')
          .doc(pharmacyId)
          .collection('medicines')
          .get();

      for (final medDoc in medicinesQuery.docs) {
        final medData = medDoc.data();
        final name = medData['name'] ?? 'Unknown';
        final unitPrice = (medData['unitPrice'] ?? 0.0).toDouble();
        final quantity = medData['quantity'] ?? 0;

        print(
          '     - $name: \$${unitPrice.toStringAsFixed(2)} (Stock: $quantity)',
        );
      }
    }
  } catch (e) {
    print('❌ Error fetching bills: $e');
  }
}
