import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class DoctorAvailabilityScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorAvailabilityScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorAvailabilityScreen> createState() => _DoctorAvailabilityScreenState();
}

class _DoctorAvailabilityScreenState extends State<DoctorAvailabilityScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  
  // Availability data
  Map<String, bool> _workingDays = {
    'Monday': true,
    'Tuesday': true,
    'Wednesday': true,
    'Thursday': true,
    'Friday': true,
    'Saturday': false,
    'Sunday': false,
  };
  
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _lunchStart = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _lunchEnd = const TimeOfDay(hour: 14, minute: 0);
  
  int _appointmentDuration = 30; // minutes
  int _consultationFee = 2500; // LKR
  
  bool _isOnline = true;
  String _clinicAddress = '';
  String _notes = '';

  @override
  void initState() {
    super.initState();
    _loadAvailabilityData();
  }

  Future<void> _loadAvailabilityData() async {
    try {
      final doc = await _firestore
          .collection('doctorAvailability')
          .doc(widget.doctorId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _workingDays = Map<String, bool>.from(data['workingDays'] ?? _workingDays);
          
          // Parse times
          if (data['startTime'] != null) {
            final start = data['startTime'] as String;
            final parts = start.split(':');
            _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          
          if (data['endTime'] != null) {
            final end = data['endTime'] as String;
            final parts = end.split(':');
            _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          
          if (data['lunchStart'] != null) {
            final lunch = data['lunchStart'] as String;
            final parts = lunch.split(':');
            _lunchStart = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          
          if (data['lunchEnd'] != null) {
            final lunchEnd = data['lunchEnd'] as String;
            final parts = lunchEnd.split(':');
            _lunchEnd = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          
          _appointmentDuration = data['appointmentDuration'] ?? 30;
          _consultationFee = data['consultationFee'] ?? 2500;
          _isOnline = data['isOnline'] ?? true;
          _clinicAddress = data['clinicAddress'] ?? '';
          _notes = data['notes'] ?? '';
          
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading availability data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAvailabilityData() async {
    try {
      final data = {
        'doctorId': widget.doctorId,
        'doctorName': widget.doctorName,
        'workingDays': _workingDays,
        'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        'lunchStart': '${_lunchStart.hour.toString().padLeft(2, '0')}:${_lunchStart.minute.toString().padLeft(2, '0')}',
        'lunchEnd': '${_lunchEnd.hour.toString().padLeft(2, '0')}:${_lunchEnd.minute.toString().padLeft(2, '0')}',
        'appointmentDuration': _appointmentDuration,
        'consultationFee': _consultationFee,
        'isOnline': _isOnline,
        'clinicAddress': _clinicAddress,
        'notes': _notes,
        'timeSlots': _generateTimeSlots(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('doctorAvailability')
          .doc(widget.doctorId)
          .set(data);

      // Also update the users collection with availability status
      await _firestore
          .collection('users')
          .doc(widget.doctorId)
          .update({
        'timeSlots': _generateTimeSlots(),
        'consultationFee': _consultationFee,
        'isAvailable': _isOnline,
        'availabilityUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Availability settings saved successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  List<String> _generateTimeSlots() {
    final slots = <String>[];
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final lunchStartMinutes = _lunchStart.hour * 60 + _lunchStart.minute;
    final lunchEndMinutes = _lunchEnd.hour * 60 + _lunchEnd.minute;

    for (int minutes = startMinutes; minutes < endMinutes; minutes += _appointmentDuration) {
      // Skip lunch break
      if (minutes >= lunchStartMinutes && minutes < lunchEndMinutes) {
        continue;
      }
      
      final hour = minutes ~/ 60;
      final minute = minutes % 60;
      final time = TimeOfDay(hour: hour, minute: minute);
      slots.add(_formatTimeSlot(time));
    }

    return slots;
  }

  String _formatTimeSlot(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation Hours'),
        backgroundColor: AppTheme.doctorColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveAvailabilityData,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Working Days Section
                  _buildSection(
                    title: 'Working Days',
                    icon: Icons.calendar_today,
                    child: Column(
                      children: _workingDays.keys.map((day) => 
                        CheckboxListTile(
                          title: Text(day),
                          value: _workingDays[day],
                          onChanged: (value) {
                            setState(() {
                              _workingDays[day] = value ?? false;
                            });
                          },
                          activeColor: AppTheme.doctorColor,
                        ),
                      ).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Working Hours Section
                  _buildSection(
                    title: 'Working Hours',
                    icon: Icons.access_time,
                    child: Column(
                      children: [
                        _buildTimeSelector(
                          'Start Time',
                          _startTime,
                          (time) => setState(() => _startTime = time),
                        ),
                        const SizedBox(height: 12),
                        _buildTimeSelector(
                          'End Time',
                          _endTime,
                          (time) => setState(() => _endTime = time),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Lunch Break Section
                  _buildSection(
                    title: 'Lunch Break',
                    icon: Icons.lunch_dining,
                    child: Column(
                      children: [
                        _buildTimeSelector(
                          'Lunch Start',
                          _lunchStart,
                          (time) => setState(() => _lunchStart = time),
                        ),
                        const SizedBox(height: 12),
                        _buildTimeSelector(
                          'Lunch End',
                          _lunchEnd,
                          (time) => setState(() => _lunchEnd = time),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Appointment Settings
                  _buildSection(
                    title: 'Appointment Settings',
                    icon: Icons.settings,
                    child: Column(
                      children: [
                        _buildDurationSelector(),
                        const SizedBox(height: 16),
                        _buildConsultationFeeSelector(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Availability Status
                  _buildSection(
                    title: 'Availability Status',
                    icon: Icons.online_prediction,
                    child: SwitchListTile(
                      title: const Text('Currently Available'),
                      subtitle: Text(_isOnline ? 'Accepting new appointments' : 'Not accepting appointments'),
                      value: _isOnline,
                      onChanged: (value) => setState(() => _isOnline = value),
                      activeColor: AppTheme.doctorColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Clinic Address
                  _buildSection(
                    title: 'Clinic Information',
                    icon: Icons.location_on,
                    child: Column(
                      children: [
                        TextField(
                          onChanged: (value) => _clinicAddress = value,
                          controller: TextEditingController(text: _clinicAddress),
                          decoration: const InputDecoration(
                            labelText: 'Clinic Address',
                            hintText: 'Enter your clinic address',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (value) => _notes = value,
                          controller: TextEditingController(text: _notes),
                          decoration: const InputDecoration(
                            labelText: 'Additional Notes',
                            hintText: 'Any special instructions for patients',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Preview Generated Time Slots
                  _buildSection(
                    title: 'Generated Time Slots Preview',
                    icon: Icons.preview,
                    child: Container(
                      height: 200,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _generateTimeSlots().length,
                        itemBuilder: (context, index) {
                          final slot = _generateTimeSlots()[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.doctorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.doctorColor.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                slot,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.doctorColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.doctorColor),
                const SizedBox(width: 8),
                Text(title, style: AppTheme.headingMedium),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        time.format(context),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onTap: () async {
        final newTime = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (newTime != null) {
          onChanged(newTime);
        }
      },
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Appointment Duration'),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _appointmentDuration,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: [15, 20, 30, 45, 60].map((duration) => 
            DropdownMenuItem(
              value: duration,
              child: Text('$duration minutes'),
            ),
          ).toList(),
          onChanged: (value) => setState(() => _appointmentDuration = value ?? 30),
        ),
      ],
    );
  }

  Widget _buildConsultationFeeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Consultation Fee (LKR)'),
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: _consultationFee.toString()),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixText: 'LKR ',
          ),
          onChanged: (value) {
            final fee = int.tryParse(value);
            if (fee != null) {
              _consultationFee = fee;
            }
          },
        ),
      ],
    );
  }
}
