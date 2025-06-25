import 'package:flutter/material.dart';
import 'patientReg.dart';
import 'doctorReg.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  void _onRoleSelected(BuildContext context, String role) {
    switch (role) {
      case 'Patient':
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => const PatientRegistrationPage()),
        );
        break;
      case 'Doctor':
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => const DoctorRegistrationPage()),
        );
        break;
      case 'Caregiver':
      case 'Hospital':
        // TODO: Navigate to other registration pages when implemented
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$role registration coming soon')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roleButton(context, 'Patient', Icons.person),
              const SizedBox(height: 20),
              _roleButton(context, 'Doctor', Icons.medical_services),
              const SizedBox(height: 20),
              _roleButton(context, 'Caregiver', Icons.volunteer_activism),
              const SizedBox(height: 20),
              _roleButton(context, 'Hospital', Icons.local_hospital),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleButton(BuildContext context, String role, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(role, style: const TextStyle(fontSize: 18)),
        ),
        onPressed: () => _onRoleSelected(context, role),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
