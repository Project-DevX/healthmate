import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _appointmentReminders = true;
  bool _medicationReminders = true;
  bool _labResults = true;
  bool _healthTips = false;
  bool _emergencyAlerts = true;
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _smsNotifications = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: AppTheme.primaryBlue,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Health Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Appointment Reminders
          SwitchListTile(
            title: const Text('Appointment Reminders'),
            subtitle: const Text('Get notified about upcoming appointments'),
            value: _appointmentReminders,
            onChanged: (value) {
              setState(() => _appointmentReminders = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const Divider(),

          // Medication Reminders
          SwitchListTile(
            title: const Text('Medication Reminders'),
            subtitle: const Text('Daily reminders for medication schedules'),
            value: _medicationReminders,
            onChanged: (value) {
              setState(() => _medicationReminders = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const Divider(),

          // Lab Results
          SwitchListTile(
            title: const Text('Lab Results Available'),
            subtitle: const Text(
              'Notifications when new lab results are ready',
            ),
            value: _labResults,
            onChanged: (value) {
              setState(() => _labResults = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const Divider(),

          // Health Tips
          SwitchListTile(
            title: const Text('Health Tips & Articles'),
            subtitle: const Text('Weekly health tips and educational content'),
            value: _healthTips,
            onChanged: (value) {
              setState(() => _healthTips = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const Divider(),

          // Emergency Alerts
          SwitchListTile(
            title: const Text('Emergency Alerts'),
            subtitle: const Text(
              'Critical health alerts and emergency notifications',
            ),
            value: _emergencyAlerts,
            onChanged: (value) {
              setState(() => _emergencyAlerts = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const SizedBox(height: 32),

          const Text(
            'Notification Methods',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Push Notifications
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive notifications in the app'),
            value: _pushNotifications,
            onChanged: (value) {
              setState(() => _pushNotifications = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const Divider(),

          // Email Notifications
          SwitchListTile(
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive notifications via email'),
            value: _emailNotifications,
            onChanged: (value) {
              setState(() => _emailNotifications = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const Divider(),

          // SMS Notifications
          SwitchListTile(
            title: const Text('SMS Notifications'),
            subtitle: const Text('Receive notifications via text message'),
            value: _smsNotifications,
            onChanged: (value) {
              setState(() => _smsNotifications = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const SizedBox(height: 32),

          // Notification Schedule
          const Text(
            'Notification Schedule',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ListTile(
            title: const Text('Quiet Hours'),
            subtitle: const Text('Set times when notifications are silenced'),
            trailing: const Icon(Icons.schedule),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Quiet hours settings coming soon'),
                ),
              );
            },
          ),

          ListTile(
            title: const Text('Reminder Frequency'),
            subtitle: const Text('How often to send medication reminders'),
            trailing: const Icon(Icons.repeat),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reminder frequency settings coming soon'),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Test Notifications
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent!')),
                );
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Send Test Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
