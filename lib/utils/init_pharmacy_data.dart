import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';
import '../services/pharmacy_service.dart';

// Test utility to initialize sample pharmacy data
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Authenticate as a test pharmacy user
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'contact.healthcarepharm@gmail.com',
      password: 'testpassword',
    );

    print('✅ Authenticated as pharmacy user');

    // Initialize sample data
    final pharmacyService = PharmacyService();
    await pharmacyService.initializeSampleData();

    print('✅ Sample data initialization complete');
  } catch (e) {
    print('❌ Error: $e');
  }
}
