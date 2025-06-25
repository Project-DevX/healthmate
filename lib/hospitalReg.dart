import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class HospitalRegistrationPage extends StatefulWidget {
  const HospitalRegistrationPage({super.key});

  @override
  State<HospitalRegistrationPage> createState() =>
      _HospitalRegistrationPageState();
}

class _HospitalRegistrationPageState extends State<HospitalRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  String? _selectedType;
  File? _certificateFile;
  String? _certificateFileName;
  bool _isLoading = false;
  bool _acceptedTerms = false;

  final List<String> _typeOptions = ['General', 'Specialty', 'Clinic', 'Other'];

  final _institutionNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  String? _selectedInstitutionType;
  final List<String> _institutionTypeOptions = [
    'Hospital',
    'Laboratory',
    'Pharmacy',
  ];

  // Contact Information
  final _officialEmailController = TextEditingController();
  final _hotlineController = TextEditingController();
  final _institutionAddressController = TextEditingController();
  final _websiteController = TextEditingController();

  // Authorized Representative
  final _repNameController = TextEditingController();
  final _repDesignationController = TextEditingController();
  final _repContactController = TextEditingController();
  final _repEmailController = TextEditingController();

  // Document Uploads
  File? _businessCertFile;
  String? _businessCertFileName;
  File? _healthDeptApprovalFile;
  String? _healthDeptApprovalFileName;
  File? _pharmacyLicenseFile;
  String? _pharmacyLicenseFileName;

  @override
  void dispose() {
    _hospitalNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _registrationNumberController.dispose();
    _institutionNameController.dispose();
    _licenseNumberController.dispose();
    _officialEmailController.dispose();
    _hotlineController.dispose();
    _institutionAddressController.dispose();
    _websiteController.dispose();
    _repNameController.dispose();
    _repDesignationController.dispose();
    _repContactController.dispose();
    _repEmailController.dispose();
    _certificateFile = null;
    _certificateFileName = null;
    _businessCertFile = null;
    _businessCertFileName = null;
    _healthDeptApprovalFile = null;
    _healthDeptApprovalFileName = null;
    _pharmacyLicenseFile = null;
    _pharmacyLicenseFileName = null;
    _selectedInstitutionType = null;
    super.dispose();
  }

  Future<void> _pickCertificate() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null) {
        setState(() {
          _certificateFile = File(result.files.single.path!);
          _certificateFileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  Future<String?> _uploadFile(File file, String fileName) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'hospital_certificates/$fileName',
      );
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickFile(
    Function(File, String) setter,
    List<String> allowedExtensions,
  ) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (result != null) {
        setter(File(result.files.single.path!), result.files.single.name);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  Future<void> _registerHospital() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedInstitutionType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select institution type')),
      );
      return;
    }
    if (_businessCertFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your business registration certificate'),
        ),
      );
      return;
    }
    if ((_selectedInstitutionType == 'Hospital' ||
            _selectedInstitutionType == 'Laboratory') &&
        _healthDeptApprovalFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload Health Department Approval'),
        ),
      );
      return;
    }
    if (_selectedInstitutionType == 'Pharmacy' &&
        _pharmacyLicenseFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload Pharmacy License')),
      );
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must accept the Terms & Conditions to register.'),
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _officialEmailController.text.trim(),
            password: _passwordController.text,
          );
      String? businessCertUrl;
      String? healthDeptApprovalUrl;
      String? pharmacyLicenseUrl;
      if (_businessCertFile != null) {
        businessCertUrl = await _uploadFile(
          _businessCertFile!,
          _businessCertFileName!,
        );
      }
      if (_healthDeptApprovalFile != null) {
        healthDeptApprovalUrl = await _uploadFile(
          _healthDeptApprovalFile!,
          _healthDeptApprovalFileName!,
        );
      }
      if (_pharmacyLicenseFile != null) {
        pharmacyLicenseUrl = await _uploadFile(
          _pharmacyLicenseFile!,
          _pharmacyLicenseFileName!,
        );
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'institutionName': _institutionNameController.text.trim(),
            'institutionType': _selectedInstitutionType,
            'licenseNumber': _licenseNumberController.text.trim(),
            'officialEmail': _officialEmailController.text.trim(),
            'hotline': _hotlineController.text.trim(),
            'address': _institutionAddressController.text.trim(),
            'website': _websiteController.text.trim(),
            'repName': _repNameController.text.trim(),
            'repDesignation': _repDesignationController.text.trim(),
            'repContact': _repContactController.text.trim(),
            'repEmail': _repEmailController.text.trim(),
            'businessCertUrl': businessCertUrl,
            'healthDeptApprovalUrl': healthDeptApprovalUrl,
            'pharmacyLicenseUrl': pharmacyLicenseUrl,
            'userType': 'hospital',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for this email';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Institution Registration')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Register Your Institution',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Institution Details
                TextFormField(
                  controller: _institutionNameController,
                  decoration: const InputDecoration(
                    labelText: 'Institution Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_hospital),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter institution name'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedInstitutionType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _institutionTypeOptions.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedInstitutionType = newValue;
                    });
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select institution type'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _licenseNumberController,
                  decoration: const InputDecoration(
                    labelText: 'License/Registration Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.confirmation_number),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter license/registration number'
                      : null,
                ),
                const SizedBox(height: 24),
                // Contact Information
                TextFormField(
                  controller: _officialEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Official Email Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email address';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hotlineController,
                  decoration: const InputDecoration(
                    labelText: 'Hotline/Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter hotline/phone number'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _institutionAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Institution Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter address'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website URL (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.language),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 24),
                // Authorized Representative
                Text(
                  'Authorized Representative',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _repNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter representative name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _repDesignationController,
                  decoration: const InputDecoration(
                    labelText: 'Designation',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter designation'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _repContactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter contact number'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _repEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Official Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email address';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Document Uploads
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _businessCertFileName ??
                        'Upload Business Registration Certificate',
                  ),
                  onPressed: () => _pickFile((file, name) {
                    setState(() {
                      _businessCertFile = file;
                      _businessCertFileName = name;
                    });
                  }, ['pdf', 'jpg', 'jpeg', 'png']),
                ),
                const SizedBox(height: 16),
                if (_selectedInstitutionType == 'Hospital' ||
                    _selectedInstitutionType == 'Laboratory')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _healthDeptApprovalFileName ??
                          'Upload Health Department Approval',
                    ),
                    onPressed: () => _pickFile((file, name) {
                      setState(() {
                        _healthDeptApprovalFile = file;
                        _healthDeptApprovalFileName = name;
                      });
                    }, ['pdf', 'jpg', 'jpeg', 'png']),
                  ),
                if (_selectedInstitutionType == 'Hospital' ||
                    _selectedInstitutionType == 'Laboratory')
                  const SizedBox(height: 16),
                if (_selectedInstitutionType == 'Pharmacy')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _pharmacyLicenseFileName ?? 'Upload Pharmacy License',
                    ),
                    onPressed: () => _pickFile((file, name) {
                      setState(() {
                        _pharmacyLicenseFile = file;
                        _pharmacyLicenseFileName = name;
                      });
                    }, ['pdf', 'jpg', 'jpeg', 'png']),
                  ),
                if (_selectedInstitutionType == 'Pharmacy')
                  const SizedBox(height: 16),
                // Password fields
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter a password'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please confirm your password'
                      : null,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _acceptedTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptedTerms = value ?? false;
                    });
                  },
                  title: const Text('I accept the Terms & Conditions'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerHospital,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
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
      ),
    );
  }
}
