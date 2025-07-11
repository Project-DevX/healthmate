import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math';
import 'config/testing_config.dart';

class CaregiverRegistrationPage extends StatefulWidget {
  const CaregiverRegistrationPage({super.key});

  @override
  State<CaregiverRegistrationPage> createState() =>
      _CaregiverRegistrationPageState();
}

class _CaregiverRegistrationPageState extends State<CaregiverRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nicController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _patientCodeController = TextEditingController();

  DateTime? _dateOfBirth;
  String? _selectedGender;
  String? _selectedType;
  File? _certFile;
  String? _certFileName;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];
  final List<String> _typeOptions = ['Family', 'Professional', 'Nurse'];

  final List<Map<String, dynamic>> _sampleCaregivers = [
    {
      'firstName': 'Mary',
      'lastName': 'Johnson',
      'email': 'mary.johnson.care@gmail.com',
      'password': 'password123',
      'relationship': 'Spouse',
      'patientCode': 'PAT001',
      'phone': '+1234567810',
    },
    {
      'firstName': 'David',
      'lastName': 'Miller',
      'email': 'david.miller.family@gmail.com',
      'password': 'password123',
      'relationship': 'Son',
      'patientCode': 'PAT002',
      'phone': '+1234567811',
    },
    {
      'firstName': 'Susan',
      'lastName': 'Garcia',
      'email': 'susan.garcia.caregiver@gmail.com',
      'password': 'password123',
      'relationship': 'Daughter',
      'patientCode': 'PAT003',
      'phone': '+1234567812',
    },
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _nicController.dispose();
    _inviteCodeController.dispose();
    _relationshipController.dispose();
    _patientCodeController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime birthDate) {
    final DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Future<void> _pickCertFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result != null) {
        setState(() {
          _certFile = File(result.files.single.path!);
          _certFileName = result.files.single.name;
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
      final storageRef = FirebaseStorage.instance.ref().child(
        'caregiver_certifications/$fileName',
      );
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> _registerCaregiver() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    // Skip document upload requirements in testing mode
    print(
      '🧪 Caregiver Registration - Testing Mode: ${TestingConfig.isTestingMode}',
    );
    print(
      '📁 Caregiver Registration - Skip Document Uploads: ${TestingConfig.skipDocumentUploads}',
    );

    if (!TestingConfig.skipDocumentUploads) {
      print(
        '📋 Caregiver Registration - Checking document upload requirements...',
      );
      if (_selectedType == 'Nurse' && _certFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please upload your certification or nursing license',
            ),
          ),
        );
        return;
      }
    } else {
      print('🧪 CAREGIVER TESTING MODE: Skipping document upload requirements');
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
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      String? certUrl;
      if (_selectedType == 'Nurse' && _certFile != null) {
        certUrl = await _uploadFile(_certFile!, _certFileName!);
      }
      final int age = _calculateAge(_dateOfBirth!);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'fullName': _fullNameController.text.trim(),
            'email': _emailController.text.trim(),
            'dateOfBirth': _dateOfBirth,
            'age': age,
            'gender': _selectedGender,
            'phone': _phoneController.text.trim(),
            'nicOrPassport': _nicController.text.trim(),
            'userType': 'caregiver',
            'caregiverType': _selectedType,
            'certificationUrl': certUrl,
            'inviteCode': _inviteCodeController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );

        // In testing mode, redirect to login with pre-filled credentials
        if (TestingConfig.isTestingMode) {
          Navigator.pushReplacementNamed(
            context,
            '/login',
            arguments: {
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
              'message':
                  '🧪 Testing Mode: Caregiver credentials auto-filled from registration',
            },
          );
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
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
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
        _sampleCaregivers[random.nextInt(_sampleCaregivers.length)];

    setState(() {
      _fullNameController.text =
          '${sampleData['firstName']} ${sampleData['lastName']}';
      _emailController.text = sampleData['email'];
      _passwordController.text = sampleData['password'];
      _confirmPasswordController.text = sampleData['password'];
      _relationshipController.text = sampleData['relationship'];
      _patientCodeController.text = sampleData['patientCode'];
      _phoneController.text = sampleData['phone'];

      // Set additional required fields
      _dateOfBirth = DateTime(
        1970 + random.nextInt(30),
        1 + random.nextInt(12),
        1 + random.nextInt(28),
      );
      _selectedGender = _genderOptions[random.nextInt(_genderOptions.length)];
      _selectedType = _typeOptions[random.nextInt(_typeOptions.length)];
      _nicController.text = 'NIC${1000000000 + random.nextInt(1000000000)}';
      _inviteCodeController.text = 'INV${random.nextInt(10000)}';
      _acceptedTerms = true;
    });

    // Show confirmation that testing mode is active
    if (TestingConfig.skipDocumentUploads) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
      appBar: AppBar(title: const Text('Caregiver Registration')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Your Caregiver Account',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter your full name'
                      : null,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _selectDateOfBirth(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      controller: TextEditingController(
                        text: _dateOfBirth == null
                            ? ''
                            : _dateOfBirth!.toLocal().toString().split(' ')[0],
                      ),
                      validator: (value) => _dateOfBirth == null
                          ? 'Please select your date of birth'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  items: _genderOptions
                      .map(
                        (gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedGender = value),
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select your gender'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nicController,
                  decoration: const InputDecoration(
                    labelText: 'NIC/Passport Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter your NIC or Passport Number'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter your email address'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter your phone number'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: _typeOptions
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedType = value),
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select caregiver type'
                      : null,
                ),
                if (_selectedType == 'Nurse') ...[
                  const SizedBox(height: 16),
                  if (TestingConfig.isTestingMode) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '✅ TESTING MODE: Nursing license upload is OPTIONAL',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _certFileName ??
                          'Upload Certification or Nursing License',
                    ),
                    onPressed: _pickCertFile,
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _inviteCodeController,
                  decoration: const InputDecoration(
                    labelText:
                        'Patient ID or Invite Code (if already created by the patient)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    // TODO: Implement request access logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request access feature coming soon.'),
                      ),
                    );
                  },
                  child: const Text(
                    'Request Access from existing patient accounts',
                  ),
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 24),
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
                ElevatedButton(
                  onPressed: _isLoading ? null : _registerCaregiver,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Register'),
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
                // Debug button - only visible in debug mode
                if (kDebugMode || TestingConfig.showDebugUI) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _fillSampleData,
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Fill Sample Data (DEBUG)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
