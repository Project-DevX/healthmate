import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _dataSharing = false;
  bool _locationTracking = false;
  bool _analyticsTracking = true;
  bool _marketingEmails = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
        backgroundColor: AppTheme.primaryBlue,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Data Privacy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Data Sharing
          SwitchListTile(
            title: const Text('Data Sharing with Healthcare Providers'),
            subtitle: const Text(
              'Allow sharing of medical data with authorized healthcare providers',
            ),
            value: _dataSharing,
            onChanged: (value) {
              setState(() => _dataSharing = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const Divider(),

          // Location Tracking
          SwitchListTile(
            title: const Text('Location Tracking'),
            subtitle: const Text(
              'Allow location tracking for emergency services',
            ),
            value: _locationTracking,
            onChanged: (value) {
              setState(() => _locationTracking = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const Divider(),

          // Analytics Tracking
          SwitchListTile(
            title: const Text('Analytics & Usage Tracking'),
            subtitle: const Text(
              'Help improve the app by sharing anonymous usage data',
            ),
            value: _analyticsTracking,
            onChanged: (value) {
              setState(() => _analyticsTracking = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const Divider(),

          // Marketing Emails
          SwitchListTile(
            title: const Text('Marketing Communications'),
            subtitle: const Text(
              'Receive emails about new features and health tips',
            ),
            value: _marketingEmails,
            onChanged: (value) {
              setState(() => _marketingEmails = value);
            },
            activeColor: AppTheme.primaryBlue,
          ),

          const SizedBox(height: 32),

          // Data Management Section
          const Text(
            'Data Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ListTile(
            title: const Text('Download My Data'),
            subtitle: const Text(
              'Get a copy of all your personal and medical data',
            ),
            trailing: const Icon(Icons.download),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data download feature coming soon'),
                ),
              );
            },
          ),

          ListTile(
            title: const Text('Delete My Account'),
            subtitle: const Text(
              'Permanently delete your account and all associated data',
            ),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () {
              _showDeleteAccountDialog();
            },
          ),

          const SizedBox(height: 32),

          // Privacy Policy
          ListTile(
            title: const Text('Privacy Policy'),
            subtitle: const Text(
              'Read our privacy policy and terms of service',
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy policy will open in browser'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion feature coming soon'),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
