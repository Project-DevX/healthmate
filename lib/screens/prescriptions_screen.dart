import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class PrescriptionsScreen extends StatefulWidget {
  final String doctorId;

  const PrescriptionsScreen({super.key, required this.doctorId});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _patientNameController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();

  List<PrescriptionMedication> _medications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addMedicationField();
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientIdController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    for (var medication in _medications) {
      medication.dispose();
    }
    super.dispose();
  }

  void _addMedicationField() {
    setState(() {
      _medications.add(PrescriptionMedication());
    });
  }

  void _removeMedicationField(int index) {
    if (_medications.length > 1) {
      setState(() {
        _medications[index].dispose();
        _medications.removeAt(index);
      });
    }
  }

  Future<void> _savePrescription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prescriptionData = {
        'doctorId': widget.doctorId,
        'patientName': _patientNameController.text.trim(),
        'patientId': _patientIdController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'notes': _notesController.text.trim(),
        'medications': _medications.map((med) => med.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'prescriptionDate': DateTime.now(),
        'status': 'active',
      };

      await _firestore.collection('prescriptions').add(prescriptionData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription saved successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving prescription: $e'),
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
    _diagnosisController.clear();
    _notesController.clear();

    setState(() {
      for (var medication in _medications) {
        medication.dispose();
      }
      _medications.clear();
      _addMedicationField();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppWidgets.buildAppBar(
        title: 'Write Prescription',
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
                                color: AppTheme.doctorColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.edit_note,
                                color: AppTheme.doctorColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New Prescription',
                                    style: AppTheme.headingMedium,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Fill in patient details and medication information',
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
                      controller: _diagnosisController,
                      decoration: const InputDecoration(
                        labelText: 'Diagnosis',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medical_information),
                      ),
                      maxLines: 2,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter diagnosis'
                          : null,
                    ),

                    const SizedBox(height: 24),

                    // Medications Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Medications',
                          style: AppTheme.headingMedium,
                        ),
                        ElevatedButton.icon(
                          onPressed: _addMedicationField,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Medicine'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.doctorColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Medication fields
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _medications.length,
                      itemBuilder: (context, index) {
                        return _buildMedicationField(index);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Additional Notes
                    const Text(
                      'Additional Notes',
                      style: AppTheme.headingMedium,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Special instructions, warnings, etc.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
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
                            onPressed: _savePrescription,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.doctorColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save Prescription'),
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

  Widget _buildMedicationField(int index) {
    final medication = _medications[index];

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
                  'Medicine ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (_medications.length > 1)
                  IconButton(
                    onPressed: () => _removeMedicationField(index),
                    icon: const Icon(Icons.delete, color: AppTheme.errorRed),
                    tooltip: 'Remove medicine',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: medication.nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter medicine name'
                  : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: medication.dosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.straighten),
                      hintText: 'e.g., 500mg',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter dosage'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: medication.frequencyController,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                      hintText: 'e.g., 2x daily',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter frequency'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: medication.durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      hintText: 'e.g., 7 days',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter duration'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: medication.timing,
                    decoration: const InputDecoration(
                      labelText: 'Timing',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.restaurant),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Before Food',
                        child: Text('Before Food'),
                      ),
                      DropdownMenuItem(
                        value: 'After Food',
                        child: Text('After Food'),
                      ),
                      DropdownMenuItem(
                        value: 'With Food',
                        child: Text('With Food'),
                      ),
                      DropdownMenuItem(
                        value: 'Empty Stomach',
                        child: Text('Empty Stomach'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        medication.timing = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select timing' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: medication.instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info),
                hintText: 'Special instructions for this medicine',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class PrescriptionMedication {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController dosageController = TextEditingController();
  final TextEditingController frequencyController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController instructionsController = TextEditingController();
  String? timing;

  Map<String, dynamic> toMap() {
    return {
      'name': nameController.text.trim(),
      'dosage': dosageController.text.trim(),
      'frequency': frequencyController.text.trim(),
      'duration': durationController.text.trim(),
      'timing': timing ?? '',
      'instructions': instructionsController.text.trim(),
    };
  }

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    instructionsController.dispose();
  }
}
