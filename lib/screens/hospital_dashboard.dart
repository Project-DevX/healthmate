import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../login.dart';
import 'analytics_page.dart';
import 'profile_page.dart';

class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({Key? key}) : super(key: key);

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  int _selectedBottomNav = 0;

  Map<String, dynamic>? hospitalData;
  bool _isLoading = true;

  // Sample data for enhanced functionality
  List<Map<String, dynamic>> staff = [
    {
      'id': 'DOC001',
      'fullName': 'Dr. Sarah Johnson',
      'specialization': 'Cardiology',
      'experience': '8 years',
      'department': 'Cardiology',
      'status': 'Active',
      'shift': 'Morning',
      'photoURL':
          'https://ui-avatars.com/api/?name=Sarah+Johnson&background=4CAF50&color=fff',
    },
    {
      'id': 'NUR001',
      'fullName': 'Emily Rodriguez',
      'specialization': 'ICU Nursing',
      'experience': '5 years',
      'department': 'ICU',
      'status': 'Active',
      'shift': 'Night',
      'photoURL':
          'https://ui-avatars.com/api/?name=Emily+Rodriguez&background=2196F3&color=fff',
    },
    {
      'id': 'DOC002',
      'fullName': 'Dr. Michael Chen',
      'specialization': 'Neurology',
      'experience': '12 years',
      'department': 'Neurology',
      'status': 'On Leave',
      'shift': 'Evening',
      'photoURL':
          'https://ui-avatars.com/api/?name=Michael+Chen&background=FF9800&color=fff',
    },
  ];

  List<Map<String, dynamic>> patients = [
    {
      'id': 'PAT001',
      'fullName': 'John Smith',
      'age': 45,
      'condition': 'Hypertension',
      'ward': 'Cardiology - Room 201',
      'admissionDate': '2025-07-10',
      'status': 'Stable',
      'assignedDoctor': 'Dr. Sarah Johnson',
    },
    {
      'id': 'PAT002',
      'fullName': 'Maria Garcia',
      'age': 32,
      'condition': 'Post-surgery recovery',
      'ward': 'ICU - Bed 5',
      'admissionDate': '2025-07-12',
      'status': 'Critical',
      'assignedDoctor': 'Dr. Michael Chen',
    },
    {
      'id': 'PAT003',
      'fullName': 'Robert Wilson',
      'age': 67,
      'condition': 'Diabetes management',
      'ward': 'General - Room 105',
      'admissionDate': '2025-07-13',
      'status': 'Improving',
      'assignedDoctor': 'Dr. Sarah Johnson',
    },
  ];

  List<Map<String, dynamic>> appointments = [
    {
      'id': 'APT001',
      'patientName': 'Alice Brown',
      'doctorName': 'Dr. Sarah Johnson',
      'time': '09:00 AM',
      'date': '2025-07-14',
      'type': 'Consultation',
      'status': 'Scheduled',
    },
    {
      'id': 'APT002',
      'patientName': 'David Lee',
      'doctorName': 'Dr. Michael Chen',
      'time': '11:30 AM',
      'date': '2025-07-14',
      'type': 'Follow-up',
      'status': 'In Progress',
    },
    {
      'id': 'APT003',
      'patientName': 'Lisa Wang',
      'doctorName': 'Dr. Sarah Johnson',
      'time': '02:00 PM',
      'date': '2025-07-14',
      'type': 'Surgery',
      'status': 'Scheduled',
    },
  ];

  List<Map<String, dynamic>> inventory = [
    {
      'name': 'Surgical Masks',
      'category': 'PPE',
      'currentStock': 500,
      'minStock': 100,
      'unit': 'pieces',
      'supplier': 'MedSupply Co',
      'lastRestocked': '2025-07-10',
    },
    {
      'name': 'Ventilator',
      'category': 'Equipment',
      'currentStock': 8,
      'minStock': 10,
      'unit': 'units',
      'supplier': 'MedTech Inc',
      'lastRestocked': '2025-06-15',
    },
    {
      'name': 'Blood Pressure Monitor',
      'category': 'Equipment',
      'currentStock': 25,
      'minStock': 15,
      'unit': 'units',
      'supplier': 'HealthCare Ltd',
      'lastRestocked': '2025-07-05',
    },
  ];

  // KPI calculations
  int get totalStaff => staff.length;
  int get activeStaff => staff.where((s) => s['status'] == 'Active').length;
  int get totalPatients => patients.length;
  int get criticalPatients =>
      patients.where((p) => p['status'] == 'Critical').length;
  int get todaysAppointments => appointments.length;
  int get lowStockItems =>
      inventory.where((i) => i['currentStock'] <= i['minStock']).length;

  final List<_DashboardFeature> _features = [
    _DashboardFeature('Staff Management', Icons.people),
    _DashboardFeature('Patient Records', Icons.folder_shared),
    _DashboardFeature('Appointments', Icons.calendar_today),
    _DashboardFeature('Inventory', Icons.inventory),
    _DashboardFeature('Reports', Icons.assessment),
    _DashboardFeature('Billing', Icons.receipt_long),
    _DashboardFeature('Analytics', Icons.show_chart),
    _DashboardFeature('Settings', Icons.settings),
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
      // Fetch hospital info
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (docSnap.exists) {
        hospitalData = docSnap.data();
      }

      // Fetch related doctors (if any)
      final doctorsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'doctor')
          .where('affiliation', isEqualTo: hospitalData?['institutionName'])
          .limit(10)
          .get();
      staff.addAll(doctorsSnap.docs.map((d) => d.data()).toList());

      // Fetch patients
      final patientsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'patient')
          .limit(10)
          .get();
      patients = patientsSnap.docs.map((d) => d.data()).toList();

      // Fetch recent appointments
      final appointmentsSnap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('hospitalId', isEqualTo: uid)
          .orderBy('date', descending: true)
          .limit(5)
          .get();
      appointments = appointmentsSnap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Error loading hospital dashboard data: $e');
    }
    setState(() => _isLoading = false);
  }

  void _onFeatureTap(String feature) {
    Widget? page;
    switch (feature) {
      case 'Staff Management':
        _showStaffManagement();
        return;
      case 'Patient Records':
        _showPatientRecords();
        return;
      case 'Appointments':
        _showAppointments();
        return;
      case 'Inventory':
        _showInventory();
        return;
      case 'Reports':
        _showReports();
        return;
      case 'Billing':
        _showBilling();
        return;
      case 'Analytics':
        page = const AnalyticsPage();
        break;
      case 'Settings':
        _showSettings();
        return;
    }
    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page!));
    }
  }

  void _showStaffManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Staff Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: staff.isEmpty
                  ? const Center(child: Text('No staff members found'))
                  : ListView.builder(
                      itemCount: staff.length,
                      itemBuilder: (context, index) {
                        final doctor = staff[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(
                                doctor['photoURL'] ??
                                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(doctor['fullName'] ?? 'Doctor')}&background=7B61FF&color=fff',
                              ),
                            ),
                            title: Text(doctor['fullName'] ?? 'Unknown'),
                            subtitle: Text(
                              doctor['specialization'] ?? 'General',
                            ),
                            trailing: Text(
                              doctor['experience'] ?? '0' + ' years',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPatientRecords() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Patient Records',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: patients.isEmpty
                  ? const Center(child: Text('No patient records found'))
                  : ListView.builder(
                      itemCount: patients.length,
                      itemBuilder: (context, index) {
                        final patient = patients[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(
                                patient['photoURL'] ??
                                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(patient['firstName'] ?? 'Patient')}&background=42A5F5&color=fff',
                              ),
                            ),
                            title: Text(
                              '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}',
                            ),
                            subtitle: Text(
                              'Age: ${patient['age'] ?? 'Unknown'}',
                            ),
                            trailing: Text(patient['gender'] ?? ''),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Appointments',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: appointments.isEmpty
                  ? const Center(child: Text('No appointments found'))
                  : ListView.builder(
                      itemCount: appointments.length,
                      itemBuilder: (context, index) {
                        final appointment = appointments[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.calendar_today,
                              color: Colors.blue,
                            ),
                            title: Text(
                              appointment['patientName'] ?? 'Unknown Patient',
                            ),
                            subtitle: Text(
                              '${appointment['date'] ?? ''} at ${appointment['time'] ?? ''}',
                            ),
                            trailing: Text(appointment['status'] ?? 'Pending'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInventory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inventory Management'),
        content: const Text('Inventory management feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReports() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reports'),
        content: const Text('Reports feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBilling() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Billing'),
        content: const Text('Billing feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Settings feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await AuthService.clearLoginState();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color mainBlue = theme.primaryColor;
    final Color scaffoldBg = theme.scaffoldBackgroundColor;
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final Color cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: mainBlue,
        foregroundColor: Colors.white,
        title: Text(hospitalData?['institutionName'] ?? 'Hospital Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Theme toggle requires app restart'),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
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
                  // Welcome Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: mainBlue,
                            child: Icon(
                              Icons.local_hospital,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${hospitalData?['institutionName'] ?? 'Hospital'}!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hospitalData?['institutionType'] ??
                                      'Healthcare Institution',
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
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Statistics Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Staff',
                          '${totalStaff}',
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Patients',
                          '${patients.length}',
                          Icons.person,
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
                          'Appointments',
                          '${appointments.length}',
                          Icons.calendar_today,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Revenue',
                          '\$0',
                          Icons.attach_money,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: _features.length,
                    itemBuilder: (context, index) {
                      final feature = _features[index];
                      return GestureDetector(
                        onTap: () => _onFeatureTap(feature.label),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(feature.icon, size: 32, color: mainBlue),
                                const SizedBox(height: 8),
                                Text(
                                  feature.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          : _selectedBottomNav == 1
          ? const Center(
              child: Text('Chat System (Stub)', style: TextStyle(fontSize: 20)),
            )
          : const ProfilePage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomNav,
        onTap: (index) => setState(() => _selectedBottomNav = index),
        type: BottomNavigationBarType.fixed,
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
