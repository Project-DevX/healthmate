import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math';
import 'config/testing_config.dart';

class LabRegistrationPage extends StatefulWidget {
  const LabRegistrationPage({super.key});

  @override
  State<LabRegistrationPage> createState() => _LabRegistrationPageState();
}

class _LabRegistrationPageState extends State<LabRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _acceptedTerms = false;

  // Laboratory Details
  final _labNameController = TextEditingController();
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

  // Additional Lab-Specific Fields
  final _operatingHoursController = TextEditingController();
  final _testTypesController = TextEditingController();
  final _turnaroundTimeController = TextEditingController();
  final _accreditationController = TextEditingController();

  // Password
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Document Uploads
  File? _labLicenseFile;
  String? _labLicenseFileName;
  File? _businessCertFile;
  String? _businessCertFileName;
  File? _accreditationFile;
  String? _accreditationFileName;

  final List<Map<String, dynamic>> _sampleLabs = [
    {
      'labName': 'Precision Diagnostics Lab',
      'licenseNumber': 'LAB001',
      'officialEmail': 'info.precisiondiag@gmail.com',
      'hotline': '+1234567800',
      'address': '123 Laboratory Avenue, Medical City, MC 12345',
      'website': 'www.precisiondiagnostics.com',
      'repName': 'Dr. Michael Johnson',
      'repDesignation': 'Laboratory Director',
      'repContact': '+1234567801',
      'repEmail': 'michael.johnson@precisiondiag.com',
      'operatingHours': '24/7 Emergency Services, Regular: 6:00 AM - 10:00 PM',
      'testTypes':
          'Blood Tests, Urine Analysis, Microbiology, Pathology, Radiology, Molecular Diagnostics',
      'turnaroundTime':
          'Routine: 24-48 hours, Urgent: 2-4 hours, STAT: 30-60 minutes',
      'accreditation': 'CAP, CLIA, ISO 15189',
      'password': 'lab123',
    },
    {
      'labName': 'Advanced Medical Laboratory',
      'licenseNumber': 'LAB002',
      'officialEmail': 'contact.advancedmed@gmail.com',
      'hotline': '+1234567802',
      'address': '456 Science Drive, Health Town, HT 67890',
      'website': 'www.advancedmedlab.com',
      'repName': 'Dr. Sarah Chen',
      'repDesignation': 'Chief Laboratory Scientist',
      'repContact': '+1234567803',
      'repEmail': 'sarah.chen@advancedmed.com',
      'operatingHours': '5:00 AM - 11:00 PM, Emergency On-Call',
      'testTypes':
          'Clinical Chemistry, Hematology, Immunology, Genetics, Cytology, Histopathology',
      'turnaroundTime':
          'Standard: 12-24 hours, Priority: 1-2 hours, Critical: 15-30 minutes',
      'accreditation': 'NABL, CAP, FDA Registered',
      'password': 'lab123',
    },
    {
      'labName': 'Regional Health Laboratory',
      'licenseNumber': 'LAB003',
      'officialEmail': 'admin.regionalhealth@gmail.com',
      'hotline': '+1234567804',
      'address': '789 Research Boulevard, Science City, SC 54321',
      'website': 'www.regionalhealthlab.com',
      'repName': 'Dr. Emily Rodriguez',
      'repDesignation': 'Director of Laboratory Services',
      'repContact': '+1234567805',
      'repEmail': 'emily.rodriguez@regionalhealth.com',
      'operatingHours': '7:00 AM - 9:00 PM, 24/7 Critical Care Support',
      'testTypes':
          'Routine Labs, Cardiac Markers, Toxicology, Infectious Disease, Endocrinology',
      'turnaroundTime':
          'Regular: 4-6 hours, Urgent: 1 hour, Emergency: 20 minutes',
      'accreditation': 'Joint Commission, CLIA, AABB',
      'password': 'lab123',
    },
  ];

  @override
  void dispose() {
    _labNameController.dispose();
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
    _testTypesController.dispose();
    _turnaroundTimeController.dispose();
    _accreditationController.dispose();
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
        'lab_documents/$fileName',
      );
      await storageRef.putFile(file);
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> _registerLab() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Skip document upload requirements in testing mode
    if (!TestingConfig.skipDocumentUploads) {
      if (_labLicenseFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload your laboratory license'),
          ),
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

      String? labLicenseUrl;
      String? businessCertUrl;
      String? accreditationUrl;

      if (_labLicenseFile != null) {
        labLicenseUrl = await _uploadFile(
          _labLicenseFile!,
          _labLicenseFileName!,
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
            'institutionName': _labNameController.text.trim(),
            'institutionType': 'Laboratory',
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
            'testTypes': _testTypesController.text.trim(),
            'turnaroundTime': _turnaroundTimeController.text.trim(),
            'accreditation': _accreditationController.text.trim(),
            'labLicenseUrl': labLicenseUrl,
            'businessCertUrl': businessCertUrl,
            'accreditationUrl': accreditationUrl,
            'userType': 'lab',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laboratory registration successful!')),
        );

        // In testing mode, redirect to login with pre-filled credentials
        if (TestingConfig.isTestingMode) {
          Navigator.pushReplacementNamed(
            context,
            '/login',
            arguments: {
              'email': _officialEmailController.text.trim(),
              'userType': 'lab',
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
    final sampleData = _sampleLabs[random.nextInt(_sampleLabs.length)];

    setState(() {
      _labNameController.text = sampleData['labName'];
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
      _testTypesController.text = sampleData['testTypes'];
      _turnaroundTimeController.text = sampleData['turnaroundTime'];
      _accreditationController.text = sampleData['accreditation'];
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
        title: const Text('Laboratory Registration'),
        backgroundColor: Colors.blue,
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
                const Icon(Icons.science, size: 80, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Register Your Laboratory',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join our network to provide diagnostic services',
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
                      color: Colors.orange.withOpacity(0.1),
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
                          label: const Text('Fill Sample Laboratory Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Laboratory Information Section
                const Text(
                  'Laboratory Information',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _labNameController,
                  decoration: const InputDecoration(
                    labelText: 'Laboratory Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.science),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter laboratory name'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _licenseNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Laboratory License Number *',
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
                    labelText: 'Laboratory Address *',
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

                // Services Information
                const Text(
                  'Laboratory Services',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _operatingHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Operating Hours *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                    hintText:
                        'e.g., 24/7 Emergency, Regular: 6:00 AM - 10:00 PM',
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter operating hours'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _testTypesController,
                  decoration: const InputDecoration(
                    labelText: 'Test Types Offered *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services),
                    hintText:
                        'e.g., Blood Tests, Urine Analysis, Microbiology, Pathology',
                  ),
                  maxLines: 3,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter test types offered'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _turnaroundTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Report Turnaround Time *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule),
                    hintText:
                        'e.g., Routine: 24-48 hours, Urgent: 2-4 hours, STAT: 30-60 minutes',
                  ),
                  maxLines: 2,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter turnaround time'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _accreditationController,
                  decoration: const InputDecoration(
                    labelText: 'Accreditations & Certifications',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.verified),
                    hintText: 'e.g., CAP, CLIA, ISO 15189, NABL',
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
                    hintText:
                        'e.g., Laboratory Director, Chief Laboratory Scientist',
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
                      color: Colors.green.withOpacity(0.1),
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
                    _labLicenseFileName ?? 'Upload Laboratory License',
                  ),
                  onPressed: () => _pickFile((file, name) {
                    setState(() {
                      _labLicenseFile = file;
                      _labLicenseFileName = name;
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
                    onPressed: _isLoading ? null : _registerLab,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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
                            'Register Laboratory',
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
