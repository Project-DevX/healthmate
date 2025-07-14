import 'package:flutter/material.dart';
import 'patientReg.dart';
import 'doctorReg.dart';
import 'caregiverReg.dart';
import 'hospitalRegNew.dart';
import 'pharmacyReg.dart';
import 'labReg.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  void _onRoleSelected(BuildContext context, String role) {
    switch (role) {
      case 'Patient':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PatientRegistrationPage(),
          ),
        );
        break;
      case 'Doctor':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DoctorRegistrationPage(),
          ),
        );
        break;
      case 'Caregiver':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CaregiverRegistrationPage(),
          ),
        );
        break;
      case 'Hospital':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const HospitalRegistrationPage(),
          ),
        );
        break;
      case 'Pharmacy':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PharmacyRegistrationPage(),
          ),
        );
        break;
      case 'Laboratory':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LabRegistrationPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Registration Type'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Icon(Icons.app_registration, size: 80, color: Colors.teal),
              const SizedBox(height: 16),
              const Text(
                'Join HealthMate',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your role to get started with the right features',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Role Cards in a Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: [
                  _buildRoleCard(
                    context,
                    'Patient',
                    Icons.person,
                    Colors.blue,
                    'Manage your health records and appointments',
                  ),
                  _buildRoleCard(
                    context,
                    'Doctor',
                    Icons.medical_services,
                    Colors.green,
                    'Provide medical care and manage patients',
                  ),
                  _buildRoleCard(
                    context,
                    'Caregiver',
                    Icons.favorite,
                    Colors.pink,
                    'Care for your loved ones',
                  ),
                  _buildRoleCard(
                    context,
                    'Hospital',
                    Icons.local_hospital,
                    Colors.red,
                    'Register your hospital for healthcare services',
                  ),
                  _buildRoleCard(
                    context,
                    'Pharmacy',
                    Icons.local_pharmacy,
                    Colors.orange,
                    'Register your pharmacy for medication services',
                  ),
                  _buildRoleCard(
                    context,
                    'Laboratory',
                    Icons.science,
                    Colors.purple,
                    'Register your lab for diagnostic services',
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    String role,
    IconData icon,
    Color color,
    String description,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _onRoleSelected(context, role),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                role,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
