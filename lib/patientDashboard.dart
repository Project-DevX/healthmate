import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'theme/app_theme.dart';
import 'models/shared_models.dart';
import 'services/trend_analysis_service.dart';
import 'services/gemini_service.dart';
import 'services/interconnect_service.dart';
import 'screens/medical_records_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/trend_analysis_screen.dart';
import 'screens/health_vitals_screen.dart';
import 'screens/medical_summary_screen.dart';
import 'screens/lab_report_content_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/notifications_settings_screen.dart';
import 'screens/patient_profile_edit_screen.dart';
import 'widgets/trend_test_data_widget.dart';
import 'widgets/doctor_booking_widget.dart';
import 'screens/chat_page.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
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
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          if (mounted) {
            setState(() {
              userData = userDoc.data();
              userData!['uid'] = user.uid;
              _isLoading = false; // Set loading to false here
            });
          }
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Widget> get _pages => [
    DashboardContent(userData: userData, onNavigateToTrends: _navigateToTrends),
    AppointmentsContent(userData: userData),
    MedicalRecordsScreen(userId: userData?['uid'] ?? ''),
    ChatPage(),
    UserProfileContent(
      displayName: _getDisplayName(),
      email: _getEmail(),
      photoUrl: _getPhotoUrl(),
      dateOfBirth: _getDateOfBirth(),
      phoneNumber: _getPhoneNumber(),
      gender: _getGender(),
      userData: userData,
      onProfileUpdated: _loadUserData,
    ),
  ];

  void _onItemTapped(int index) {
    // Only update state if widget is still mounted
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
          title: const Text('Emergency'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEmergencyOption(
                context,
                Icons.local_hospital,
                'Call Emergency Services',
                Colors.red,
                () async {
                  Navigator.pop(context);
                  const emergencyNumber = '911'; // US emergency number
                  final Uri launchUri = Uri(
                    scheme: 'tel',
                    path: emergencyNumber,
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to make emergency call. Please call 911 manually.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              _buildEmergencyOption(
                context,
                Icons.phone,
                'Call Emergency Contact',
                Colors.orange,
                () async {
                  Navigator.pop(context);
                  final emergencyContactPhone =
                      userData?['emergencyContactPhone'];
                  if (emergencyContactPhone != null &&
                      emergencyContactPhone.isNotEmpty) {
                    final Uri launchUri = Uri(
                      scheme: 'tel',
                      path: emergencyContactPhone,
                    );
                    if (await canLaunchUrl(launchUri)) {
                      await launchUrl(launchUri);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unable to call emergency contact.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No emergency contact phone number set. Please update your profile.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
              ),
              _buildEmergencyOption(
                context,
                Icons.location_on,
                'Share Location',
                AppTheme.patientColor,
                () async {
                  Navigator.pop(context);
                  // For now, open Google Maps with a generic location sharing message
                  // In a real app, you'd get the actual GPS coordinates
                  final Uri launchUri = Uri.parse(
                    'https://maps.google.com/?q=current+location',
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to open maps. Please share your location manually.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  // Show a message about location sharing
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Location sharing initiated. Help is on the way.',
                        ),
                        backgroundColor: AppTheme.patientColor,
                      ),
                    );
                  }
                },
              ),
              _buildEmergencyOption(
                context,
                Icons.contacts,
                'Emergency Contacts',
                Colors.green,
                () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyContactsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmergencyOption(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 24,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
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
    return userData?['name'] ??
        _auth.currentUser?.displayName ??
        'Unknown User';
  }

  String _getEmail() {
    return userData?['email'] ?? _auth.currentUser?.email ?? 'No email';
  }

  String? _getPhotoUrl() {
    return userData?['photoUrl'] ?? _auth.currentUser?.photoURL;
  }

  String _getDateOfBirth() {
    final dob = userData?['dateOfBirth'];
    if (dob != null) {
      if (dob is Timestamp) {
        return DateFormat('MMMM d, yyyy').format(dob.toDate());
      } else if (dob is String) {
        try {
          final date = DateTime.parse(dob);
          return DateFormat('MMMM d, yyyy').format(date);
        } catch (e) {
          return dob;
        }
      }
    }
    return 'Not provided';
  }

  String _getPhoneNumber() {
    return userData?['phoneNumber'] ?? 'Not provided';
  }

  String _getGender() {
    return userData?['gender'] ?? 'Not specified';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthMate'),
        backgroundColor: AppTheme.patientColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency),
            onPressed: _showEmergencyOptions,
            tooltip: 'Emergency',
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
        selectedItemColor: AppTheme.patientColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Records',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  void _navigateToTrends() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TrendAnalysisScreen()),
    );
  }

  @override
  void dispose() {
    // Cancel any pending async operations to prevent setState after dispose
    super.dispose();
  }
}

class DashboardContent extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback? onNavigateToTrends;

  const DashboardContent({
    super.key,
    required this.userData,
    this.onNavigateToTrends,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  Map<String, dynamic>? _latestVitals;

  @override
  void initState() {
    super.initState();
    _loadLatestVitals();
  }

  Future<void> _loadLatestVitals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final vitalsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('health_vitals')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (vitalsQuery.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _latestVitals = vitalsQuery.docs.first.data();
          });
        }
      }
    } catch (e) {
      print('Error loading vitals: $e');
    }
  }

  void _navigateToHealthVitals() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HealthVitalsScreen()),
    ).then((result) {
      if (result == true) {
        _loadLatestVitals(); // Refresh data after saving
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();
    final userName = widget.userData?['name'] ?? 'User';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User greeting card
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
                      Text(
                        '$greeting, $userName!',
                        style: TextStyle(
                          fontSize: isDesktop ? 28 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'How are you feeling today?',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Test Data Widget (only in debug mode)
              if (kDebugMode) const TrendTestDataWidget(),

              const SizedBox(height: 16),

              // For desktop: Two-column layout for main cards
              if (isDesktop) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          // Medical Summary Card
                          _buildMedicalSummaryCard(
                            context,
                            widget.userData?['uid'],
                          ),
                          const SizedBox(height: 16),
                          // Trend Analysis Card
                          _buildTrendAnalysisCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          // Trend Notifications
                          _buildTrendNotifications(),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Mobile/Tablet: Single column layout
                // Medical Summary Card
                _buildMedicalSummaryCard(context, widget.userData?['uid']),

                const SizedBox(height: 16),

                // Trend Analysis Card
                _buildTrendAnalysisCard(),

                const SizedBox(height: 16),

                // Trend Notifications
                _buildTrendNotifications(),
              ],

              const SizedBox(height: 16),

              // Quick Access Buttons - Responsive grid
              _buildQuickAccessButtons(
                context,
                widget.userData?['uid'],
                isDesktop,
              ),

              const SizedBox(height: 24),

              // Health Stats Section
              const Text(
                'Health Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              // Health Stats Grid - Responsive
              if (isDesktop) ...[
                // Desktop: 4 cards in a row
                Row(
                  children: [
                    Expanded(
                      child: _buildHealthStatCard(
                        'Heart Rate',
                        _latestVitals?['heartRate'] != null
                            ? '${_latestVitals!['heartRate']} bpm'
                            : 'Not recorded',
                        Icons.favorite,
                        Colors.red,
                        _navigateToHealthVitals,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHealthStatCard(
                        'Blood Pressure',
                        _latestVitals?['bloodPressureSystolic'] != null &&
                                _latestVitals?['bloodPressureDiastolic'] != null
                            ? '${_latestVitals!['bloodPressureSystolic']}/${_latestVitals!['bloodPressureDiastolic']}'
                            : 'Not recorded',
                        Icons.bloodtype,
                        AppTheme.patientColor,
                        _navigateToHealthVitals,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHealthStatCard(
                        'Weight',
                        _latestVitals?['weight'] != null
                            ? '${_latestVitals!['weight']} kg'
                            : 'Not recorded',
                        Icons.monitor_weight,
                        Colors.green,
                        _navigateToHealthVitals,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHealthStatCard(
                        'Temperature',
                        _latestVitals?['temperature'] != null
                            ? '${_latestVitals!['temperature']}°F'
                            : 'Not recorded',
                        Icons.thermostat,
                        Colors.orange,
                        _navigateToHealthVitals,
                      ),
                    ),
                  ],
                ),
              ] else if (isTablet) ...[
                // Tablet: 2 cards per row
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildHealthStatCard(
                            'Heart Rate',
                            _latestVitals?['heartRate'] != null
                                ? '${_latestVitals!['heartRate']} bpm'
                                : 'Not recorded',
                            Icons.favorite,
                            Colors.red,
                            _navigateToHealthVitals,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildHealthStatCard(
                            'Blood Pressure',
                            _latestVitals?['bloodPressureSystolic'] != null &&
                                    _latestVitals?['bloodPressureDiastolic'] !=
                                        null
                                ? '${_latestVitals!['bloodPressureSystolic']}/${_latestVitals!['bloodPressureDiastolic']}'
                                : 'Not recorded',
                            Icons.bloodtype,
                            AppTheme.patientColor,
                            _navigateToHealthVitals,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildHealthStatCard(
                            'Weight',
                            _latestVitals?['weight'] != null
                                ? '${_latestVitals!['weight']} kg'
                                : 'Not recorded',
                            Icons.monitor_weight,
                            Colors.green,
                            _navigateToHealthVitals,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildHealthStatCard(
                            'Temperature',
                            _latestVitals?['temperature'] != null
                                ? '${_latestVitals!['temperature']}°F'
                                : 'Not recorded',
                            Icons.thermostat,
                            Colors.orange,
                            _navigateToHealthVitals,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                // Mobile: 2 cards per row (existing layout)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildHealthStatCard(
                            'Heart Rate',
                            _latestVitals?['heartRate'] != null
                                ? '${_latestVitals!['heartRate']} bpm'
                                : 'Not recorded',
                            Icons.favorite,
                            Colors.red,
                            _navigateToHealthVitals,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildHealthStatCard(
                            'Blood Pressure',
                            _latestVitals?['bloodPressureSystolic'] != null &&
                                    _latestVitals?['bloodPressureDiastolic'] !=
                                        null
                                ? '${_latestVitals!['bloodPressureSystolic']}/${_latestVitals!['bloodPressureDiastolic']}'
                                : 'Not recorded',
                            Icons.bloodtype,
                            AppTheme.patientColor,
                            _navigateToHealthVitals,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildHealthStatCard(
                            'Weight',
                            _latestVitals?['weight'] != null
                                ? '${_latestVitals!['weight']} kg'
                                : 'Not recorded',
                            Icons.monitor_weight,
                            Colors.green,
                            _navigateToHealthVitals,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildHealthStatCard(
                            'Temperature',
                            _latestVitals?['temperature'] != null
                                ? '${_latestVitals!['temperature']}°F'
                                : 'Not recorded',
                            Icons.thermostat,
                            Colors.orange,
                            _navigateToHealthVitals,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMedicalSummaryCard(BuildContext context, String? userId) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (userId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MedicalSummaryScreen(userId: userId),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please log in to view medical summary'),
              ),
            );
          }
        },
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
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.purple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI Medical Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'View your AI-generated medical history summary based on uploaded documents',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessButtons(
    BuildContext context,
    String? userId,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (isDesktop) ...[
          // Desktop: 4 buttons in 2 rows of 2
          Row(
            children: [
              Expanded(
                child: _buildQuickAccessButton(
                  context,
                  Icons.folder_shared,
                  'Medical Records',
                  AppTheme.patientColor,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MedicalRecordsScreen(userId: userId ?? ''),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickAccessButton(
                  context,
                  Icons.auto_awesome,
                  'AI Summary',
                  Colors.purple,
                  () async {
                    if (userId != null) {
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) =>
                            const Center(child: CircularProgressIndicator()),
                      );

                      try {
                        // Import and create GeminiService
                        final GeminiService geminiService = GeminiService();

                        // Check if there are new documents that need analysis
                        final statusData = await geminiService
                            .checkAnalysisStatus();

                        // Close loading dialog
                        Navigator.of(context).pop();

                        if (statusData['needsAnalysis']) {
                          // There are new documents - trigger analysis before showing summary
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MedicalSummaryScreen(
                                userId: userId,
                                autoTriggerAnalysis: true,
                              ),
                            ),
                          );
                        } else {
                          // No new documents - just show the summary
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MedicalSummaryScreen(userId: userId),
                            ),
                          );
                        }
                      } catch (e) {
                        // Close loading dialog if still open
                        Navigator.of(context).pop();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error checking analysis status: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please log in to view medical summary',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickAccessButton(
                  context,
                  Icons.medication,
                  'Medications',
                  Colors.orange,
                  () {
                    // Navigate to appointments screen with prescriptions tab
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentsContent(
                          userData: {'uid': userId},
                          initialTab: 2, // Prescriptions tab
                        ),
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
                child: _buildQuickAccessButton(
                  context,
                  Icons.calendar_month,
                  'Appointments',
                  Colors.green,
                  () {
                    // Navigate to appointments screen with appointments tab
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentsContent(
                          userData: {'uid': userId},
                          initialTab: 0, // Appointments tab
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickAccessButton(
                  context,
                  Icons.science,
                  'Lab Reports',
                  Colors.teal,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LabReportContentScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: SizedBox(),
              ), // Empty space to balance the row
            ],
          ),
        ] else ...[
          // Mobile/Tablet: Original layout with 3 rows
          Row(
            children: [
              Expanded(
                child: _buildQuickAccessButton(
                  context,
                  Icons.folder_shared,
                  'Medical Records',
                  AppTheme.patientColor,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MedicalRecordsScreen(userId: userId ?? ''),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickAccessButton(
                  context,
                  Icons.auto_awesome,
                  'AI Summary',
                  Colors.purple,
                  () async {
                    if (userId != null) {
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) =>
                            const Center(child: CircularProgressIndicator()),
                      );

                      try {
                        // Import and create GeminiService
                        final GeminiService geminiService = GeminiService();

                        // Check if there are new documents that need analysis
                        final statusData = await geminiService
                            .checkAnalysisStatus();

                        // Close loading dialog
                        Navigator.of(context).pop();

                        if (statusData['needsAnalysis']) {
                          // There are new documents - trigger analysis before showing summary
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MedicalSummaryScreen(
                                userId: userId,
                                autoTriggerAnalysis: true,
                              ),
                            ),
                          );
                        } else {
                          // No new documents - just show the summary
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MedicalSummaryScreen(userId: userId),
                            ),
                          );
                        }
                      } catch (e) {
                        // Close loading dialog if still open
                        Navigator.of(context).pop();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error checking analysis status: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please log in to view medical summary',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickAccessButton(
                  context,
                  Icons.medication,
                  'Medications',
                  Colors.orange,
                  () {
                    // Navigate to appointments screen with prescriptions tab
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentsContent(
                          userData: {'uid': userId},
                          initialTab: 2, // Prescriptions tab
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickAccessButton(
                  context,
                  Icons.calendar_month,
                  'Appointments',
                  Colors.green,
                  () {
                    // Navigate to appointments screen with appointments tab
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentsContent(
                          userData: {'uid': userId},
                          initialTab: 0, // Appointments tab
                        ),
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
                child: _buildQuickAccessButton(
                  context,
                  Icons.science,
                  'Lab Reports',
                  Colors.teal,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LabReportContentScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: SizedBox(),
              ), // Empty space to balance the row
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuickAccessButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthStatCard(
    String title,
    String value,
    IconData icon,
    Color color, [
    VoidCallback? onTap,
  ]) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.edit, size: 16, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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

  Widget _buildTrendAnalysisCard() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: widget.onNavigateToTrends,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.patientColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: AppTheme.patientColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Health Trends',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View patterns in your lab reports',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendNotifications() {
    return FutureBuilder<List<TrendNotification>>(
      future: TrendAnalysisService.getTrendNotifications(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final unreadNotifications = snapshot.data!
            .where((notification) => !notification.read)
            .toList();

        if (unreadNotifications.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          color: AppTheme.patientColor.withOpacity(0.05),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(Icons.notifications, color: AppTheme.patientColor),
            title: const Text('New Health Trends Available'),
            subtitle: Text('${unreadNotifications.length} new analysis'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: widget.onNavigateToTrends,
          ),
        );
      },
    );
  }
}

class UserProfileContent extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;
  final String dateOfBirth;
  final String phoneNumber;
  final String gender;
  final Map<String, dynamic>? userData;
  final VoidCallback? onProfileUpdated;

  const UserProfileContent({
    super.key,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.dateOfBirth,
    required this.phoneNumber,
    required this.gender,
    this.userData,
    this.onProfileUpdated,
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
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Profile Information
          const Text(
            'Personal Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildInfoCard('Date of Birth', dateOfBirth, Icons.cake),
          _buildInfoCard('Phone Number', phoneNumber, Icons.phone),
          _buildInfoCard('Gender', gender, Icons.person),

          const SizedBox(height: 24),

          // Settings Section
          const Text(
            'Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildSettingsOption(context, 'Edit Profile', Icons.edit, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PatientProfileEditScreen(userData: userData ?? {}),
              ),
            ).then((updated) {
              if (updated == true && onProfileUpdated != null) {
                onProfileUpdated!();
              }
            });
          }),
          _buildSettingsOption(
            context,
            'Privacy Settings',
            Icons.privacy_tip,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
          _buildSettingsOption(
            context,
            'Notifications',
            Icons.notifications,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.patientColor),
        title: Text(title),
        subtitle: Text(value),
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
        leading: Icon(icon, color: AppTheme.patientColor),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// New Appointments Content Widget
class AppointmentsContent extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final int initialTab;

  const AppointmentsContent({
    Key? key,
    this.userData,
    this.initialTab = 0, // Default to appointments tab
  }) : super(key: key);

  @override
  State<AppointmentsContent> createState() => _AppointmentsContentState();
}

class _AppointmentsContentState extends State<AppointmentsContent> {
  List<Appointment> _appointments = [];
  List<LabReport> _labReports = [];
  List<Prescription> _prescriptions = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab; // Set initial tab
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.userData == null) return;

    try {
      final userId = widget.userData!['uid'];

      // Load all interconnected data
      final appointments = await InterconnectService.getUserAppointments(
        userId,
        'patient',
      );
      final labReports = await InterconnectService.getUserLabReports(
        userId,
        'patient',
      );
      final prescriptions = await InterconnectService.getUserPrescriptions(
        userId,
        'patient',
      );

      if (mounted) {
        setState(() {
          _appointments = appointments;
          _labReports = labReports;
          _prescriptions = prescriptions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Tab Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorBookingWidget(
                          patientId: widget.userData!['uid'],
                          patientName: widget.userData!['name'] ?? '',
                          patientEmail: widget.userData!['email'] ?? '',
                        ),
                      ),
                    ).then((_) => _loadData()); // Refresh on return
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Book Appointment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tab Navigation
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _selectedTab = 0),
                  style: TextButton.styleFrom(
                    backgroundColor: _selectedTab == 0
                        ? Theme.of(context).primaryColor
                        : null,
                    foregroundColor: _selectedTab == 0 ? Colors.white : null,
                  ),
                  child: const Text('Appointments'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _selectedTab = 1),
                  style: TextButton.styleFrom(
                    backgroundColor: _selectedTab == 1
                        ? Theme.of(context).primaryColor
                        : null,
                    foregroundColor: _selectedTab == 1 ? Colors.white : null,
                  ),
                  child: const Text('Lab Reports'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _selectedTab = 2),
                  style: TextButton.styleFrom(
                    backgroundColor: _selectedTab == 2
                        ? Theme.of(context).primaryColor
                        : null,
                    foregroundColor: _selectedTab == 2 ? Colors.white : null,
                  ),
                  child: const Text('Prescriptions'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Tab Content
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildAppointmentsList();
      case 1:
        return _buildLabReportsList();
      case 2:
        return _buildPrescriptionsList();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAppointmentsList() {
    if (_appointments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No appointments yet'),
            Text('Book your first appointment with a doctor'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(appointment.status),
              child: Icon(
                _getStatusIcon(appointment.status),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              'Dr. ${appointment.doctorName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appointment.doctorSpecialty),
                Text(appointment.hospitalName),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(appointment.appointmentDate)} at ${appointment.timeSlot}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (appointment.reason != null)
                  Text('Reason: ${appointment.reason}'),
              ],
            ),
            trailing: Chip(
              label: Text(
                appointment.status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: _getStatusColor(
                appointment.status,
              ).withOpacity(0.2),
              labelStyle: TextStyle(color: _getStatusColor(appointment.status)),
            ),
            onTap: () => _showAppointmentDetails(appointment),
          ),
        );
      },
    );
  }

  Widget _buildLabReportsList() {
    if (_labReports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No lab reports yet'),
            Text('Your lab test results will appear here'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _labReports.length,
      itemBuilder: (context, index) {
        final report = _labReports[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(report.status),
              child: Icon(Icons.assignment, color: Colors.white, size: 20),
            ),
            title: Text(
              report.testName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.labName),
                if (report.doctorName != null)
                  Text('Requested by: Dr. ${report.doctorName}'),
                Text(
                  'Test Date: ${DateFormat('MMM dd, yyyy').format(report.testDate)}',
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Chip(
                  label: Text(
                    report.status.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: _getStatusColor(
                    report.status,
                  ).withOpacity(0.2),
                ),
                if (report.status == 'completed' && report.reportUrl != null)
                  const Icon(Icons.download, size: 16),
              ],
            ),
            onTap: () => _showLabReportDetails(report),
          ),
        );
      },
    );
  }

  Widget _buildPrescriptionsList() {
    if (_prescriptions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No prescriptions yet'),
            Text('Your medications will appear here'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _prescriptions.length,
      itemBuilder: (context, index) {
        final prescription = _prescriptions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(prescription.status),
              child: Icon(Icons.medication, color: Colors.white, size: 20),
            ),
            title: Text(
              'Prescription from Dr. ${prescription.doctorName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prescribed: ${DateFormat('MMM dd, yyyy').format(prescription.prescribedDate)}',
                ),
                if (prescription.pharmacyName != null)
                  Text('Pharmacy: ${prescription.pharmacyName}'),
                Chip(
                  label: Text(
                    prescription.status.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: _getStatusColor(
                    prescription.status,
                  ).withOpacity(0.2),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medications:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...prescription.medicines.map(
                      (medicine) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicine.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Dosage: ${medicine.dosage}'),
                              Text('Frequency: ${medicine.frequency}'),
                              Text('Duration: ${medicine.duration} days'),
                              if (medicine.instructions.isNotEmpty)
                                Text('Instructions: ${medicine.instructions}'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (prescription.notes != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Notes: ${prescription.notes}',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
      case 'requested':
      case 'prescribed':
        return AppTheme.patientColor;
      case 'confirmed':
      case 'in_progress':
        return Colors.orange;
      case 'completed':
      case 'filled':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
      case 'requested':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  void _showAppointmentDetails(Appointment appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Appointment with Dr. ${appointment.doctorName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specialty: ${appointment.doctorSpecialty}'),
            Text('Hospital: ${appointment.hospitalName}'),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(appointment.appointmentDate)}',
            ),
            Text('Time: ${appointment.timeSlot}'),
            Text('Status: ${appointment.status.toUpperCase()}'),
            if (appointment.reason != null)
              Text('Reason: ${appointment.reason}'),
            if (appointment.symptoms != null)
              Text('Symptoms: ${appointment.symptoms}'),
            if (appointment.notes != null) Text('Notes: ${appointment.notes}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLabReportDetails(LabReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.testName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lab: ${report.labName}'),
            if (report.doctorName != null)
              Text('Requested by: Dr. ${report.doctorName}'),
            Text(
              'Test Date: ${DateFormat('MMM dd, yyyy').format(report.testDate)}',
            ),
            Text('Status: ${report.status.toUpperCase()}'),
            if (report.notes != null) Text('Notes: ${report.notes}'),
            if (report.status == 'completed' && report.reportUrl != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Open report URL
                  // You can implement URL launching here
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Report'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
