import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'profile_page.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({Key? key}) : super(key: key);

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  bool isDarkMode = false;
  int _selectedBottomNav = 0;
  bool _isLoading = true;
  int _selectedFeature = -1;

  Map<String, dynamic>? caregiverData;
  List<Map<String, dynamic>> patients = [];

  // Add controllers for vitals input
  final TextEditingController _bpSystolicController = TextEditingController();
  final TextEditingController _bpDiastolicController = TextEditingController();
  final TextEditingController _glucoseController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _heartRateController = TextEditingController();

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
      // Fetch caregiver info
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (docSnap.exists) {
        caregiverData = docSnap.data();
      }
      // Fetch patients assigned to caregiver
      final patSnap = await FirebaseFirestore.instance
          .collection('patients')
          .where('caregiverId', isEqualTo: uid)
          .get();
      patients = patSnap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
    setState(() => _isLoading = false);
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedBottomNav = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color mainBlue = const Color(0xFF2196F3);
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
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: const Text('Dashboard'),
          actions: [
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
            ? _buildCaregiverDashboard(
                mainBlue,
                textColor,
                subTextColor,
                cardBg,
              )
            : _selectedBottomNav == 1
            ? const ChatPage()
            : const ProfilePage(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedBottomNav,
          onTap: _onNavTap,
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

  Widget _buildCaregiverDashboard(
    Color mainBlue,
    Color textColor,
    Color subTextColor,
    Color cardBg,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Greeting and avatar
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(
                caregiverData?['photoURL'] ??
                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(caregiverData?['fullName'] ?? 'Caregiver')}&background=7B61FF&color=fff',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${caregiverData?['fullName'] ?? 'Caregiver'} 👋',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Here is your caregiving overview.',
                    style: TextStyle(fontSize: 15, color: subTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Patient Details Card (replaces Patients stat card)
        _buildPatientDetailsCard(mainBlue, subTextColor, cardBg),
        const SizedBox(height: 24),
        // Upcoming Appointments Card (placeholder)
        _buildUpcomingAppointmentsCard(mainBlue),
        const SizedBox(height: 24),
        // Horizontal feature icons (quick access to all main features)
        _buildFeatureIcons(mainBlue, textColor),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPatientDetailsCard(Color mainBlue, Color subTextColor, Color cardBg) {
    if (patients.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Icon(Icons.person_off, color: Colors.grey, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'No patient assigned to you yet.',
                  style: TextStyle(fontSize: 16, color: subTextColor),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final patient = patients[0];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(
                patient['photoURL'] ??
                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(patient['name'] ?? 'Patient')}&background=7B61FF&color=fff',
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient['name'] ?? 'Patient',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Age: ${patient['age'] ?? '--'}',
                    style: TextStyle(fontSize: 14, color: subTextColor),
                  ),
                  if (patient['condition'] != null && patient['condition'].toString().isNotEmpty)
                    Text(
                      patient['condition'],
                      style: TextStyle(fontSize: 14, color: subTextColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointmentsCard(Color mainBlue) {
    // Placeholder for upcoming appointments
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
                  onPressed: () {},
                  child: Text('View All', style: TextStyle(color: mainBlue)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // TODO: Replace with real data
            const Text(
              'No upcoming appointments',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureIcons(Color mainBlue, Color textColor) {
    final features = [
      {
        'label': 'Vitals',
        'icon': Icons.monitor_heart,
        'builder': _buildVitalsEntry,
      },
      {
        'label': 'Appointments',
        'icon': Icons.calendar_today,
        'builder': _buildAppointmentManager,
      },
      {
        'label': 'Records',
        'icon': Icons.folder_shared,
        'builder': _buildMedicalRecordsViewer,
      },
      {
        'label': 'Upload',
        'icon': Icons.upload_file,
        'builder': _buildUploadReports,
      },
      {
        'label': 'Medication',
        'icon': Icons.medication,
        'builder': _buildMedicationTracker,
      },
      {
        'label': 'Tips',
        'icon': Icons.lightbulb,
        'builder': _buildHealthTipsSection,
      },
    ];
    return Column(
      children: [
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: features.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final feature = features[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFeature = index;
                  });
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(feature['label'] as String),
                      content: SizedBox(
                        width: 350,
                        child:
                            (feature['builder']
                                as Widget Function(Color, Color))!(
                              mainBlue,
                              Theme.of(context).cardColor,
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
                },
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: mainBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Icon(
                        feature['icon'] as IconData,
                        color: mainBlue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feature['label'] as String,
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
      ],
    );
  }

  Widget _buildVitalsEntry(Color mainBlue, Color cardBg) {
    // Vitals entry UI with attractive input boxes, line by line
    const inputFillColor = Color(0xFFE3F0FB);
    const borderRadius = BorderRadius.all(Radius.circular(14));
    const inputPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 18);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter Patient Vitals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 18),
            TextField(
              controller: _bpSystolicController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'BP Systolic',
                prefixIcon: Icon(Icons.favorite, color: mainBlue),
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide.none),
                contentPadding: inputPadding,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bpDiastolicController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'BP Diastolic',
                prefixIcon: Icon(Icons.favorite, color: mainBlue),
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide.none),
                contentPadding: inputPadding,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _glucoseController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Glucose',
                prefixIcon: Icon(Icons.bloodtype, color: mainBlue),
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide.none),
                contentPadding: inputPadding,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _temperatureController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Temperature',
                prefixIcon: Icon(Icons.thermostat, color: mainBlue),
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide.none),
                contentPadding: inputPadding,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _heartRateController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Heart Rate',
                prefixIcon: Icon(Icons.monitor_heart, color: mainBlue),
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide.none),
                contentPadding: inputPadding,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: mainBlue,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                elevation: 1,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                // No backend logic yet
              },
              icon: Icon(Icons.save, color: mainBlue),
              label: const Text('Save Vitals'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentManager(Color mainBlue, Color cardBg) {
    // Placeholder for appointment manager UI
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Appointments',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // TODO: Implement appointment list and actions
            Text(
              'Upcoming appointments list and actions (request, cancel, reschedule)',
              style: TextStyle(color: mainBlue),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: mainBlue,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                elevation: 1,
              ),
              onPressed: () {},
              icon: Icon(Icons.add, color: mainBlue),
              label: const Text('Request Appointment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalRecordsViewer(Color mainBlue, Color cardBg) {
    // Placeholder for medical records viewer UI
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patient Medical Records',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // TODO: Implement read-only medical records viewer
            Text(
              'Read-only access to medical records, lab reports, prescriptions, and doctor notes.',
              style: TextStyle(color: mainBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadReports(Color mainBlue, Color cardBg) {
    // Placeholder for upload reports UI
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Reports',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // TODO: Implement upload functionality
            Text(
              'Upload test reports, medication charts, or handwritten notes.',
              style: TextStyle(color: mainBlue),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: mainBlue,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                elevation: 1,
              ),
              onPressed: () {},
              icon: Icon(Icons.upload_file, color: mainBlue),
              label: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationTracker(Color mainBlue, Color cardBg) {
    // Placeholder for medication tracker UI
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medication Tracker',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // TODO: Implement medication tracker
            Text(
              'View prescribed medicines, dosage, and mark as Taken/Skipped.',
              style: TextStyle(color: mainBlue),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: mainBlue,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    elevation: 1,
                  ),
                  onPressed: () {},
                  icon: Icon(Icons.check, color: mainBlue),
                  label: const Text('Taken'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: mainBlue,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    elevation: 1,
                  ),
                  onPressed: () {},
                  icon: Icon(Icons.close, color: mainBlue),
                  label: const Text('Skipped'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTipsSection(Color mainBlue, Color cardBg) {
    // Placeholder for health tips feed
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Health Tips',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // TODO: Implement health tips feed
            Text(
              'Simple health reminders and educational content.',
              style: TextStyle(color: mainBlue),
            ),
          ],
        ),
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
          .where('caregiverId', isEqualTo: uid)
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
                              n['timestamp'] is int
                                  ? DateTime.fromMillisecondsSinceEpoch(n['timestamp'])
                                      .toLocal()
                                      .toString()
                                      .substring(0, 16)
                                  : n['timestamp'].toDate().toLocal().toString().substring(0, 16),
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
        content: SizedBox(
          width: 300,
          child: Column(
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
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
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
}
 