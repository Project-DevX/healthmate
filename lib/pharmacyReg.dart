import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math';
import 'config/testing_config.dart';

class PharmacyRegistrationPage extends StatefulWidget {
  const PharmacyRegistrationPage({super.key});

  @override
  State<PharmacyRegistrationPage> createState() =>
      _PharmacyRegistrationPageState();
}

class _PharmacyRegistrationPageState extends State<PharmacyRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _acceptedTerms = false;

  // Pharmacy Details
  final _pharmacyNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _officialEmailController = TextEditingController();
  final _hotlineController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();

  // Authorized Representative
  final _repNameController = TextEditingController();
  final _repDesignationController = TextEditingController();
  final _repContactController = TextEditingController();
  final _repEmailController = TextEditingController();

  // Additional Pharmacy-Specific Fields
  final _operatingHoursController = TextEditingController();
  final _servicesController = TextEditingController();
  final _specialtiesController = TextEditingController();

  // Password
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Document Uploads
  File? _pharmacyLicenseFile;
  String? _pharmacyLicenseFileName;
  File? _businessCertFile;
  String? _businessCertFileName;

  final List<Map<String, dynamic>> _samplePharmacies = [
    {
      'pharmacyName': 'MediCare Pharmacy',
      'licenseNumber': 'PHARM001',
      'officialEmail': 'info.medicare@gmail.com',
      'hotline': '+1234567890',
      'address': '123 Health Street, Medical City, MC 12345',
      'website': 'www.medicarepharmacy.com',
      'repName': 'Dr. Sarah Johnson',
      'repDesignation': 'Chief Pharmacist',
      'repContact': '+1234567891',
      'repEmail': 'sarah.johnson@medicare.com',
      'operatingHours': '8:00 AM - 10:00 PM',
      'services':
          'Prescription Filling, Consultation, Home Delivery, Health Checkups',
      'specialties':
          'Clinical Pharmacy, Pharmaceutical Care, Medication Therapy Management',
      'password': 'pharmacy123',
    },
    {
      'pharmacyName': 'HealthPlus Pharmacy',
      'licenseNumber': 'PHARM002',
      'officialEmail': 'contact.healthplus@gmail.com',
      'hotline': '+1234567892',
      'address': '456 Wellness Avenue, Health Town, HT 67890',
      'website': 'www.healthpluspharmacy.com',
      'repName': 'PharmD Michael Chen',
      'repDesignation': 'Pharmacy Manager',
      'repContact': '+1234567893',
      'repEmail': 'michael.chen@healthplus.com',
      'operatingHours': '7:00 AM - 11:00 PM',
      'services':
          'Prescription Services, Vaccinations, Health Screening, Compounding',
      'specialties': 'Oncology Pharmacy, Geriatric Care, Diabetes Management',
      'password': 'pharmacy123',
    },
    {
      'pharmacyName': 'Community Care Pharmacy',
      'licenseNumber': 'PHARM003',
      'officialEmail': 'admin.communitycare@gmail.com',
      'hotline': '+1234567894',
      'address': '789 Community Road, Care City, CC 54321',
      'website': 'www.communitycarepharmacy.com',
      'repName': 'Dr. Emily Rodriguez',
      'repDesignation': 'Director of Pharmacy',
      'repContact': '+1234567895',
      'repEmail': 'emily.rodriguez@communitycare.com',
      'operatingHours': '6:00 AM - 12:00 AM',
      'services':
          ' 24/7 Emergency Services, Insurance Processing, Generic Alternatives',
      'specialties': 'Psychiatric Pharmacy, Pediatric Care, Pain Management',
      'password': 'pharmacy123',
    },
  ];

  @override
  void dispose() {
    _pharmacyNameController.dispose();
    _licenseNumberController.dispose();
    _officialEmailController.dispose();
    _hotlineController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _repNameController.dispose();
    _repDesignationController.dispose();
    _repContactController.dispose();
    _repEmailController.dispose();
    _operatingHoursController.dispose();
    _servicesController.dispose();
    _specialtiesController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(
    Function(File, String) onFilePicked,
    List<String> allowedExtensions,
  ) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        onFilePicked(file, fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  Future<String> _uploadFile(File file, String fileName) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'pharmacy_documents/$fileName',
      );
      await storageRef.putFile(file);
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> _registerPharmacy() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Skip document upload requirements in testing mode
    if (!TestingConfig.skipDocumentUploads) {
      if (_pharmacyLicenseFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload your pharmacy license')),
        );
        return;
      }
      if (_businessCertFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please upload your business registration certificate',
            ),
          ),
        );
        return;
      }
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

      String? pharmacyLicenseUrl;
      String? businessCertUrl;

      if (_pharmacyLicenseFile != null) {
        pharmacyLicenseUrl = await _uploadFile(
          _pharmacyLicenseFile!,
          _pharmacyLicenseFileName!,
        );
      }
      if (_businessCertFile != null) {
        businessCertUrl = await _uploadFile(
          _businessCertFile!,
          _businessCertFileName!,
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'institutionName': _pharmacyNameController.text.trim(),
            'institutionType': 'Pharmacy',
            'licenseNumber': _licenseNumberController.text.trim(),
            'officialEmail': _officialEmailController.text.trim(),
            'hotline': _hotlineController.text.trim(),
            'address': _addressController.text.trim(),
            'website': _websiteController.text.trim(),
            'repName': _repNameController.text.trim(),
            'repDesignation': _repDesignationController.text.trim(),
            'repContact': _repContactController.text.trim(),
            'repEmail': _repEmailController.text.trim(),
            'operatingHours': _operatingHoursController.text.trim(),
            'services': _servicesController.text.trim(),
            'specialties': _specialtiesController.text.trim(),
            'pharmacyLicenseUrl': pharmacyLicenseUrl,
            'businessCertUrl': businessCertUrl,
            'userType': 'pharmacy',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pharmacy registration successful!')),
        );

        // In testing mode, redirect to login with pre-filled credentials
        if (TestingConfig.isTestingMode) {
          Navigator.pushReplacementNamed(
            context,
            '/login',
            arguments: {
              'email': _officialEmailController.text.trim(),
              'userType': 'pharmacy',
            },
          );
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
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

  void _fillSampleData() {
    final random = Random();
    final sampleData =
        _samplePharmacies[random.nextInt(_samplePharmacies.length)];

    setState(() {
      _pharmacyNameController.text = sampleData['pharmacyName'];
      _licenseNumberController.text = sampleData['licenseNumber'];
      _officialEmailController.text = sampleData['officialEmail'];
      _hotlineController.text = sampleData['hotline'];
      _addressController.text = sampleData['address'];
      _websiteController.text = sampleData['website'];
      _repNameController.text = sampleData['repName'];
      _repDesignationController.text = sampleData['repDesignation'];
      _repContactController.text = sampleData['repContact'];
      _repEmailController.text = sampleData['repEmail'];
      _operatingHoursController.text = sampleData['operatingHours'];
      _servicesController.text = sampleData['services'];
      _specialtiesController.text = sampleData['specialties'];
      _passwordController.text = sampleData['password'];
      _confirmPasswordController.text = sampleData['password'];
      _acceptedTerms = true;
    });

    if (TestingConfig.skipDocumentUploads) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🧪 Sample data filled! Testing mode: Document uploads bypassed',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Registration'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Icon(Icons.local_pharmacy, size: 80, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'Register Your Pharmacy',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join our network to provide pharmaceutical services',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Debug button for testing
                if (kDebugMode || TestingConfig.showDebugUI) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '🧪 TESTING MODE ACTIVE',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _fillSampleData,
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text('Fill Sample Pharmacy Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Pharmacy Information Section
                const Text(
                  'Pharmacy Information',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _pharmacyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Pharmacy Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_pharmacy),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter pharmacy name'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _licenseNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Pharmacy License Number *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter license number'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _officialEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Official Email *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _hotlineController,
                  decoration: const InputDecoration(
                    labelText: 'Hotline Number *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter hotline number'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Pharmacy Address *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter address'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.web),
                  ),
                ),
                const SizedBox(height: 24),

                // Operating Hours and Services
                const Text(
                  'Services Information',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _operatingHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Operating Hours *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                    hintText: 'e.g., 8:00 AM - 10:00 PM',
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter operating hours'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _servicesController,
                  decoration: const InputDecoration(
                    labelText: 'Services Offered *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services),
                    hintText:
                        'e.g., Prescription Filling, Consultation, Home Delivery',
                  ),
                  maxLines: 3,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter services offered'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _specialtiesController,
                  decoration: const InputDecoration(
                    labelText: 'Pharmacy Specialties (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.star),
                    hintText:
                        'e.g., Clinical Pharmacy, Medication Therapy Management',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Authorized Representative Section
                const Text(
                  'Authorized Representative',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _repNameController,
                  decoration: const InputDecoration(
                    labelText: 'Representative Name *',
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
                    labelText: 'Designation *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                    hintText: 'e.g., Chief Pharmacist, Pharmacy Manager',
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter designation'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _repContactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter contact number'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _repEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Representative Email *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter representative email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Document Uploads
                if (TestingConfig.isTestingMode) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '✅ TESTING MODE: Document uploads are OPTIONAL and will be bypassed during registration',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(
                    'Document Uploads (Optional in Testing Mode)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  const Text(
                    'Required Document Uploads',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                ],

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
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _businessCertFileName ?? 'Upload Business Registration',
                  ),
                  onPressed: () => _pickFile((file, name) {
                    setState(() {
                      _businessCertFile = file;
                      _businessCertFileName = name;
                    });
                  }, ['pdf', 'jpg', 'jpeg', 'png']),
                ),
                const SizedBox(height: 24),

                // Password Section
                const Text(
                  'Account Security',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
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
                    labelText: 'Confirm Password *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Terms and Conditions
                CheckboxListTile(
                  title: const Text('I accept the Terms & Conditions'),
                  value: _acceptedTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptedTerms = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 24),

                // Register Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerPharmacy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
                            'Register Pharmacy',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Back to login
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
