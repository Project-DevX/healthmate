import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math';
import 'config/testing_config.dart';

class HospitalRegistrationPage extends StatefulWidget {
  const HospitalRegistrationPage({super.key});

  @override
  State<HospitalRegistrationPage> createState() =>
      _HospitalRegistrationPageState();
}

class _HospitalRegistrationPageState extends State<HospitalRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _acceptedTerms = false;

  // Hospital Details
  final _hospitalNameController = TextEditingController();
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

  // Additional Hospital-Specific Fields
  final _specialtiesController = TextEditingController();
  final _bedsController = TextEditingController();
  final _emergencyServicesController = TextEditingController();
  final _facilityTypeController = TextEditingController();

  // Password
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Document Uploads
  File? _hospitalLicenseFile;
  String? _hospitalLicenseFileName;
  File? _businessCertFile;
  String? _businessCertFileName;
  File? _accreditationFile;
  String? _accreditationFileName;

  final List<Map<String, dynamic>> _sampleHospitals = [
    {
      'hospitalName': 'City General Hospital',
      'licenseNumber': 'HOSP001',
      'officialEmail': 'admin.citygeneral@gmail.com',
      'hotline': '+1234567890',
      'address': '123 Medical Drive, Healthcare City, HC 12345',
      'website': 'www.citygeneral.com',
      'repName': 'Dr. John Smith',
      'repDesignation': 'Chief Medical Officer',
      'repContact': '+1234567891',
      'repEmail': 'cmo.citygeneral@gmail.com',
      'specialties':
          'Cardiology, Neurology, Oncology, Emergency Medicine, Surgery',
      'beds': '250',
      'emergencyServices': '24/7 Emergency Room, Trauma Center, ICU, CCU',
      'facilityType': 'Tertiary Care Hospital',
      'password': 'hospital123',
    },
    {
      'hospitalName': 'Metro Medical Center',
      'licenseNumber': 'HOSP002',
      'officialEmail': 'info.metromedical@gmail.com',
      'hotline': '+1234567892',
      'address': '456 Health Avenue, Metro City, MC 67890',
      'website': 'www.metromedical.com',
      'repName': 'Dr. Sarah Johnson',
      'repDesignation': 'Medical Director',
      'repContact': '+1234567893',
      'repEmail': 'sarah.johnson@metromedical.com',
      'specialties':
          'Pediatrics, Obstetrics, Orthopedics, Radiology, Laboratory Services',
      'beds': '180',
      'emergencyServices':
          'Emergency Department, Ambulance Services, Surgical Suites',
      'facilityType': 'Secondary Care Hospital',
      'password': 'hospital123',
    },
    {
      'hospitalName': 'Community Health Hospital',
      'licenseNumber': 'HOSP003',
      'officialEmail': 'contact.communityhealth@gmail.com',
      'hotline': '+1234567894',
      'address': '789 Community Road, Health Town, HT 54321',
      'website': 'www.communityhealth.com',
      'repName': 'Dr. Michael Rodriguez',
      'repDesignation': 'Hospital Administrator',
      'repContact': '+1234567895',
      'repEmail': 'michael.rodriguez@communityhealth.com',
      'specialties':
          'Family Medicine, Internal Medicine, Psychiatry, Rehabilitation',
      'beds': '120',
      'emergencyServices':
          'Urgent Care, Mental Health Crisis Support, Outpatient Services',
      'facilityType': 'Community Hospital',
      'password': 'hospital123',
    },
  ];

  @override
  void dispose() {
    _hospitalNameController.dispose();
    _licenseNumberController.dispose();
    _officialEmailController.dispose();
    _hotlineController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _repNameController.dispose();
    _repDesignationController.dispose();
    _repContactController.dispose();
    _repEmailController.dispose();
    _specialtiesController.dispose();
    _bedsController.dispose();
    _emergencyServicesController.dispose();
    _facilityTypeController.dispose();
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
        'hospital_documents/$fileName',
      );
      await storageRef.putFile(file);
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> _registerHospital() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Skip document upload requirements in testing mode
    if (!TestingConfig.skipDocumentUploads) {
      if (_hospitalLicenseFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload your hospital license')),
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

      String? hospitalLicenseUrl;
      String? businessCertUrl;
      String? accreditationUrl;

      if (_hospitalLicenseFile != null) {
        hospitalLicenseUrl = await _uploadFile(
          _hospitalLicenseFile!,
          _hospitalLicenseFileName!,
        );
      }
      if (_businessCertFile != null) {
        businessCertUrl = await _uploadFile(
          _businessCertFile!,
          _businessCertFileName!,
        );
      }
      if (_accreditationFile != null) {
        accreditationUrl = await _uploadFile(
          _accreditationFile!,
          _accreditationFileName!,
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'institutionName': _hospitalNameController.text.trim(),
            'institutionType': 'Hospital',
            'licenseNumber': _licenseNumberController.text.trim(),
            'officialEmail': _officialEmailController.text.trim(),
            'hotline': _hotlineController.text.trim(),
            'address': _addressController.text.trim(),
            'website': _websiteController.text.trim(),
            'repName': _repNameController.text.trim(),
            'repDesignation': _repDesignationController.text.trim(),
            'repContact': _repContactController.text.trim(),
            'repEmail': _repEmailController.text.trim(),
            'specialties': _specialtiesController.text.trim(),
            'beds': _bedsController.text.trim(),
            'emergencyServices': _emergencyServicesController.text.trim(),
            'facilityType': _facilityTypeController.text.trim(),
            'hospitalLicenseUrl': hospitalLicenseUrl,
            'businessCertUrl': businessCertUrl,
            'accreditationUrl': accreditationUrl,
            'userType': 'hospital',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hospital registration successful!')),
        );

        // In testing mode, redirect to login with pre-filled credentials
        if (TestingConfig.isTestingMode) {
          Navigator.pushReplacementNamed(
            context,
            '/login',
            arguments: {
              'email': _officialEmailController.text.trim(),
              'userType': 'hospital',
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
        _sampleHospitals[random.nextInt(_sampleHospitals.length)];

    setState(() {
      _hospitalNameController.text = sampleData['hospitalName'];
      _licenseNumberController.text = sampleData['licenseNumber'];
      _officialEmailController.text = sampleData['officialEmail'];
      _hotlineController.text = sampleData['hotline'];
      _addressController.text = sampleData['address'];
      _websiteController.text = sampleData['website'];
      _repNameController.text = sampleData['repName'];
      _repDesignationController.text = sampleData['repDesignation'];
      _repContactController.text = sampleData['repContact'];
      _repEmailController.text = sampleData['repEmail'];
      _specialtiesController.text = sampleData['specialties'];
      _bedsController.text = sampleData['beds'];
      _emergencyServicesController.text = sampleData['emergencyServices'];
      _facilityTypeController.text = sampleData['facilityType'];
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
        title: const Text('Hospital Registration'),
        backgroundColor: Colors.red,
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
                const Icon(Icons.local_hospital, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Register Your Hospital',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join our network to provide healthcare services',
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
                          label: const Text('Fill Sample Hospital Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Hospital Information Section
                const Text(
                  'Hospital Information',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _hospitalNameController,
                  decoration: const InputDecoration(
                    labelText: 'Hospital Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_hospital),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter hospital name'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _licenseNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Hospital License Number *',
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
                    labelText: 'Hospital Address *',
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

                // Hospital Facilities
                const Text(
                  'Hospital Facilities & Services',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _facilityTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Facility Type *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.apartment),
                    hintText:
                        'e.g., Tertiary Care, Secondary Care, Community Hospital',
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter facility type'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bedsController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Beds *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.bed),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter number of beds'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _specialtiesController,
                  decoration: const InputDecoration(
                    labelText: 'Medical Specialties *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services),
                    hintText:
                        'e.g., Cardiology, Neurology, Oncology, Emergency Medicine',
                  ),
                  maxLines: 3,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter medical specialties'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emergencyServicesController,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Services *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.emergency),
                    hintText:
                        'e.g., 24/7 Emergency Room, Trauma Center, ICU, CCU',
                  ),
                  maxLines: 2,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter emergency services'
                      : null,
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
                    hintText: 'e.g., Chief Medical Officer, Medical Director',
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
                    _hospitalLicenseFileName ?? 'Upload Hospital License',
                  ),
                  onPressed: () => _pickFile((file, name) {
                    setState(() {
                      _hospitalLicenseFile = file;
                      _hospitalLicenseFileName = name;
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
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _accreditationFileName ??
                        'Upload Accreditation Certificates (Optional)',
                  ),
                  onPressed: () => _pickFile((file, name) {
                    setState(() {
                      _accreditationFile = file;
                      _accreditationFileName = name;
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
                    onPressed: _isLoading ? null : _registerHospital,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
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
                            'Register Hospital',
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
