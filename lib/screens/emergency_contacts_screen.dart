import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          if (mounted) {
            setState(() {
              userData = userDoc.data();
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _callContact(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to make call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: AppTheme.primaryBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primary Emergency Contact from Profile
            const Text(
              'Primary Emergency Contact',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: const Icon(
                    Icons.contact_emergency,
                    color: Colors.orange,
                  ),
                ),
                title: Text(userData?['emergencyContact'] ?? 'Not set'),
                subtitle: Text(
                  userData?['emergencyContactPhone'] ?? 'No phone number',
                ),
                trailing: userData?['emergencyContactPhone'] != null
                    ? IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: () =>
                            _callContact(userData!['emergencyContactPhone']),
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/profile',
                ); // Navigate to profile edit
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Emergency Contact'),
            ),

            const SizedBox(height: 32),

            // Emergency Services
            const Text(
              'Emergency Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildEmergencyServiceCard(
              'Emergency Services (911)',
              'Call 911 for immediate emergency assistance',
              Icons.local_hospital,
              Colors.red,
              '911',
            ),

            _buildEmergencyServiceCard(
              'Poison Control',
              'For poisoning emergencies',
              Icons.science,
              Colors.purple,
              '18002221222', // US Poison Control
            ),

            _buildEmergencyServiceCard(
              'Suicide Prevention Lifeline',
              '24/7 support for mental health crises',
              Icons.psychology,
              Colors.blue,
              '988', // US Suicide Prevention Lifeline
            ),

            const SizedBox(height: 32),

            // Additional Contacts Section
            const Text(
              'Additional Emergency Contacts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.contacts, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Additional Contacts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add family members, friends, or other important contacts for emergency situations.',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Additional contacts feature coming soon',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Safety Tips
            const Text(
              'Emergency Safety Tips',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildSafetyTip(
              'Stay Calm',
              'Take deep breaths and assess the situation before acting.',
            ),

            _buildSafetyTip(
              'Call Emergency Services',
              'Always call emergency services first in life-threatening situations.',
            ),

            _buildSafetyTip(
              'Provide Clear Information',
              'When calling emergency services, provide your location and describe the situation clearly.',
            ),

            _buildSafetyTip(
              'Know Your Location',
              'Be aware of your current address and nearby landmarks.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyServiceCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String phoneNumber,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: Colors.green),
          onPressed: () => _callContact(phoneNumber),
        ),
      ),
    );
  }

  Widget _buildSafetyTip(String title, String description) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(description, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
