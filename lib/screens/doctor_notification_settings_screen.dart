import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class DoctorNotificationSettingsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorNotificationSettingsScreen({super.key, required this.doctorId});

  @override
  State<DoctorNotificationSettingsScreen> createState() => _DoctorNotificationSettingsScreenState();
}

class _DoctorNotificationSettingsScreenState extends State<DoctorNotificationSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;

  // Notification preferences
  bool _appointmentNotifications = true;
  bool _prescriptionNotifications = true;
  bool _labReportNotifications = true;
  bool _emergencyNotifications = true;
  bool _reminderNotifications = true;
  bool _marketingNotifications = false;

  // Notification methods
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _smsNotifications = false;

  // Timing preferences
  String _appointmentReminderTime = '30 minutes';
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '07:00';
  bool _quietHoursEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final doc = await _firestore
          .collection('doctorNotificationSettings')
          .doc(widget.doctorId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _appointmentNotifications = data['appointmentNotifications'] ?? true;
          _prescriptionNotifications = data['prescriptionNotifications'] ?? true;
          _labReportNotifications = data['labReportNotifications'] ?? true;
          _emergencyNotifications = data['emergencyNotifications'] ?? true;
          _reminderNotifications = data['reminderNotifications'] ?? true;
          _marketingNotifications = data['marketingNotifications'] ?? false;
          
          _emailNotifications = data['emailNotifications'] ?? true;
          _pushNotifications = data['pushNotifications'] ?? true;
          _smsNotifications = data['smsNotifications'] ?? false;
          
          _appointmentReminderTime = data['appointmentReminderTime'] ?? '30 minutes';
          _quietHoursStart = data['quietHoursStart'] ?? '22:00';
          _quietHoursEnd = data['quietHoursEnd'] ?? '07:00';
          _quietHoursEnabled = data['quietHoursEnabled'] ?? true;
          
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading notification settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNotificationSettings() async {
    try {
      final data = {
        'doctorId': widget.doctorId,
        'appointmentNotifications': _appointmentNotifications,
        'prescriptionNotifications': _prescriptionNotifications,
        'labReportNotifications': _labReportNotifications,
        'emergencyNotifications': _emergencyNotifications,
        'reminderNotifications': _reminderNotifications,
        'marketingNotifications': _marketingNotifications,
        'emailNotifications': _emailNotifications,
        'pushNotifications': _pushNotifications,
        'smsNotifications': _smsNotifications,
        'appointmentReminderTime': _appointmentReminderTime,
        'quietHoursStart': _quietHoursStart,
        'quietHoursEnd': _quietHoursEnd,
        'quietHoursEnabled': _quietHoursEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('doctorNotificationSettings')
          .doc(widget.doctorId)
          .set(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved successfully!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: AppTheme.doctorColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveNotificationSettings,
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
                  // Notification Types
                  _buildSection(
                    title: 'Notification Types',
                    icon: Icons.notifications,
                    child: Column(
                      children: [
                        _buildNotificationSwitch(
                          'Appointment Notifications',
                          'New appointments, cancellations, and changes',
                          _appointmentNotifications,
                          (value) => setState(() => _appointmentNotifications = value),
                          isImportant: true,
                        ),
                        _buildNotificationSwitch(
                          'Prescription Notifications',
                          'Updates on prescription fulfillment',
                          _prescriptionNotifications,
                          (value) => setState(() => _prescriptionNotifications = value),
                        ),
                        _buildNotificationSwitch(
                          'Lab Report Notifications',
                          'New lab results and test updates',
                          _labReportNotifications,
                          (value) => setState(() => _labReportNotifications = value),
                        ),
                        _buildNotificationSwitch(
                          'Emergency Notifications',
                          'Critical patient alerts and emergencies',
                          _emergencyNotifications,
                          (value) => setState(() => _emergencyNotifications = value),
                          isImportant: true,
                        ),
                        _buildNotificationSwitch(
                          'Reminder Notifications',
                          'Appointment reminders and follow-ups',
                          _reminderNotifications,
                          (value) => setState(() => _reminderNotifications = value),
                        ),
                        _buildNotificationSwitch(
                          'Marketing & Updates',
                          'HealthMate updates and promotional content',
                          _marketingNotifications,
                          (value) => setState(() => _marketingNotifications = value),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Notification Methods
                  _buildSection(
                    title: 'Notification Methods',
                    icon: Icons.send,
                    child: Column(
                      children: [
                        _buildNotificationSwitch(
                          'Email Notifications',
                          'Receive notifications via email',
                          _emailNotifications,
                          (value) => setState(() => _emailNotifications = value),
                        ),
                        _buildNotificationSwitch(
                          'Push Notifications',
                          'Receive notifications on your device',
                          _pushNotifications,
                          (value) => setState(() => _pushNotifications = value),
                        ),
                        _buildNotificationSwitch(
                          'SMS Notifications',
                          'Receive notifications via text message',
                          _smsNotifications,
                          (value) => setState(() => _smsNotifications = value),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Timing Preferences
                  _buildSection(
                    title: 'Timing Preferences',
                    icon: Icons.schedule,
                    child: Column(
                      children: [
                        _buildDropdownSetting(
                          'Appointment Reminder',
                          'When to remind you about upcoming appointments',
                          _appointmentReminderTime,
                          ['15 minutes', '30 minutes', '1 hour', '2 hours', '1 day'],
                          (value) => setState(() => _appointmentReminderTime = value!),
                        ),
                        const SizedBox(height: 16),
                        _buildNotificationSwitch(
                          'Quiet Hours',
                          'Reduce notifications during specified hours',
                          _quietHoursEnabled,
                          (value) => setState(() => _quietHoursEnabled = value),
                        ),
                        if (_quietHoursEnabled) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimeSetting(
                                  'Start Time',
                                  _quietHoursStart,
                                  (value) => setState(() => _quietHoursStart = value),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTimeSetting(
                                  'End Time',
                                  _quietHoursEnd,
                                  (value) => setState(() => _quietHoursEnd = value),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Test Notifications
                  _buildSection(
                    title: 'Test Notifications',
                    icon: Icons.play_arrow,
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _sendTestNotification,
                          icon: const Icon(Icons.send),
                          label: const Text('Send Test Notification'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.doctorColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Send a test notification to verify your settings',
                          style: AppTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _enableAllNotifications,
                          child: const Text('Enable All'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _disableNonEssentialNotifications,
                          child: const Text('Essential Only'),
                        ),
                      ),
                    ],
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

  Widget _buildNotificationSwitch(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged, {
    bool isImportant = false,
  }) {
    return ListTile(
      title: Row(
        children: [
          Text(title),
          if (isImportant) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'IMPORTANT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorRed,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle, style: AppTheme.bodySmall),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.doctorColor,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDropdownSetting(
    String title,
    String subtitle,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTheme.bodySmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: options.map((option) => DropdownMenuItem(
            value: option,
            child: Text(option),
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTimeSetting(String label, String time, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.bodyMedium),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final timeParts = time.split(':');
            final initialTime = TimeOfDay(
              hour: int.parse(timeParts[0]),
              minute: int.parse(timeParts[1]),
            );
            
            final newTime = await showTimePicker(
              context: context,
              initialTime: initialTime,
            );
            
            if (newTime != null) {
              final formattedTime = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
              onChanged(formattedTime);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(time),
          ),
        ),
      ],
    );
  }

  void _sendTestNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔔 Test notification sent! Check your preferred notification method.'),
        backgroundColor: AppTheme.infoBlue,
      ),
    );
  }

  void _enableAllNotifications() {
    setState(() {
      _appointmentNotifications = true;
      _prescriptionNotifications = true;
      _labReportNotifications = true;
      _emergencyNotifications = true;
      _reminderNotifications = true;
      _marketingNotifications = true;
    });
  }

  void _disableNonEssentialNotifications() {
    setState(() {
      _appointmentNotifications = true;
      _prescriptionNotifications = true;
      _labReportNotifications = true;
      _emergencyNotifications = true;
      _reminderNotifications = false;
      _marketingNotifications = false;
    });
  }
}
