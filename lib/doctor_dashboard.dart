import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';
import 'utils/user_data_utils.dart';
import 'screens/prescriptions_screen.dart';
import 'screens/lab_reports_screen.dart';
import 'screens/doctor_appointments_screen.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? userData;
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      print(
        '🔍 Doctor Dashboard - Current user: ${user?.uid}, Email: ${user?.email}',
      );

      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        print('🔍 Doctor Dashboard - User document exists: ${userDoc.exists}');

        if (userDoc.exists) {
          final docData = userDoc.data();
          print('🔍 Doctor Dashboard - Document data: $docData');

          setState(() {
            userData = docData;
            userData!['uid'] = user.uid;
            _isLoading = false;
          });

          print('🔍 Doctor Dashboard - User data loaded: $userData');
          print('🔍 Doctor Dashboard - User type: ${userData?['userType']}');
          print(
            '🔍 Doctor Dashboard - Display name: ${UserDataUtils.getDisplayName(userData)}',
          );
        } else {
          print(
            '❌ Doctor Dashboard - User document does not exist in Firestore',
          );
          setState(() => _isLoading = false);
        }
      } else {
        print('❌ Doctor Dashboard - No authenticated user found');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Doctor Dashboard - Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Widget> get _pages => [
    DoctorDashboardContent(userData: userData),
    DoctorAppointmentsScreen(doctorId: userData?['uid'] ?? ''),
    PrescriptionsScreen(doctorId: userData?['uid'] ?? ''),
    const Center(child: Text('Patient Management - Coming Soon')),
    DoctorProfileContent(
      displayName: _getDisplayName(),
      email: _getEmail(),
      specialization: _getSpecialization(),
      licenseNumber: _getLicenseNumber(),
      phoneNumber: _getPhoneNumber(),
      gender: _getGender(),
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showEmergencyOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Emergency Protocols'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppWidgets.buildEmergencyOption(
                context: context,
                icon: Icons.local_hospital,
                label: 'Call Emergency Services',
                color: AppTheme.errorRed,
                onTap: () {
                  Navigator.pop(context);
                  // Add emergency call functionality
                },
              ),
              AppWidgets.buildEmergencyOption(
                context: context,
                icon: Icons.medical_services,
                label: 'Emergency Consultation',
                color: AppTheme.warningOrange,
                onTap: () {
                  Navigator.pop(context);
                  // Add emergency consultation functionality
                },
              ),
              AppWidgets.buildEmergencyOption(
                context: context,
                icon: Icons.phone,
                label: 'Contact On-Call Doctor',
                color: AppTheme.infoBlue,
                onTap: () {
                  Navigator.pop(context);
                  // Add on-call doctor contact functionality
                },
              ),
              AppWidgets.buildEmergencyOption(
                context: context,
                icon: Icons.location_on,
                label: 'Hospital Emergency Dept',
                color: AppTheme.successGreen,
                onTap: () {
                  Navigator.pop(context);
                  // Add emergency department functionality
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
      }
    }
  }

  String _getDisplayName() {
    return UserDataUtils.getDisplayName(userData);
  }

  String _getEmail() {
    return userData?['email'] ?? _auth.currentUser?.email ?? 'No email';
  }

  String _getSpecialization() {
    return userData?['specialization'] ?? 'General Medicine';
  }

  String _getLicenseNumber() {
    return userData?['licenseNumber'] ?? 'Not provided';
  }

  String _getPhoneNumber() {
    return UserDataUtils.getPhoneNumber(userData);
  }

  String _getGender() {
    return userData?['gender'] ?? 'Not specified';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppWidgets.buildAppBar(
        title: 'HealthMate - Doctor',
        userType: 'doctor',
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency),
            onPressed: _showEmergencyOptions,
            tooltip: 'Emergency Protocols',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
          ? const Center(child: Text('No user data available'))
          : _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.doctorColor,
        unselectedItemColor: AppTheme.textMedium,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Prescriptions',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Patients'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class DoctorDashboardContent extends StatelessWidget {
  final Map<String, dynamic>? userData;

  const DoctorDashboardContent({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();
    final doctorName = UserDataUtils.getDisplayName(userData);

    print('🎯 Doctor Dashboard Content - userName: $doctorName');
    print('🎯 Doctor Dashboard Content - userData: $userData');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor greeting card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.doctorColor.withOpacity(0.2),
                        child: Icon(
                          Icons.medical_services,
                          color: AppTheme.doctorColor,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting, Dr. $doctorName!',
                              style: AppTheme.headingLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userData?['specialization'] ?? 'General Medicine',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.doctorColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Ready to care for your patients today?',
                              style: AppTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Today's Overview
          _buildTodaysOverview(context),

          const SizedBox(height: 16),

          // Quick Actions
          _buildQuickActions(context, userData?['uid']),

          const SizedBox(height: 24),

          // Recent Activity & Stats
          const Text('Recent Activity', style: AppTheme.headingMedium),
          const SizedBox(height: 12),

          _buildRecentActivity(context),

          const SizedBox(height: 24),

          // Practice Statistics
          const Text('Practice Overview', style: AppTheme.headingMedium),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: AppWidgets.buildHealthStatCard(
                  title: 'Today\'s Patients',
                  value: '12',
                  icon: Icons.people,
                  color: AppTheme.doctorColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppWidgets.buildHealthStatCard(
                  title: 'Pending Reports',
                  value: '5',
                  icon: Icons.pending_actions,
                  color: AppTheme.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppWidgets.buildHealthStatCard(
                  title: 'Prescriptions',
                  value: '28',
                  icon: Icons.medication,
                  color: AppTheme.accentPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppWidgets.buildHealthStatCard(
                  title: 'Lab Orders',
                  value: '15',
                  icon: Icons.science,
                  color: AppTheme.infoBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysOverview(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.infoBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.today,
                    color: AppTheme.infoBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Today\'s Schedule',
                    style: AppTheme.headingMedium,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildScheduleItem(
                    'Next Appointment',
                    '10:30 AM',
                    'John Doe - Consultation',
                    AppTheme.successGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildScheduleItem(
                    'Total Today',
                    '12 Patients',
                    '8:00 AM - 6:00 PM',
                    AppTheme.doctorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(
    String title,
    String value,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, String? doctorId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: AppTheme.headingMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppWidgets.buildQuickAccessButton(
                context: context,
                icon: Icons.edit_note,
                label: 'Write Prescription',
                color: AppTheme.doctorColor,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PrescriptionsScreen(doctorId: doctorId ?? ''),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppWidgets.buildQuickAccessButton(
                context: context,
                icon: Icons.science,
                label: 'Order Lab Tests',
                color: AppTheme.infoBlue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          LabReportsScreen(doctorId: doctorId ?? ''),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppWidgets.buildQuickAccessButton(
                context: context,
                icon: Icons.calendar_month,
                label: 'View Appointments',
                color: AppTheme.accentPurple,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DoctorAppointmentsScreen(doctorId: doctorId ?? ''),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppWidgets.buildQuickAccessButton(
                context: context,
                icon: Icons.people,
                label: 'Patient Records',
                color: AppTheme.warningOrange,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Patient records feature coming soon'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          _buildActivityItem(
            'New patient consultation completed',
            'Sarah Wilson - General checkup',
            '2 hours ago',
            Icons.check_circle,
            AppTheme.successGreen,
          ),
          const Divider(height: 1),
          _buildActivityItem(
            'Lab results received',
            'Michael Brown - Blood test results',
            '4 hours ago',
            Icons.science,
            AppTheme.infoBlue,
          ),
          const Divider(height: 1),
          _buildActivityItem(
            'Prescription issued',
            'Emma Davis - Hypertension medication',
            '1 day ago',
            Icons.medication,
            AppTheme.accentPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        radius: 20,
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle, style: AppTheme.bodySmall),
      trailing: Text(time, style: AppTheme.captionSmall),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }
}

class DoctorProfileContent extends StatelessWidget {
  final String displayName;
  final String email;
  final String specialization;
  final String licenseNumber;
  final String phoneNumber;
  final String gender;

  const DoctorProfileContent({
    super.key,
    required this.displayName,
    required this.email,
    required this.specialization,
    required this.licenseNumber,
    required this.phoneNumber,
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.doctorColor.withOpacity(0.2),
                  child: Icon(
                    Icons.medical_services,
                    size: 50,
                    color: AppTheme.doctorColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Dr. $displayName', style: AppTheme.headingLarge),
                Text(email, style: AppTheme.bodySmall),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.doctorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Doctor',
                    style: TextStyle(
                      color: AppTheme.doctorColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Professional Information
          const Text('Professional Information', style: AppTheme.headingMedium),
          const SizedBox(height: 16),

          AppWidgets.buildInfoCard(
            title: 'Specialization',
            value: specialization,
            icon: Icons.medical_services,
            color: AppTheme.doctorColor,
          ),
          AppWidgets.buildInfoCard(
            title: 'License Number',
            value: licenseNumber,
            icon: Icons.badge,
            color: AppTheme.doctorColor,
          ),
          AppWidgets.buildInfoCard(
            title: 'Phone Number',
            value: phoneNumber,
            icon: Icons.phone,
            color: AppTheme.doctorColor,
          ),
          AppWidgets.buildInfoCard(
            title: 'Gender',
            value: gender,
            icon: Icons.person,
            color: AppTheme.doctorColor,
          ),

          const SizedBox(height: 24),

          // Settings Section
          const Text('Settings', style: AppTheme.headingMedium),
          const SizedBox(height: 16),

          _buildSettingsOption(context, 'Edit Profile', Icons.edit, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edit profile feature coming soon')),
            );
          }),
          _buildSettingsOption(
            context,
            'Consultation Hours',
            Icons.schedule,
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Consultation hours feature coming soon'),
                ),
              );
            },
          ),
          _buildSettingsOption(
            context,
            'Notification Settings',
            Icons.notifications,
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification settings feature coming soon'),
                ),
              );
            },
          ),
          _buildSettingsOption(
            context,
            'Privacy & Security',
            Icons.security,
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy settings feature coming soon'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOption(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.doctorColor),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
