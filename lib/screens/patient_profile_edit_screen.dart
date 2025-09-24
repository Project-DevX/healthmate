import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class PatientProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PatientProfileEditScreen({super.key, required this.userData});

  @override
  State<PatientProfileEditScreen> createState() =>
      _PatientProfileEditScreenState();
}

class _PatientProfileEditScreenState extends State<PatientProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _emergencyContactPhoneController;

  String _selectedGender = '';
  DateTime? _selectedDateOfBirth;
  bool _isLoading = false;

  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final userData = widget.userData;
    _firstNameController = TextEditingController(
      text: _extractFirstName(userData['name'] ?? ''),
    );
    _lastNameController = TextEditingController(
      text: _extractLastName(userData['name'] ?? ''),
    );
    _phoneController = TextEditingController(text: userData['phone'] ?? '');
    _addressController = TextEditingController(text: userData['address'] ?? '');
    _emergencyContactController = TextEditingController(
      text: userData['emergencyContact'] ?? '',
    );
    _emergencyContactPhoneController = TextEditingController(
      text: userData['emergencyContactPhone'] ?? '',
    );

    _selectedGender = userData['gender'] ?? '';

    // Parse date of birth if available
    if (userData['dateOfBirth'] != null) {
      if (userData['dateOfBirth'] is Timestamp) {
        _selectedDateOfBirth = (userData['dateOfBirth'] as Timestamp).toDate();
      }
    }
  }

  String _extractFirstName(String fullName) {
    final parts = fullName.split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  String _extractLastName(String fullName) {
    final parts = fullName.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _emergencyContactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final updatedData = {
        'name':
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                .trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'gender': _selectedGender,
        'emergencyContact': _emergencyContactController.text.trim(),
        'emergencyContactPhone': _emergencyContactPhoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_selectedDateOfBirth != null) {
        updatedData['dateOfBirth'] = Timestamp.fromDate(_selectedDateOfBirth!);
      }

      await _firestore.collection('users').doc(user.uid).update(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDateOfBirth ??
          DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppTheme.primaryBlue,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: widget.userData['photoUrl'] != null
                          ? NetworkImage(widget.userData['photoUrl'])
                          : null,
                      child: widget.userData['photoUrl'] == null
                          ? Text(
                              widget.userData['name']?.isNotEmpty == true
                                  ? widget.userData['name'][0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(fontSize: 32),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // TODO: Implement photo upload
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Photo upload coming soon'),
                          ),
                        );
                      },
                      child: const Text('Change Photo'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Personal Information Section
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // First Name
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Last Name
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Last name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Date of Birth
              InkWell(
                onTap: _selectDateOfBirth,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake),
                  ),
                  child: Text(
                    _selectedDateOfBirth != null
                        ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                        : 'Select date of birth',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Gender
              DropdownButtonFormField<String>(
                value: _selectedGender.isNotEmpty ? _selectedGender : null,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                items: _genders.map((gender) {
                  return DropdownMenuItem(value: gender, child: Text(gender));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your gender';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              // Emergency Contact Section
              const Text(
                'Emergency Contact',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Emergency Contact Name
              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.contact_emergency),
                ),
              ),

              const SizedBox(height: 16),

              // Emergency Contact Phone
              TextFormField(
                controller: _emergencyContactPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
