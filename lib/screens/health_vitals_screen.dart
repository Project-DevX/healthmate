import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class HealthVitalsScreen extends StatefulWidget {
  const HealthVitalsScreen({super.key});

  @override
  State<HealthVitalsScreen> createState() => _HealthVitalsScreenState();
}

class _HealthVitalsScreenState extends State<HealthVitalsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for form fields
  final _heartRateController = TextEditingController();
  final _bloodPressureSystolicController = TextEditingController();
  final _bloodPressureDiastolicController = TextEditingController();
  final _weightController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _currentVitals;

  @override
  void initState() {
    super.initState();
    _loadCurrentVitals();
  }

  @override
  void dispose() {
    _heartRateController.dispose();
    _bloodPressureSystolicController.dispose();
    _bloodPressureDiastolicController.dispose();
    _weightController.dispose();
    _temperatureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentVitals() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final vitalsDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('health_vitals')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (vitalsDoc.docs.isNotEmpty) {
        final vitals = vitalsDoc.docs.first.data();
        setState(() {
          _currentVitals = vitals;
          _populateFormFields(vitals);
        });
      }
    } catch (e) {
      print('Error loading vitals: $e');
    }
  }

  void _populateFormFields(Map<String, dynamic> vitals) {
    _heartRateController.text = vitals['heartRate']?.toString() ?? '';
    _bloodPressureSystolicController.text =
        vitals['bloodPressureSystolic']?.toString() ?? '';
    _bloodPressureDiastolicController.text =
        vitals['bloodPressureDiastolic']?.toString() ?? '';
    _weightController.text = vitals['weight']?.toString() ?? '';
    _temperatureController.text = vitals['temperature']?.toString() ?? '';
    _notesController.text = vitals['notes'] ?? '';

    if (vitals['date'] != null) {
      _selectedDate = (vitals['date'] as Timestamp).toDate();
    }
  }

  Future<void> _saveVitals() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final vitalsData = {
        'heartRate': int.tryParse(_heartRateController.text.trim()),
        'bloodPressureSystolic': int.tryParse(
          _bloodPressureSystolicController.text.trim(),
        ),
        'bloodPressureDiastolic': int.tryParse(
          _bloodPressureDiastolicController.text.trim(),
        ),
        'weight': double.tryParse(_weightController.text.trim()),
        'temperature': double.tryParse(_temperatureController.text.trim()),
        'notes': _notesController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Remove null values
      vitalsData.removeWhere((key, value) => value == null);

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('health_vitals')
          .add(vitalsData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health vitals saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vitals: $e'),
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Vitals'),
        backgroundColor: AppTheme.primaryBlue,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveVitals,
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
              // Date Selection
              const Text(
                'Date & Time',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Measurement Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Vital Signs Section
              const Text(
                'Vital Signs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Heart Rate
              TextFormField(
                controller: _heartRateController,
                decoration: const InputDecoration(
                  labelText: 'Heart Rate (BPM)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.favorite),
                  suffixText: 'BPM',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final rate = int.tryParse(value);
                    if (rate == null || rate < 40 || rate > 200) {
                      return 'Please enter a valid heart rate (40-200 BPM)';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Blood Pressure
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bloodPressureSystolicController,
                      decoration: const InputDecoration(
                        labelText: 'Systolic',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bloodtype),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final systolic = int.tryParse(value);
                          if (systolic == null ||
                              systolic < 80 ||
                              systolic > 250) {
                            return 'Invalid systolic pressure';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _bloodPressureDiastolicController,
                      decoration: const InputDecoration(
                        labelText: 'Diastolic',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final diastolic = int.tryParse(value);
                          if (diastolic == null ||
                              diastolic < 50 ||
                              diastolic > 150) {
                            return 'Invalid diastolic pressure';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Weight
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_weight),
                  suffixText: 'kg',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final weight = double.tryParse(value);
                    if (weight == null || weight < 20 || weight > 300) {
                      return 'Please enter a valid weight (20-300 kg)';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Temperature
              TextFormField(
                controller: _temperatureController,
                decoration: const InputDecoration(
                  labelText: 'Temperature',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.thermostat),
                  suffixText: '°F',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final temp = double.tryParse(value);
                    if (temp == null || temp < 90 || temp > 110) {
                      return 'Please enter a valid temperature (90-110°F)';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Notes Section
              const Text(
                'Additional Notes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 200,
              ),

              const SizedBox(height: 32),

              // Current Vitals Display
              if (_currentVitals != null) ...[
                const Text(
                  'Last Recorded Vitals',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentVitals!['heartRate'] != null)
                          Text(
                            'Heart Rate: ${_currentVitals!['heartRate']} BPM',
                          ),
                        if (_currentVitals!['bloodPressureSystolic'] != null &&
                            _currentVitals!['bloodPressureDiastolic'] != null)
                          Text(
                            'Blood Pressure: ${_currentVitals!['bloodPressureSystolic']}/${_currentVitals!['bloodPressureDiastolic']}',
                          ),
                        if (_currentVitals!['weight'] != null)
                          Text('Weight: ${_currentVitals!['weight']} kg'),
                        if (_currentVitals!['temperature'] != null)
                          Text(
                            'Temperature: ${_currentVitals!['temperature']}°F',
                          ),
                        if (_currentVitals!['date'] != null)
                          Text(
                            'Date: ${(_currentVitals!['date'] as Timestamp).toDate().toString().split(' ')[0]}',
                          ),
                      ].expand((widget) => [widget, const SizedBox(height: 4)]).toList()..removeLast(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
