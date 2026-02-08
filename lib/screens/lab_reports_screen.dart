import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shared_models.dart';
import '../services/interconnect_service.dart';
import '../theme/app_theme.dart';

class LabReportsScreen extends StatefulWidget {
  final String doctorId;

  const LabReportsScreen({super.key, required this.doctorId});

  @override
  State<LabReportsScreen> createState() => _LabReportsScreenState();
}

class _LabReportsScreenState extends State<LabReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _patientNameController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _clinicalNotesController = TextEditingController();
  final _urgencyNotesController = TextEditingController();

  List<LabTest> _labTests = [];
  String _urgency = 'Routine';
  bool _isLoading = false;

  // Lab selection
  List<Map<String, dynamic>> _labs = [];
  String? _selectedLabId;

  final List<String> _urgencyOptions = ['Routine', 'Urgent', 'STAT'];

  @override
  void initState() {
    super.initState();
    _addLabTestField();
    _loadLabs();
  }

  Future<void> _loadLabs() async {
    try {
      final labsSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'lab')
          .get();

      setState(() {
        _labs = labsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['institutionName'] ?? data['name'] ?? 'Lab',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading labs: $e');
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientIdController.dispose();
    _clinicalNotesController.dispose();
    _urgencyNotesController.dispose();
    for (var test in _labTests) {
      test.dispose();
    }
    super.dispose();
  }

  void _addLabTestField() {
    setState(() {
      _labTests.add(LabTest());
    });
  }

  void _removeLabTestField(int index) {
    if (_labTests.length > 1) {
      setState(() {
        _labTests[index].dispose();
        _labTests.removeAt(index);
      });
    }
  }

  Future<void> _submitLabOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLabId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a lab'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get doctor name
      final doctorDoc = await _firestore
          .collection('users')
          .doc(widget.doctorId)
          .get();
      final doctorName = doctorDoc.data()?['fullName'] ?? 'Doctor';

      // Get selected lab name
      final selectedLab = _labs.firstWhere(
        (lab) => lab['id'] == _selectedLabId,
      );
      final labName = selectedLab['name'] as String;

      final patientName = _patientNameController.text.trim();
      final patientId = _patientIdController.text.trim();
      final notes = _clinicalNotesController.text.trim();
      final priority = _urgency.toLowerCase() == 'stat'
          ? 'critical'
          : _urgency.toLowerCase();

      // Create a lab_reports entry for each test via InterconnectService
      for (final test in _labTests) {
        final testName = test.testNameController.text.trim();
        if (testName.isEmpty) continue;

        final labReport = LabReport(
          id: '',
          patientId: patientId,
          patientName: patientName,
          labId: _selectedLabId!,
          labName: labName,
          doctorId: widget.doctorId,
          doctorName: doctorName,
          testType: test.category ?? 'Other',
          testName: testName,
          testDate: DateTime.now(),
          status: 'requested',
          notes:
              '$notes${test.instructionsController.text.trim().isNotEmpty ? '\nInstructions: ${test.instructionsController.text.trim()}' : ''}',
          createdAt: DateTime.now(),
        );

        await InterconnectService.requestLabTest(labReport);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lab order submitted successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting lab order: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearForm() {
    _patientNameController.clear();
    _patientIdController.clear();
    _clinicalNotesController.clear();
    _urgencyNotesController.clear();

    setState(() {
      for (var test in _labTests) {
        test.dispose();
      }
      _labTests.clear();
      _urgency = 'Routine';
      _addLabTestField();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppWidgets.buildAppBar(
        title: 'Order Lab Tests',
        userType: 'doctor',
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearForm,
            tooltip: 'Clear Form',
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
                    // Header card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.infoBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.science,
                                color: AppTheme.infoBlue,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Laboratory Test Order',
                                    style: AppTheme.headingMedium,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Order lab tests and diagnostic procedures',
                                    style: AppTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Patient Information
                    const Text(
                      'Patient Information',
                      style: AppTheme.headingMedium,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _patientNameController,
                      decoration: const InputDecoration(
                        labelText: 'Patient Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter patient name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _patientIdController,
                      decoration: const InputDecoration(
                        labelText: 'Patient ID (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _clinicalNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Clinical Notes / Reason for Tests',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medical_information),
                      ),
                      maxLines: 2,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter clinical notes'
                          : null,
                    ),

                    const SizedBox(height: 24),

                    // Select Lab
                    const Text(
                      'Select Laboratory',
                      style: AppTheme.headingMedium,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _selectedLabId,
                      decoration: const InputDecoration(
                        labelText: 'Choose a lab',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.biotech),
                      ),
                      items: _labs.map((lab) {
                        return DropdownMenuItem<String>(
                          value: lab['id'] as String,
                          child: Text(lab['name'] as String),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLabId = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a lab' : null,
                    ),

                    const SizedBox(height: 24),

                    // Urgency Level
                    const Text('Urgency Level', style: AppTheme.headingMedium),
                    const SizedBox(height: 12),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _urgency,
                              decoration: const InputDecoration(
                                labelText: 'Priority Level',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.priority_high),
                              ),
                              items: _urgencyOptions.map((urgency) {
                                return DropdownMenuItem(
                                  value: urgency,
                                  child: Row(
                                    children: [
                                      _getUrgencyIcon(urgency),
                                      const SizedBox(width: 8),
                                      Text(urgency),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _urgency = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _urgencyNotesController,
                              decoration: const InputDecoration(
                                labelText: 'Urgency Notes (Optional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.note),
                                hintText:
                                    'Special instructions regarding urgency',
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Lab Tests Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Laboratory Tests',
                          style: AppTheme.headingMedium,
                        ),
                        ElevatedButton.icon(
                          onPressed: _addLabTestField,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Test'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.infoBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lab test fields
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _labTests.length,
                      itemBuilder: (context, index) {
                        return _buildLabTestField(index);
                      },
                    ),

                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitLabOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.infoBlue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Submit Order'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _getUrgencyIcon(String urgency) {
    switch (urgency) {
      case 'Routine':
        return const Icon(
          Icons.schedule,
          color: AppTheme.successGreen,
          size: 16,
        );
      case 'Urgent':
        return const Icon(
          Icons.warning,
          color: AppTheme.warningOrange,
          size: 16,
        );
      case 'STAT':
        return const Icon(Icons.emergency, color: AppTheme.errorRed, size: 16);
      default:
        return const Icon(
          Icons.schedule,
          color: AppTheme.successGreen,
          size: 16,
        );
    }
  }

  Widget _buildLabTestField(int index) {
    final labTest = _labTests[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Test ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (_labTests.length > 1)
                  IconButton(
                    onPressed: () => _removeLabTestField(index),
                    icon: const Icon(Icons.delete, color: AppTheme.errorRed),
                    tooltip: 'Remove test',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: labTest.category,
              decoration: const InputDecoration(
                labelText: 'Test Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: LabTest.categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  labTest.category = value;
                  labTest.testNameController
                      .clear(); // Clear test name when category changes
                });
              },
              validator: (value) =>
                  value == null ? 'Please select test category' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: labTest.testNameController,
              decoration: const InputDecoration(
                labelText: 'Test Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.science),
                hintText: 'e.g., Complete Blood Count, Glucose',
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter test name'
                  : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: labTest.instructionsController,
              decoration: const InputDecoration(
                labelText: 'Special Instructions (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info),
                hintText: 'Fasting required, specific preparation, etc.',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class LabTest {
  final TextEditingController testNameController = TextEditingController();
  final TextEditingController instructionsController = TextEditingController();
  String? category;

  static const List<String> categories = [
    'Hematology',
    'Chemistry',
    'Microbiology',
    'Immunology',
    'Pathology',
    'Radiology',
    'Cardiology',
    'Endocrinology',
    'Other',
  ];

  Map<String, dynamic> toMap() {
    return {
      'category': category ?? '',
      'testName': testNameController.text.trim(),
      'instructions': instructionsController.text.trim(),
    };
  }

  void dispose() {
    testNameController.dispose();
    instructionsController.dispose();
  }
}
