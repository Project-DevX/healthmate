import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class DoctorProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DoctorProfileEditScreen({super.key, required this.userData});

  @override
  State<DoctorProfileEditScreen> createState() => _DoctorProfileEditScreenState();
}

class _DoctorProfileEditScreenState extends State<DoctorProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _licenseController;
  late TextEditingController _experienceController;
  late TextEditingController _bioController;
  late TextEditingController _addressController;
  late TextEditingController _emergencyContactController;

  String _selectedSpecialization = '';
  String _selectedGender = '';
  List<String> _selectedLanguages = [];
  bool _isLoading = false;

  final List<String> _specializations = [
    'General Medicine',
    'Cardiology',
    'Dermatology',
    'Neurology',
    'Orthopedics',
    'Pediatrics',
    'Psychiatry',
    'Radiology',
    'Surgery',
    'Gynecology',
    'Oncology',
    'Ophthalmology',
    'ENT',
    'Anesthesiology',
    'Emergency Medicine',
  ];

  final List<String> _languages = [
    'English',
    'Sinhala',
    'Tamil',
    'Hindi',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _firstNameController = TextEditingController(text: widget.userData['firstName'] ?? '');
    _lastNameController = TextEditingController(text: widget.userData['lastName'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phoneNumber'] ?? '');
    _licenseController = TextEditingController(text: widget.userData['licenseNumber'] ?? '');
    _experienceController = TextEditingController(text: widget.userData['yearsOfExperience']?.toString() ?? '');
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    _addressController = TextEditingController(text: widget.userData['address'] ?? '');
    _emergencyContactController = TextEditingController(text: widget.userData['emergencyContact'] ?? '');

    _selectedSpecialization = widget.userData['specialization'] ?? _specializations.first;
    _selectedGender = widget.userData['gender'] ?? 'Male';
    _selectedLanguages = List<String>.from(widget.userData['languages'] ?? ['English']);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'licenseNumber': _licenseController.text.trim(),
        'yearsOfExperience': int.tryParse(_experienceController.text) ?? 0,
        'bio': _bioController.text.trim(),
        'address': _addressController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'specialization': _selectedSpecialization,
        'gender': _selectedGender,
        'languages': _selectedLanguages,
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppTheme.doctorColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text(
              'SAVE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo Section
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: AppTheme.doctorColor.withValues(alpha: 0.2),
                            child: Icon(
                              Icons.medical_services,
                              size: 60,
                              color: AppTheme.doctorColor,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppTheme.doctorColor,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, color: Colors.white),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Photo upload feature coming soon')),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Personal Information
                    _buildSectionHeader('Personal Information', Icons.person),
                    _buildTextFormField(
                      controller: _firstNameController,
                      label: 'First Name',
                      validator: (value) => value?.isEmpty == true ? 'First name is required' : null,
                    ),
                    _buildTextFormField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      validator: (value) => value?.isEmpty == true ? 'Last name is required' : null,
                    ),
                    _buildDropdownField(
                      label: 'Gender',
                      value: _selectedGender,
                      items: ['Male', 'Female', 'Other'],
                      onChanged: (value) => setState(() => _selectedGender = value!),
                    ),
                    _buildTextFormField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      validator: (value) => value?.isEmpty == true ? 'Phone number is required' : null,
                    ),
                    _buildTextFormField(
                      controller: _addressController,
                      label: 'Address',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 24),

                    // Professional Information
                    _buildSectionHeader('Professional Information', Icons.medical_services),
                    _buildDropdownField(
                      label: 'Specialization',
                      value: _selectedSpecialization,
                      items: _specializations,
                      onChanged: (value) => setState(() => _selectedSpecialization = value!),
                    ),
                    _buildTextFormField(
                      controller: _licenseController,
                      label: 'License Number',
                      validator: (value) => value?.isEmpty == true ? 'License number is required' : null,
                    ),
                    _buildTextFormField(
                      controller: _experienceController,
                      label: 'Years of Experience',
                      keyboardType: TextInputType.number,
                    ),
                    _buildLanguageSelector(),
                    _buildTextFormField(
                      controller: _bioController,
                      label: 'Professional Bio',
                      maxLines: 4,
                      hintText: 'Tell patients about your experience and approach...',
                    ),

                    const SizedBox(height: 24),

                    // Emergency Contact
                    _buildSectionHeader('Emergency Contact', Icons.emergency),
                    _buildTextFormField(
                      controller: _emergencyContactController,
                      label: 'Emergency Contact Number',
                      keyboardType: TextInputType.phone,
                      hintText: 'Alternative contact number',
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.doctorColor),
          const SizedBox(width: 8),
          Text(title, style: AppTheme.headingMedium),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppTheme.doctorColor),
          ),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppTheme.doctorColor),
          ),
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Languages Spoken', style: AppTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _languages.map((language) => FilterChip(
              label: Text(language),
              selected: _selectedLanguages.contains(language),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedLanguages.add(language);
                  } else {
                    _selectedLanguages.remove(language);
                  }
                });
              },
              selectedColor: AppTheme.doctorColor.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.doctorColor,
            )).toList(),
          ),
        ],
      ),
    );
  }
}
