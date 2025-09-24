import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'utils/user_data_utils.dart';
import 'screens/doctor_appointments_screen.dart';
import 'screens/doctor_patient_management_screen.dart';
import 'screens/prescriptions_screen.dart';
import 'screens/lab_reports_screen.dart';
import 'screens/doctor_availability_screen.dart';
import 'screens/doctor_profile_edit_screen.dart';
import 'widgets/patient_medical_history_widget.dart';
import 'screens/doctor_notification_settings_screen.dart';
import 'screens/doctor_privacy_security_screen.dart';

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

  // Statistics data
  int totalAppointments = 0;
  int todayAppointments = 0;
  int pendingLabReports = 0;
  int totalPatients = 0;

  // Today's appointments
  List<Map<String, dynamic>> todaysAppointmentsList = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Widget _buildOldUI(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.doctorColor),
        ),
      );
    }

    if (userData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Failed to load user data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _signOut,
                child: const Text('Return to Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Main screen widgets
    final List<Widget> screens = [
      _buildHomeScreen(),
      DoctorAppointmentsScreen(doctorId: userData!['uid']),
      DoctorPatientManagementScreen(
        doctorId: userData!['uid'],
        doctorName: UserDataUtils.getDisplayName(userData),
      ),
      PrescriptionsScreen(doctorId: userData!['uid']),
      LabReportsScreen(doctorId: userData!['uid']),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.doctorColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & Support coming soon!')),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: AppTheme.doctorColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_outlined),
            activeIcon: Icon(Icons.receipt),
            label: 'Prescriptions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science_outlined),
            activeIcon: Icon(Icons.science),
            label: 'Lab Reports',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Doctor Dashboard';
      case 1:
        return 'Appointments';
      case 2:
        return 'Patient Management';
      case 3:
        return 'Prescriptions';
      case 4:
        return 'Lab Reports';
      default:
        return 'Doctor Dashboard';
    }
  }

  Widget _buildDrawer() {
    final name = UserDataUtils.getDisplayName(userData);
    final email = UserDataUtils.getEmail(userData);
    final specialty =
        userData?['specialty'] as String? ?? 'General Practitioner';
    final profileImage = userData?['profileImageUrl'];

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: AppTheme.doctorColor),
            accountName: Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  specialty,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: profileImage != null
                  ? NetworkImage(profileImage)
                  : null,
              child: profileImage == null
                  ? Text(
                      UserDataUtils.getInitials(userData),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.doctorColor,
                      ),
                    )
                  : null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('Dashboard'),
                  selected: _selectedIndex == 0,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Appointments'),
                  selected: _selectedIndex == 1,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Patient Management'),
                  selected: _selectedIndex == 2,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_outlined),
                  title: const Text('Prescriptions'),
                  selected: _selectedIndex == 3,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 3);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Lab Reports'),
                  selected: _selectedIndex == 4,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 4);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Availability Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorAvailabilityScreen(
                          doctorId: userData!['uid'],
                          doctorName: UserDataUtils.getDisplayName(userData),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outlined),
                  title: const Text('Edit Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DoctorProfileEditScreen(userData: userData!),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings coming soon!')),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppTheme.errorRed),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: AppTheme.errorRed),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    _showLogoutDialog();
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HealthMate v1.0.0',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserData();
      },
      color: AppTheme.doctorColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildTodayAppointmentsSection(),
          const SizedBox(height: 24),
          _buildQuickActionsSection(),
          const SizedBox(height: 24),
          _buildRecentActivitiesSection(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final name = UserDataUtils.getDisplayName(userData);
    final greeting = _getGreeting();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.doctorColor.withOpacity(0.2),
              backgroundImage: userData?['profileImageUrl'] != null
                  ? NetworkImage(userData!['profileImageUrl'])
                  : null,
              child: userData?['profileImageUrl'] == null
                  ? Text(
                      UserDataUtils.getInitials(userData),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.doctorColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Dr. $name',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Total Appointments',
          totalAppointments.toString(),
          Icons.calendar_month,
          Colors.blue,
        ),
        _buildStatCard(
          'Today\'s Appointments',
          todayAppointments.toString(),
          Icons.today,
          Colors.orange,
        ),
        _buildStatCard(
          'Pending Lab Reports',
          pendingLabReports.toString(),
          Icons.science,
          Colors.purple,
        ),
        _buildStatCard(
          'Total Patients',
          totalPatients.toString(),
          Icons.people,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayAppointmentsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Appointments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedIndex = 1);
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(color: AppTheme.doctorColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            todaysAppointmentsList.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No appointments scheduled for today'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: todaysAppointmentsList.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final appointment = todaysAppointmentsList[index];
                      return _buildAppointmentListItem(appointment);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentListItem(Map<String, dynamic> appointment) {
    final statusColors = {
      'scheduled': Colors.blue,
      'confirmed': Colors.green,
      'completed': Colors.purple,
      'cancelled': Colors.red,
      'no_show': Colors.orange,
    };

    final color = statusColors[appointment['status']] ?? Colors.grey;
    final time = appointment['timeSlot'];
    final timestamp = appointment['appointmentDate'] as Timestamp;
    final date = timestamp.toDate();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(Icons.person, color: color),
      ),
      title: Text(
        appointment['patientName'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${DateFormat.jm().format(date)} - $time'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          appointment['status'].toString().toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ),
      onTap: () {
        // Navigate to appointment details
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment details for ${appointment['patientName']}',
            ),
            action: SnackBarAction(
              label: 'VIEW',
              onPressed: () {
                setState(() => _selectedIndex = 1);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionItem(
                  icon: Icons.search,
                  label: 'Search\nPatient',
                  color: Colors.blue,
                  onTap: () {
                    setState(() => _selectedIndex = 2);
                  },
                ),
                _buildQuickActionItem(
                  icon: Icons.receipt,
                  label: 'New\nPrescription',
                  color: Colors.green,
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                  },
                ),
                _buildQuickActionItem(
                  icon: Icons.science,
                  label: 'Lab\nRequest',
                  color: Colors.purple,
                  onTap: () {
                    setState(() => _selectedIndex = 4);
                  },
                ),
                _buildQuickActionItem(
                  icon: Icons.schedule,
                  label: 'Set\nAvailability',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorAvailabilityScreen(
                          doctorId: userData!['uid'],
                          doctorName: UserDataUtils.getDisplayName(userData),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesSection() {
    // Placeholder for recent activities
    // In a real app, this would fetch data from Firestore
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildActivityItem(
              icon: Icons.receipt_long,
              title: 'Prescription Created',
              description: 'For Patient: John Smith',
              time: '10 minutes ago',
              color: Colors.green,
            ),
            const Divider(),
            _buildActivityItem(
              icon: Icons.check_circle_outline,
              title: 'Appointment Completed',
              description: 'With Patient: Emily Johnson',
              time: '2 hours ago',
              color: Colors.blue,
            ),
            const Divider(),
            _buildActivityItem(
              icon: Icons.science,
              title: 'Lab Results Received',
              description: 'For Patient: Michael Brown',
              time: 'Yesterday',
              color: Colors.purple,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Activity history coming soon!'),
                    ),
                  );
                },
                child: Text(
                  'View All Activities',
                  style: TextStyle(color: AppTheme.doctorColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String description,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
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

          if (mounted) {
            setState(() {
              userData = docData;
              userData!['uid'] = user.uid;
              _isLoading = false;
            });
          }

          // Load statistics data after user data is loaded
          _loadStatistics(user.uid);
          _loadTodaysAppointments(user.uid);
        } else {
          print(
            '❌ Doctor Dashboard - User document does not exist in Firestore',
          );
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } else {
        print('❌ Doctor Dashboard - No authenticated user found');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('❌ Doctor Dashboard - Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadStatistics(String doctorId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Get total appointments count
      final appointmentsQuery = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      // Get today's appointments count
      final todayAppointmentsQuery = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where(
            'appointmentDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(today),
          )
          .where('appointmentDate', isLessThan: Timestamp.fromDate(tomorrow))
          .get();

      // Get pending lab reports count
      final pendingLabsQuery = await _firestore
          .collection('labReports')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', whereIn: ['requested', 'in_progress'])
          .get();

      // Get unique patients count
      final uniquePatientsQuery = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      final Set<String> uniquePatientIds = {};
      for (var doc in uniquePatientsQuery.docs) {
        uniquePatientIds.add(doc['patientId']);
      }

      if (mounted) {
        setState(() {
          totalAppointments = appointmentsQuery.docs.length;
          todayAppointments = todayAppointmentsQuery.docs.length;
          pendingLabReports = pendingLabsQuery.docs.length;
          totalPatients = uniquePatientIds.length;
        });
      }
    } catch (e) {
      print('❌ Error loading statistics: $e');
    }
  }

  Future<void> _loadTodaysAppointments(String doctorId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final todayAppointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where(
            'appointmentDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(today),
          )
          .where('appointmentDate', isLessThan: Timestamp.fromDate(tomorrow))
          .orderBy('appointmentDate')
          .limit(5)
          .get();

      final appointments = todayAppointmentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'patientName': data['patientName'] ?? 'Unknown',
          'appointmentDate': data['appointmentDate'] as Timestamp,
          'timeSlot': data['timeSlot'] ?? '',
          'status': data['status'] ?? 'scheduled',
          'reason': data['reason'] ?? 'Check-up',
        };
      }).toList();

      if (mounted) {
        setState(() {
          todaysAppointmentsList = appointments;
        });
      }
    } catch (e) {
      print('❌ Error loading today\'s appointments: $e');
    }
  }

  void _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      print('❌ Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sign out. Please try again.'),
          ),
        );
      }
    }
  }

  List<Widget> get _pages => [
    DoctorDashboardContent(userData: userData),
    DoctorAppointmentsScreen(doctorId: userData?['uid'] ?? ''),
    PrescriptionsScreen(doctorId: userData?['uid'] ?? ''),
    DoctorPatientManagementScreen(
      doctorId: userData?['uid'] ?? '',
      doctorName: _getDisplayName(),
    ),
    DoctorProfileContent(
      displayName: _getDisplayName(),
      email: _getEmail(),
      specialization: _getSpecialization(),
      licenseNumber: _getLicenseNumber(),
      phoneNumber: _getPhoneNumber(),
      gender: _getGender(),
      userData: userData,
    ),
  ];

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
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
  void dispose() {
    // Cancel any pending async operations to prevent setState after dispose
    super.dispose();
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
    final doctorId = userData?['uid'];
    if (doctorId == null) {
      return const SizedBox();
    }
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
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
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('doctorId', isEqualTo: doctorId)
                  .where(
                    'appointmentDate',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
                  )
                  .where(
                    'appointmentDate',
                    isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
                  )
                  .orderBy('appointmentDate')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('No appointments for today.');
                }
                final appointments = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final data =
                        appointments[index].data() as Map<String, dynamic>;
                    final patientName = data['patientName'] ?? 'Unknown';
                    final time = (data['appointmentDate'] as Timestamp)
                        .toDate();
                    final status = data['status'] ?? 'scheduled';
                    return ListTile(
                      leading: const Icon(Icons.access_time),
                      title: Text(
                        '$patientName - ${data['reason'] ?? 'Consultation'}',
                      ),
                      subtitle: Text(DateFormat('hh:mm a').format(time)),
                      trailing: Chip(
                        label: Text(status.toUpperCase()),
                        backgroundColor: AppTheme.infoBlue.withOpacity(0.1),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, String? doctorId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: AppTheme.headingMedium),
        const SizedBox(height: 12),
        // Quick Actions Grid
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildQuickActionCard(
              'View Patient Records',
              Icons.folder_shared,
              AppTheme.primaryBlue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PatientMedicalHistoryWidget(
                      doctorId: userData?['uid'] ?? '',
                      doctorName: UserDataUtils.getDisplayName(userData),
                    ),
                  ),
                );
              },
            ),
            _buildQuickActionCard(
              'Appointments',
              Icons.calendar_today,
              AppTheme.successGreen,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DoctorAppointmentsScreen(
                      doctorId: userData?['uid'] ?? '',
                    ),
                  ),
                );
              },
            ),
            _buildQuickActionCard(
              'Prescriptions',
              Icons.medication,
              AppTheme.accentOrange,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PrescriptionsScreen(doctorId: userData?['uid'] ?? ''),
                  ),
                );
              },
            ),
            _buildQuickActionCard(
              'Lab Reports',
              Icons.science,
              AppTheme.accentPurple,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LabReportsScreen(doctorId: userData?['uid'] ?? ''),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
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
  final Map<String, dynamic>? userData;

  const DoctorProfileContent({
    super.key,
    required this.displayName,
    required this.email,
    required this.specialization,
    required this.licenseNumber,
    required this.phoneNumber,
    required this.gender,
    required this.userData,
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

          _buildSettingsOption(context, 'Edit Profile', Icons.edit, () async {
            if (userData != null) {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DoctorProfileEditScreen(userData: userData!),
                ),
              );
              if (result == true) {
                // Refresh profile data if edit was successful
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Profile updated! Please refresh the app to see changes.',
                    ),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            }
          }),
          _buildSettingsOption(
            context,
            'Consultation Hours',
            Icons.schedule,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorAvailabilityScreen(
                    doctorId: userData?['uid'] ?? '',
                    doctorName: displayName,
                  ),
                ),
              );
            },
          ),
          _buildSettingsOption(
            context,
            'Notification Settings',
            Icons.notifications,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorNotificationSettingsScreen(
                    doctorId: userData?['uid'] ?? '',
                  ),
                ),
              );
            },
          ),
          _buildSettingsOption(
            context,
            'Privacy & Security',
            Icons.security,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorPrivacySecurityScreen(
                    doctorId: userData?['uid'] ?? '',
                  ),
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
