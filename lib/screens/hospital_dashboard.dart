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
  bool isDarkMode = false;
  int _selectedBottomNav = 0;

  Map<String, dynamic>? hospitalData;
  List<Map<String, dynamic>> doctors = [];
  List<Map<String, dynamic>> patients = [];
  List<Map<String, dynamic>> appointments = [];
  bool _isLoading = true;

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
      doctors = doctorsSnap.docs.map((d) => d.data()).toList();

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
              child: doctors.isEmpty
                  ? const Center(child: Text('No staff members found'))
                  : ListView.builder(
                      itemCount: doctors.length,
                      itemBuilder: (context, index) {
                        final doctor = doctors[index];
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
    final Color mainBlue = const Color(0xFF7B61FF);
    final Color scaffoldBg = isDarkMode ? Colors.black : Colors.grey.shade50;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subTextColor = isDarkMode
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: mainBlue,
        foregroundColor: Colors.white,
        title: Text(hospitalData?['institutionName'] ?? 'Hospital Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
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
                          '${doctors.length}',
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
          ? const Center(child: Text('Analytics'))
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
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
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
