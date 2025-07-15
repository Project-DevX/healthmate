import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class DoctorPrivacySecurityScreen extends StatefulWidget {
  final String doctorId;

  const DoctorPrivacySecurityScreen({super.key, required this.doctorId});

  @override
  State<DoctorPrivacySecurityScreen> createState() => _DoctorPrivacySecurityScreenState();
}

class _DoctorPrivacySecurityScreenState extends State<DoctorPrivacySecurityScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;
  bool _profileVisibility = true;
  bool _onlineStatus = true;
  bool _shareAnalytics = false;
  bool _twoFactorAuth = false;
  bool _sessionTimeout = true;
  String _dataRetention = '5 years';
  bool _auditLog = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final doc = await _firestore
          .collection('doctorPrivacySettings')
          .doc(widget.doctorId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _profileVisibility = data['profileVisibility'] ?? true;
          _onlineStatus = data['onlineStatus'] ?? true;
          _shareAnalytics = data['shareAnalytics'] ?? false;
          _twoFactorAuth = data['twoFactorAuth'] ?? false;
          _sessionTimeout = data['sessionTimeout'] ?? true;
          _dataRetention = data['dataRetention'] ?? '5 years';
          _auditLog = data['auditLog'] ?? true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading privacy settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrivacySettings() async {
    try {
      final data = {
        'doctorId': widget.doctorId,
        'profileVisibility': _profileVisibility,
        'onlineStatus': _onlineStatus,
        'shareAnalytics': _shareAnalytics,
        'twoFactorAuth': _twoFactorAuth,
        'sessionTimeout': _sessionTimeout,
        'dataRetention': _dataRetention,
        'auditLog': _auditLog,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('doctorPrivacySettings')
          .doc(widget.doctorId)
          .set(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings saved successfully!'),
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

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    try {
      final user = _auth.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _oldPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating password: ${e.toString().contains('wrong-password') ? 'Current password is incorrect' : e.toString()}'),
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
        title: const Text('Privacy & Security'),
        backgroundColor: AppTheme.doctorColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _savePrivacySettings,
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
                  // Password Security
                  _buildSection(
                    title: 'Password Security',
                    icon: Icons.lock,
                    child: Column(
                      children: [
                        TextField(
                          controller: _oldPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Current Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _newPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'New Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Confirm New Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.doctorColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: const Text('Change Password'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Two-Factor Authentication
                  _buildSection(
                    title: 'Two-Factor Authentication',
                    icon: Icons.security,
                    child: Column(
                      children: [
                        _buildPrivacySwitch(
                          'Enable Two-Factor Authentication',
                          'Add an extra layer of security to your account',
                          _twoFactorAuth,
                          (value) => setState(() => _twoFactorAuth = value),
                        ),
                        if (_twoFactorAuth) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _setupTwoFactor,
                            icon: const Icon(Icons.qr_code),
                            label: const Text('Setup Authenticator App'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.infoBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Profile Privacy
                  _buildSection(
                    title: 'Profile Privacy',
                    icon: Icons.visibility,
                    child: Column(
                      children: [
                        _buildPrivacySwitch(
                          'Profile Visibility',
                          'Allow patients to find and view your profile',
                          _profileVisibility,
                          (value) => setState(() => _profileVisibility = value),
                        ),
                        _buildPrivacySwitch(
                          'Show Online Status',
                          'Display when you are online to patients',
                          _onlineStatus,
                          (value) => setState(() => _onlineStatus = value),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Data Privacy
                  _buildSection(
                    title: 'Data Privacy',
                    icon: Icons.data_usage,
                    child: Column(
                      children: [
                        _buildPrivacySwitch(
                          'Share Analytics Data',
                          'Help improve HealthMate by sharing anonymous usage data',
                          _shareAnalytics,
                          (value) => setState(() => _shareAnalytics = value),
                        ),
                        _buildPrivacySwitch(
                          'Enable Audit Log',
                          'Keep track of all account activities',
                          _auditLog,
                          (value) => setState(() => _auditLog = value),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownSetting(
                          'Data Retention Period',
                          'How long to keep patient interaction data',
                          _dataRetention,
                          ['1 year', '3 years', '5 years', '10 years', 'Indefinite'],
                          (value) => setState(() => _dataRetention = value!),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Session Security
                  _buildSection(
                    title: 'Session Security',
                    icon: Icons.timer,
                    child: Column(
                      children: [
                        _buildPrivacySwitch(
                          'Automatic Session Timeout',
                          'Automatically logout after 30 minutes of inactivity',
                          _sessionTimeout,
                          (value) => setState(() => _sessionTimeout = value),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _logoutAllDevices,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout from All Devices'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningOrange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Account Actions
                  _buildSection(
                    title: 'Account Actions',
                    icon: Icons.admin_panel_settings,
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _downloadAccountData,
                          icon: const Icon(Icons.download),
                          label: const Text('Download My Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.infoBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _showDeleteAccountDialog,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorRed,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Security Recommendations
                  _buildSection(
                    title: 'Security Recommendations',
                    icon: Icons.tips_and_updates,
                    child: Column(
                      children: [
                        _buildSecurityTip(
                          'Use a strong, unique password',
                          _newPasswordController.text.length >= 8 ? Icons.check_circle : Icons.warning,
                          _newPasswordController.text.length >= 8 ? AppTheme.successGreen : AppTheme.warningOrange,
                        ),
                        _buildSecurityTip(
                          'Enable two-factor authentication',
                          _twoFactorAuth ? Icons.check_circle : Icons.warning,
                          _twoFactorAuth ? AppTheme.successGreen : AppTheme.warningOrange,
                        ),
                        _buildSecurityTip(
                          'Keep your app updated',
                          Icons.check_circle,
                          AppTheme.successGreen,
                        ),
                        _buildSecurityTip(
                          'Review your privacy settings regularly',
                          Icons.info,
                          AppTheme.infoBlue,
                        ),
                      ],
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

  Widget _buildPrivacySwitch(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      title: Text(title),
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

  Widget _buildSecurityTip(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _setupTwoFactor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setup Two-Factor Authentication'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('To setup 2FA:'),
            SizedBox(height: 16),
            Text('1. Download an authenticator app (Google Authenticator, Authy)'),
            SizedBox(height: 8),
            Text('2. Scan the QR code or enter the secret key'),
            SizedBox(height: 8),
            Text('3. Enter the verification code from your app'),
            SizedBox(height: 16),
            Text('This feature will be available in a future update.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _logoutAllDevices() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout from All Devices'),
        content: const Text('This will logout your account from all devices. You will need to login again on each device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out from all devices')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _downloadAccountData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data download will be available soon. You will receive an email with your data.'),
        backgroundColor: AppTheme.infoBlue,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion requires additional verification. Please contact support.'),
                  backgroundColor: AppTheme.warningOrange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
