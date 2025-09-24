import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'utils/user_data_utils.dart';
import 'widgets/notification_widget.dart';
import 'screens/doctor_appointments_screen.dart';
import 'screens/doctor_patient_management_screen.dart';
import 'screens/prescriptions_screen.dart';
import 'screens/lab_reports_screen.dart';
import 'screens/doctor_availability_screen.dart';
import 'screens/doctor_profile_edit_screen.dart';

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

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
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
          NotificationBadge(
            userId: userData!['uid'],
            onTap: _showNotificationsDialog,
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

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: userData != null
                    ? NotificationWidget(
                        userId: userData!['uid'],
                        userType: 'doctor',
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
