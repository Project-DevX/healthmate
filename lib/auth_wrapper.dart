import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../login.dart';
import '../patientDashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final loginState = await AuthService.getLoginState();

      if (mounted) {
        if (loginState.isNotEmpty && loginState['userId'] != null) {
          // User is logged in, navigate to appropriate screen
          final userType = loginState['userType'] ?? 'patient';

          if (userType == 'patient') {
            Navigator.pushReplacementNamed(context, '/patientDashboard');
          } else if (userType == 'doctor') {
            Navigator.pushReplacementNamed(context, '/doctorDashboard');
          } else if (userType == 'hospital') {
            Navigator.pushReplacementNamed(context, '/hospitalDashboard');
          } else {
            // Default to patient dashboard for any unknown user types
            Navigator.pushReplacementNamed(context, '/patientDashboard');
          }
        } else {
          // User is not logged in, navigate to login screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      }
    } catch (e) {
      print('Error checking auth state: $e');
      // On error, navigate to login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_hospital, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            const Text(
              'HealthMate',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
