import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../login.dart';
import 'appointments_page.dart';
import 'patient_search_page.dart';
import 'medical_records_page.dart';
import 'eprescription_page.dart';
import 'lab_reports_page.dart';
import 'vitals_page.dart';
import 'chat_page.dart';
import 'analytics_page.dart';
import 'availability_page.dart';
import 'profile_page.dart';
import 'rating_page.dart';
import 'friends_screen.dart';
import 'doctor_appointments_screen.dart';
import '../theme/app_theme.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({Key? key}) : super(key: key);

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  bool isDarkMode = false;
  int _selectedBottomNav = 0;

  Map<String, dynamic>? doctorData;
  List<Map<String, dynamic>> appointments = [];
  List<Map<String, dynamic>> patients = [];
  bool _isLoading = true;

  // Add this map to control module visibility in settings
  Map<String, bool> moduleVisibility = {};

  final List<_DashboardFeature> _features = [
    _DashboardFeature('Appointments', Icons.calendar_today),
    _DashboardFeature('Patient Search', Icons.search),
    _DashboardFeature('Medical Records', Icons.folder_shared),
    _DashboardFeature('E-Prescription', Icons.receipt_long),
    _DashboardFeature('Lab Reports', Icons.science),
    _DashboardFeature('Vitals', Icons.monitor_heart),
    _DashboardFeature('Chat', Icons.chat),
    _DashboardFeature('Analytics', Icons.show_chart),
    _DashboardFeature('Availability', Icons.schedule),
    _DashboardFeature('Profile', Icons.person),
    _DashboardFeature('Rating', Icons.star),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final uid = user.uid;
    try {
      // Fetch doctor info
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (docSnap.exists) {
        doctorData = docSnap.data();
      }

      // Fetch appointments (assuming appointments collection with doctorId field)
      try {
        final apptSnap = await FirebaseFirestore.instance
            .collection('appointments')
            .where('doctorId', isEqualTo: uid)
            .orderBy('date', descending: false)
            .limit(5)
            .get();
        appointments = apptSnap.docs.map((d) => d.data()).toList();
      } catch (e) {
        print('Error fetching appointments: $e');
        // Add sample appointments data
        appointments = [
          {
            'patientName': 'John Doe',
            'date': '2025-07-02',
            'time': '10:00 AM',
            'status': 'Scheduled',
            'patientAvatar': null,
          },
          {
            'patientName': 'Jane Smith',
            'date': '2025-07-02',
            'time': '2:00 PM',
            'status': 'Confirmed',
            'patientAvatar': null,
          },
          {
            'patientName': 'Mike Johnson',
            'date': '2025-07-03',
            'time': '9:00 AM',
            'status': 'Pending',
            'patientAvatar': null,
          },
        ];
      }

      // Fetch patients (assuming patients collection with doctorId field)
      try {
        final patSnap = await FirebaseFirestore.instance
            .collection('patients')
            .where('doctorId', isEqualTo: uid)
            .limit(10)
            .get();
        patients = patSnap.docs.map((d) => d.data()).toList();
      } catch (e) {
        print('Error fetching patients: $e');
        // Add sample patients data
        patients = [
          {'name': 'Alice Brown', 'photoURL': null},
          {'name': 'Bob Wilson', 'photoURL': null},
          {'name': 'Carol Davis', 'photoURL': null},
          {'name': 'David Miller', 'photoURL': null},
        ];
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
    setState(() => _isLoading = false);
  }

  void _onFeatureTap(String feature) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Widget? page;
    switch (feature) {
      case 'Appointments':
        page = DoctorAppointmentsScreen(doctorId: user.uid);
        break;
      case 'Patient Search':
        page = const PatientSearchPage();
        break;
      case 'Medical Records':
        page = const MedicalRecordsPage();
        break;
      case 'E-Prescription':
        page = const EPrescriptionPage();
        break;
      case 'Lab Reports':
        page = const LabReportsPage();
        break;
      case 'Vitals':
        page = const VitalsPage();
        break;
      case 'Chat':
        page = const ChatPage();
        break;
      case 'Analytics':
        page = const AnalyticsPage();
        break;
      case 'Availability':
        page = const AvailabilityPage();
        break;
      case 'Profile':
        page = const ProfilePage();
        break;
      case 'Rating':
        page = const RatingPage();
        break;
    }
    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color mainBlue = AppTheme.doctorColor;
    final Color successGreen = const Color(0xFF4CAF50);
    final Color cardBg = isDarkMode
        ? const Color(0xFF232A34)
        : const Color(0xFFF5F9FF);
    final Color scaffoldBg = isDarkMode
        ? const Color(0xFF181C22)
        : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : mainBlue;
    final Color subTextColor = isDarkMode
        ? Colors.grey[300]!
        : Colors.grey[700]!;
    return MaterialApp(
      theme: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: mainBlue,
        scaffoldBackgroundColor: scaffoldBg,
        cardColor: cardBg,
        appBarTheme: AppBarTheme(
          backgroundColor: isDarkMode ? const Color(0xFF232A34) : Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: mainBlue),
          titleTextStyle: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        colorScheme: isDarkMode
            ? ColorScheme.dark(
                primary: mainBlue,
                secondary: successGreen,
                background: scaffoldBg,
                surface: cardBg,
              )
            : ColorScheme.light(
                primary: mainBlue,
                secondary: successGreen,
                background: Colors.white,
                surface: cardBg,
              ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: successGreen,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: successGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF6F6FA),
        appBar: AppBar(
          title: const Text('Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendsScreen()),
                );
              },
              tooltip: 'Friends',
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () => _showNotificationsDialog(),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsDialog(),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedBottomNav == 0
            ? Container(
                color: scaffoldBg,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Greeting and avatar
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(
                            doctorData?['photoURL'] ??
                                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(doctorData?['fullName'] ?? 'Doctor')}&background=7B61FF&color=fff',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${doctorData?['fullName'] ?? 'Doctor'} 👋',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'How are you today?',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Statistics Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Patients',
                            '${patients.length}',
                            Icons.people,
                            AppTheme.doctorColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Appointments',
                            '${appointments.length}',
                            Icons.calendar_today,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Completed',
                            '${appointments.where((apt) => apt['status'] == 'Completed').length}',
                            Icons.check_circle,
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Pending',
                            '${appointments.where((apt) => apt['status'] == 'Pending').length}',
                            Icons.pending,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Upcoming Appointments Card
                    _buildUpcomingAppointmentsCard(mainBlue),
                    const SizedBox(height: 24),
                    // Horizontal feature icons
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _features
                            .where(
                              (f) => f.label != 'Chat' && f.label != 'Profile',
                            )
                            .length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final visibleFeatures = _features
                              .where(
                                (f) =>
                                    f.label != 'Chat' && f.label != 'Profile',
                              )
                              .toList();
                          final feature = visibleFeatures[index];
                          return GestureDetector(
                            onTap: () => _onFeatureTap(feature.label),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: mainBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Icon(
                                    feature.icon,
                                    color: mainBlue,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  feature.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    // My Patients Section
                    Text(
                      'My Patients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: patients.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final patient = patients[index];
                          return Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(
                                  patient['photoURL'] ??
                                      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(patient['name'] ?? 'Patient')}&background=7B61FF&color=fff',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                patient['name'] ?? 'Patient',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            : _selectedBottomNav == 1
            ? const ChatPage()
            : const ProfilePage(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedBottomNav,
          onTap: (index) {
            setState(() {
              _selectedBottomNav = index;
            });
            // You can add navigation logic here if needed
          },
          selectedItemColor: mainBlue,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointmentsCard(Color mainBlue) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Appointments',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorAppointmentsScreen(doctorId: user.uid),
                        ),
                      );
                    }
                  },
                  child: Text('View All', style: TextStyle(color: mainBlue)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            appointments.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No upcoming appointments',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: appointments
                        .take(3)
                        .length, // Show up to 3 appointments
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final appt = appointments[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(
                                appt['patientAvatar'] ??
                                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(appt['patientName'] ?? 'Patient')}&background=7B61FF&color=fff',
                              ),
                              radius: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appt['patientName'] ?? 'Patient',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${appt['date'] ?? ''} at ${appt['time'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  appt['status'] ?? '',
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getStatusColor(appt['status'] ?? ''),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                appt['status'] ?? 'Pending',
                                style: TextStyle(
                                  color: _getStatusColor(appt['status'] ?? ''),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return AppTheme.doctorColor;
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.clearLoginState();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    List<Map<String, dynamic>> notifications = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('doctorId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      notifications = snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Error fetching notifications: $e');
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: 320,
          child: notifications.isEmpty
              ? const Text('No new notifications.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  separatorBuilder: (context, i) => const Divider(),
                  itemBuilder: (context, i) {
                    final n = notifications[i];
                    return ListTile(
                      leading: const Icon(
                        Icons.notifications,
                        color: Colors.amber,
                      ),
                      title: Text(n['title'] ?? 'Notification'),
                      subtitle: Text(n['body'] ?? ''),
                      trailing: n['timestamp'] != null
                          ? Text(
                              DateTime.fromMillisecondsSinceEpoch(
                                n['timestamp'] is int
                                    ? n['timestamp']
                                    : n['timestamp'].millisecondsSinceEpoch,
                              ).toLocal().toString().substring(0, 16),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            )
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              value: isDarkMode,
              onChanged: (val) {
                setState(() {
                  isDarkMode = val;
                });
                Navigator.pop(context);
              },
              title: const Text('Dark Mode'),
            ),
            ...moduleVisibility.keys.map((module) {
              return CheckboxListTile(
                title: Text(module),
                value: moduleVisibility[module],
                onChanged: (val) {
                  setState(() {
                    moduleVisibility[module] = val ?? true;
                  });
                },
              );
            }).toList(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardFeature {
  final String label;
  final IconData icon;
  const _DashboardFeature(this.label, this.icon);
}
