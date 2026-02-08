import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../models/shared_models.dart';
import '../services/interconnect_service.dart';
import '../theme/app_theme.dart';
import '../utils/user_data_utils.dart';
import '../widgets/notification_widget.dart';
import 'chat_page.dart';
import 'dart:io';

class LabDashboard extends StatefulWidget {
  const LabDashboard({Key? key}) : super(key: key);

  @override
  State<LabDashboard> createState() => _LabDashboardState();
}

class _LabDashboardState extends State<LabDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String? _labId;

  // Statistics
  int _totalTests = 0;
  int _pendingTests = 0;
  int _inProgressTests = 0;
  int _completedTests = 0;
  int _todaysTests = 0;
  int _urgentTests = 0;

  // Recent lab reports
  List<Map<String, dynamic>> _recentReports = [];
  // Pending requests
  List<Map<String, dynamic>> _pendingRequests = [];

  // Search
  String _searchQuery = '';
  String _selectedFilter = 'all';

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
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          if (mounted) {
            setState(() {
              _userData = userDoc.data();
              _userData!['uid'] = user.uid;
              _labId = user.uid;
              _isLoading = false;
            });
          }
          _loadStatistics(user.uid);
          _loadRecentReports(user.uid);
          _loadPendingRequests(user.uid);
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Lab Dashboard - Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStatistics(String labId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final reportsQuery = await _firestore
          .collection('lab_reports')
          .where('labId', isEqualTo: labId)
          .get();

      int pending = 0;
      int inProgress = 0;
      int completed = 0;
      int todayCount = 0;
      int urgent = 0;

      for (var doc in reportsQuery.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? '').toLowerCase();
        final priority = (data['priority'] as String? ?? '').toLowerCase();

        if (status == 'requested' || status == 'pending') pending++;
        if (status == 'in_progress' || status == 'processing') inProgress++;
        if (status == 'completed' || status == 'uploaded') completed++;
        if (priority == 'urgent' || priority == 'critical') urgent++;

        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final date = createdAt.toDate();
          if (date.isAfter(today.subtract(const Duration(seconds: 1))) &&
              date.isBefore(tomorrow)) {
            todayCount++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalTests = reportsQuery.docs.length;
          _pendingTests = pending;
          _inProgressTests = inProgress;
          _completedTests = completed;
          _todaysTests = todayCount;
          _urgentTests = urgent;
        });
      }
    } catch (e) {
      print('❌ Error loading lab statistics: $e');
    }
  }

  Future<void> _loadRecentReports(String labId) async {
    try {
      final reportsQuery = await _firestore
          .collection('lab_reports')
          .where('labId', isEqualTo: labId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final reports = reportsQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (mounted) {
        setState(() => _recentReports = reports);
      }
    } catch (e) {
      print('❌ Error loading recent reports: $e');
      // Fallback without orderBy if index doesn't exist
      try {
        final reportsQuery = await _firestore
            .collection('lab_reports')
            .where('labId', isEqualTo: labId)
            .limit(10)
            .get();

        final reports = reportsQuery.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        if (mounted) {
          setState(() => _recentReports = reports);
        }
      } catch (e2) {
        print('❌ Error loading recent reports (fallback): $e2');
      }
    }
  }

  Future<void> _loadPendingRequests(String labId) async {
    try {
      final requestsQuery = await _firestore
          .collection('lab_reports')
          .where('labId', isEqualTo: labId)
          .get();

      final pending = requestsQuery.docs
          .where((doc) {
            final status = (doc.data()['status'] as String? ?? '')
                .toLowerCase();
            return status == 'requested' || status == 'pending';
          })
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          })
          .toList();

      if (mounted) {
        setState(() => _pendingRequests = pending);
      }
    } catch (e) {
      print('❌ Error loading pending requests: $e');
    }
  }

  Future<void> _updateReportStatus(String reportId, String newStatus) async {
    try {
      await _firestore.collection('lab_reports').doc(reportId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (_labId != null) {
        _loadStatistics(_labId!);
        _loadRecentReports(_labId!);
        _loadPendingRequests(_labId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  Future<void> _uploadLabResult(Map<String, dynamic> report) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() => _isLoading = true);

        final file = File(pickedFile.path);
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('lab_reports')
            .child(
              '${report['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );

        await storageRef.putFile(file);
        final downloadUrl = await storageRef.getDownloadURL();

        await InterconnectService.uploadLabResult(report['id'], downloadUrl, {
          'uploaded_by': _getLabName(),
        }, notes: 'Results uploaded by lab staff');

        if (_labId != null) {
          _loadStatistics(_labId!);
          _loadRecentReports(_labId!);
          _loadPendingRequests(_labId!);
        }

        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lab results uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload results: $e')));
      }
    }
  }

  String _getLabName() {
    return _userData?['institutionName'] as String? ??
        _userData?['name'] as String? ??
        'Lab';
  }

  String _getLabInitials() {
    final name = _getLabName();
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'L';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sign out. Please try again.'),
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.labColor),
        ),
      );
    }

    if (_userData == null) {
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

    final List<Widget> screens = [
      _buildHomeScreen(),
      _buildTestRequestsPage(),
      _buildReportsPage(),
      _buildProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.labColor,
        foregroundColor: Colors.white,
        actions: [
          NotificationBadge(
            userId: _userData!['uid'],
            onTap: _showNotificationsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppTheme.labColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science_outlined),
            activeIcon: Icon(Icons.science),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Lab Dashboard';
      case 1:
        return 'Test Requests';
      case 2:
        return 'Lab Reports';
      case 3:
        return 'Lab Profile';
      default:
        return 'Lab Dashboard';
    }
  }

  // ──────────────────────────────────────────
  //  DRAWER
  // ──────────────────────────────────────────

  Widget _buildDrawer() {
    final name = _getLabName();
    final email =
        _userData?['officialEmail'] as String? ??
        _userData?['email'] as String? ??
        '';
    final profileImage = _userData?['photoURL'] as String?;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: AppTheme.labColor),
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
                const Text(
                  'Laboratory',
                  style: TextStyle(
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
                      _getLabInitials(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.labColor,
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
                  leading: const Icon(Icons.assignment_outlined),
                  title: const Text('Test Requests'),
                  selected: _selectedIndex == 1,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Lab Reports'),
                  selected: _selectedIndex == 2,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outlined),
                  title: const Text('Profile'),
                  selected: _selectedIndex == 3,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 3);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.chat_outlined),
                  title: const Text('Messages'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChatPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    _showNotificationsDialog();
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
                  onTap: () {
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
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //  TAB 0: HOME / DASHBOARD
  // ──────────────────────────────────────────

  Widget _buildHomeScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return RefreshIndicator(
          onRefresh: () async => await _loadUserData(),
          color: AppTheme.labColor,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: 16),
                if (isDesktop) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatsGrid(),
                            const SizedBox(height: 24),
                            _buildQuickActionsSection(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _buildPendingRequestsSection(),
                            const SizedBox(height: 24),
                            _buildRecentActivitySection(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  _buildPendingRequestsSection(),
                  const SizedBox(height: 24),
                  _buildQuickActionsSection(),
                  const SizedBox(height: 24),
                  _buildRecentActivitySection(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard() {
    final name = _getLabName();
    final greeting = _getGreeting();
    final profileImage = _userData?['photoURL'] as String?;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.labColor.withOpacity(0.2),
              backgroundImage: profileImage != null
                  ? NetworkImage(profileImage)
                  : null,
              child: profileImage == null
                  ? Text(
                      _getLabInitials(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.labColor,
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
                    name,
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
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard(
              'Total Tests',
              _totalTests.toString(),
              Icons.assignment_turned_in,
              Colors.blue,
            ),
            _buildStatCard(
              'Pending',
              _pendingTests.toString(),
              Icons.hourglass_empty,
              Colors.orange,
            ),
            _buildStatCard(
              'In Progress',
              _inProgressTests.toString(),
              Icons.autorenew,
              AppTheme.labColor,
            ),
            _buildStatCard(
              'Completed',
              _completedTests.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ],
        );
      },
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

  Widget _buildPendingRequestsSection() {
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
                Row(
                  children: [
                    const Text(
                      'Pending Requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_pendingRequests.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_pendingRequests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  child: Text(
                    'View All',
                    style: TextStyle(color: AppTheme.labColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _pendingRequests.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: Colors.green,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No pending requests',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pendingRequests.length > 5
                        ? 5
                        : _pendingRequests.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final request = _pendingRequests[index];
                      return _buildRequestListItem(request);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestListItem(Map<String, dynamic> request) {
    final patientName = request['patientName'] as String? ?? 'Unknown Patient';
    final testType = request['testType'] as String? ?? 'Lab Test';
    final priority = request['priority'] as String? ?? 'Normal';
    final isUrgent =
        priority.toLowerCase() == 'urgent' ||
        priority.toLowerCase() == 'critical';
    final createdAt = request['createdAt'] as Timestamp?;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isUrgent
            ? Colors.red.withOpacity(0.2)
            : AppTheme.labColor.withOpacity(0.2),
        child: Icon(
          _getTestIcon(testType),
          color: isUrgent ? Colors.red : AppTheme.labColor,
        ),
      ),
      title: Text(
        patientName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(testType),
          if (createdAt != null)
            Text(
              DateFormat('MMM d, h:mm a').format(createdAt.toDate()),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUrgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Text(
                'URGENT',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            tooltip: 'Start Processing',
            onPressed: () => _updateReportStatus(request['id'], 'in_progress'),
          ),
        ],
      ),
      onTap: () => _showReportDetailsDialog(request),
    );
  }

  Widget _buildQuickActionsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                GridView.count(
                  crossAxisCount: isDesktop ? 4 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildQuickActionItem(
                      icon: Icons.upload_file,
                      label: 'Upload\nResults',
                      color: Colors.blue,
                      onTap: () => _showUploadDialog(),
                    ),
                    _buildQuickActionItem(
                      icon: Icons.search,
                      label: 'Search\nPatient',
                      color: Colors.green,
                      onTap: () => _showPatientSearchDialog(),
                    ),
                    _buildQuickActionItem(
                      icon: Icons.assignment,
                      label: 'View\nRequests',
                      color: Colors.orange,
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                    _buildQuickActionItem(
                      icon: Icons.bar_chart,
                      label: 'View\nStats',
                      color: Colors.purple,
                      onTap: () => _showStatsDialog(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
        mainAxisAlignment: MainAxisAlignment.center,
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

  Widget _buildRecentActivitySection() {
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
                  'Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 2),
                  child: Text(
                    'View All',
                    style: TextStyle(color: AppTheme.labColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _recentReports.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No recent activity'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentReports.length > 5
                        ? 5
                        : _recentReports.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final report = _recentReports[index];
                      return _buildActivityItem(report);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> report) {
    final status = (report['status'] as String? ?? 'pending').toLowerCase();
    final patientName = report['patientName'] as String? ?? 'Unknown';
    final testType = report['testType'] as String? ?? 'Lab Test';
    final createdAt = report['createdAt'] as Timestamp?;

    final statusConfig = _getStatusConfig(status);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: statusConfig.color.withOpacity(0.2),
        child: Icon(statusConfig.icon, color: statusConfig.color, size: 20),
      ),
      title: Text(
        testType,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        'Patient: $patientName',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusConfig.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusConfig.color.withOpacity(0.3)),
            ),
            child: Text(
              statusConfig.label,
              style: TextStyle(
                color: statusConfig.color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatTimeAgo(createdAt.toDate()),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ],
      ),
      onTap: () => _showReportDetailsDialog(report),
    );
  }

  // ──────────────────────────────────────────
  //  TAB 1: TEST REQUESTS
  // ──────────────────────────────────────────

  Widget _buildTestRequestsPage() {
    return Column(
      children: [
        // Search & Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search test requests...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', 'pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('In Progress', 'in_progress'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed', 'completed'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Urgent', 'urgent'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _labId != null
                ? _firestore
                      .collection('lab_reports')
                      .where('labId', isEqualTo: _labId)
                      .snapshots()
                : null,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = (data['status'] as String? ?? '').toLowerCase();
                final priority = (data['priority'] as String? ?? '')
                    .toLowerCase();
                final patientName = (data['patientName'] as String? ?? '')
                    .toLowerCase();
                final testType = (data['testType'] as String? ?? '')
                    .toLowerCase();

                // Filter
                bool matchesFilter = true;
                if (_selectedFilter == 'pending') {
                  matchesFilter = status == 'requested' || status == 'pending';
                } else if (_selectedFilter == 'in_progress') {
                  matchesFilter =
                      status == 'in_progress' || status == 'processing';
                } else if (_selectedFilter == 'completed') {
                  matchesFilter = status == 'completed' || status == 'uploaded';
                } else if (_selectedFilter == 'urgent') {
                  matchesFilter =
                      priority == 'urgent' || priority == 'critical';
                }

                // Search
                bool matchesSearch =
                    _searchQuery.isEmpty ||
                    patientName.contains(_searchQuery.toLowerCase()) ||
                    testType.contains(_searchQuery.toLowerCase());

                return matchesFilter && matchesSearch;
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No test requests found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _loadUserData(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    data['id'] = filteredDocs[index].id;
                    return _buildTestRequestCard(data);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.labColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.labColor : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildTestRequestCard(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    final patientName = data['patientName'] as String? ?? 'Unknown Patient';
    final testType = data['testType'] as String? ?? 'Lab Test';
    final priority = data['priority'] as String? ?? 'Normal';
    final doctorName = data['doctorName'] as String? ?? 'Unknown Doctor';
    final isUrgent =
        priority.toLowerCase() == 'urgent' ||
        priority.toLowerCase() == 'critical';
    final createdAt = data['createdAt'] as Timestamp?;
    final statusConfig = _getStatusConfig(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUrgent
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReportDetailsDialog(data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusConfig.color.withOpacity(0.2),
                    child: Icon(
                      _getTestIcon(testType),
                      color: statusConfig.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          testType,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Patient: $patientName',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusConfig.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusConfig.color.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      statusConfig.label,
                      style: TextStyle(
                        color: statusConfig.color,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person_outlined,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dr. $doctorName',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (isUrgent) ...[
                    const Icon(
                      Icons.priority_high,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Urgent',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeAgo(createdAt.toDate()),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
              if (status == 'requested' || status == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _updateReportStatus(data['id'], 'in_progress'),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Start Processing'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _uploadLabResult(data),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Upload Result'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.labColor,
                          side: BorderSide(color: AppTheme.labColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (status == 'in_progress' || status == 'processing') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _uploadLabResult(data),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Results'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.labColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  TAB 2: ALL REPORTS
  // ──────────────────────────────────────────

  Widget _buildReportsPage() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search reports by patient name or test type...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _labId != null
                ? _firestore
                      .collection('lab_reports')
                      .where('labId', isEqualTo: _labId)
                      .snapshots()
                : null,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final filtered = docs.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final pName = (data['patientName'] as String? ?? '')
                    .toLowerCase();
                final tType = (data['testType'] as String? ?? '').toLowerCase();
                return pName.contains(_searchQuery.toLowerCase()) ||
                    tType.contains(_searchQuery.toLowerCase());
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No reports found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _loadUserData(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index].data() as Map<String, dynamic>;
                    data['id'] = filtered[index].id;
                    return _buildTestRequestCard(data);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //  TAB 3: PROFILE
  // ──────────────────────────────────────────

  Widget _buildProfilePage() {
    final profileImage = _userData?['photoURL'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Header
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.labColor.withOpacity(0.2),
                        backgroundImage: profileImage != null
                            ? NetworkImage(profileImage)
                            : null,
                        child: profileImage == null
                            ? Text(
                                _getLabInitials(),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.labColor,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadPhoto,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.labColor,
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getLabName(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData?['officialEmail'] as String? ?? 'Email not set',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _showEditProfileDialog,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.labColor,
                      side: BorderSide(color: AppTheme.labColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lab Details Card
          _buildProfileInfoCard('Lab Details', [
            _ProfileField('Institution Name', _userData?['institutionName']),
            _ProfileField('License Number', _userData?['licenseNumber']),
            _ProfileField('Hotline', _userData?['hotline']),
            _ProfileField('Address', _userData?['address']),
            _ProfileField('Website', _userData?['website']),
          ]),
          const SizedBox(height: 16),

          // Representative Card
          _buildProfileInfoCard('Authorized Representative', [
            _ProfileField('Name', _userData?['repName']),
            _ProfileField('Designation', _userData?['repDesignation']),
            _ProfileField('Contact', _userData?['repContact']),
            _ProfileField('Email', _userData?['repEmail']),
          ]),
          const SizedBox(height: 16),

          // Operations Card
          _buildProfileInfoCard('Operations', [
            _ProfileField('Operating Hours', _userData?['operatingHours']),
            _ProfileField('Test Types', _userData?['testTypes']),
            _ProfileField('Turnaround Time', _userData?['turnaroundTime']),
          ]),
          const SizedBox(height: 16),

          // Stats Summary Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statistics Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Total Tests Processed', '$_totalTests'),
                  _buildStatRow('Completed', '$_completedTests'),
                  _buildStatRow('In Progress', '$_inProgressTests'),
                  _buildStatRow('Pending', '$_pendingTests'),
                  _buildStatRow('Today\'s Tests', '$_todaysTests'),
                  _buildStatRow('Urgent Tests', '$_urgentTests'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard(String title, List<_ProfileField> fields) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...fields.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        f.label,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        f.value?.toString().isNotEmpty == true
                            ? f.value.toString()
                            : 'Not set',
                        style: TextStyle(
                          color: f.value?.toString().isNotEmpty == true
                              ? null
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //  DIALOGS
  // ──────────────────────────────────────────

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
                child: _userData != null
                    ? NotificationWidget(
                        userId: _userData!['uid'],
                        userType: 'lab',
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDetailsDialog(Map<String, dynamic> report) {
    final status = (report['status'] as String? ?? 'pending').toLowerCase();
    final statusConfig = _getStatusConfig(status);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              _getTestIcon(report['testType'] ?? ''),
              color: AppTheme.labColor,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(report['testType'] as String? ?? 'Lab Test')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Patient', report['patientName'] ?? 'Unknown'),
              _detailRow('Doctor', report['doctorName'] ?? 'Unknown'),
              _detailRow('Priority', report['priority'] ?? 'Normal'),
              _detailRow('Status', statusConfig.label),
              if (report['notes'] != null) _detailRow('Notes', report['notes']),
              if (report['createdAt'] != null)
                _detailRow(
                  'Created',
                  DateFormat(
                    'MMM d, yyyy h:mm a',
                  ).format((report['createdAt'] as Timestamp).toDate()),
                ),
              if (report['resultUrl'] != null) _detailRow('Result', 'Uploaded'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (status == 'requested' || status == 'pending')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _updateReportStatus(report['id'], 'in_progress');
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          if (status == 'in_progress' || status == 'processing')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _uploadLabResult(report);
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.labColor,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showUploadDialog() {
    if (_pendingRequests.isEmpty && _recentReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reports available to upload results for'),
        ),
      );
      return;
    }

    final reports = [..._pendingRequests];
    for (final r in _recentReports) {
      final status = (r['status'] as String? ?? '').toLowerCase();
      if ((status == 'in_progress' || status == 'processing') &&
          !reports.any((p) => p['id'] == r['id'])) {
        reports.add(r);
      }
    }

    if (reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending or in-progress reports to upload for'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Select Report to Upload Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.labColor.withOpacity(0.2),
                          child: Icon(
                            _getTestIcon(report['testType'] ?? ''),
                            color: AppTheme.labColor,
                          ),
                        ),
                        title: Text(
                          report['testType'] as String? ?? 'Lab Test',
                        ),
                        subtitle: Text(
                          'Patient: ${report['patientName'] ?? 'Unknown'}',
                        ),
                        trailing: const Icon(Icons.upload_file),
                        onTap: () {
                          Navigator.pop(context);
                          _uploadLabResult(report);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatientSearchDialog() {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setBottomState) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Search Patient',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Enter patient name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setBottomState(() {}),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _labId != null
                        ? _firestore
                              .collection('lab_reports')
                              .where('labId', isEqualTo: _labId)
                              .snapshots()
                        : null,
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      final query = searchController.text.toLowerCase().trim();
                      final results = query.isEmpty
                          ? docs
                          : docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final pName =
                                  (data['patientName'] as String? ?? '')
                                      .toLowerCase();
                              return pName.contains(query);
                            }).toList();

                      if (results.isEmpty) {
                        return const Center(
                          child: Text(
                            'No results found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final data =
                              results[index].data() as Map<String, dynamic>;
                          data['id'] = results[index].id;
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(
                                data['patientName'] ?? 'Unknown Patient',
                              ),
                              subtitle: Text(
                                '${data['testType'] ?? 'Test'} - ${_getStatusConfig((data['status'] as String? ?? '').toLowerCase()).label}',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _showReportDetailsDialog(data);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.bar_chart, color: AppTheme.labColor),
            const SizedBox(width: 8),
            const Text('Lab Statistics'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total Tests', '$_totalTests'),
            const Divider(),
            _buildStatRow('Pending', '$_pendingTests'),
            _buildStatRow('In Progress', '$_inProgressTests'),
            _buildStatRow('Completed', '$_completedTests'),
            const Divider(),
            _buildStatRow('Today\'s Tests', '$_todaysTests'),
            _buildStatRow('Urgent Tests', '$_urgentTests'),
            const Divider(),
            _buildStatRow(
              'Completion Rate',
              _totalTests > 0
                  ? '${(_completedTests / _totalTests * 100).toStringAsFixed(1)}%'
                  : 'N/A',
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

  void _showEditProfileDialog() {
    final institutionNameCtrl = TextEditingController(
      text: _userData?['institutionName'] ?? '',
    );
    final hotlineCtrl = TextEditingController(
      text: _userData?['hotline'] ?? '',
    );
    final addressCtrl = TextEditingController(
      text: _userData?['address'] ?? '',
    );
    final websiteCtrl = TextEditingController(
      text: _userData?['website'] ?? '',
    );
    final repNameCtrl = TextEditingController(
      text: _userData?['repName'] ?? '',
    );
    final repDesigCtrl = TextEditingController(
      text: _userData?['repDesignation'] ?? '',
    );
    final repContactCtrl = TextEditingController(
      text: _userData?['repContact'] ?? '',
    );
    final repEmailCtrl = TextEditingController(
      text: _userData?['repEmail'] ?? '',
    );
    final hoursCtrl = TextEditingController(
      text: _userData?['operatingHours'] ?? '',
    );
    final testTypesCtrl = TextEditingController(
      text: _userData?['testTypes'] ?? '',
    );
    final turnaroundCtrl = TextEditingController(
      text: _userData?['turnaroundTime'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Edit Lab Profile'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lab Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: institutionNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Institution Name',
                  ),
                ),
                TextField(
                  controller: hotlineCtrl,
                  decoration: const InputDecoration(labelText: 'Hotline'),
                ),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: websiteCtrl,
                  decoration: const InputDecoration(labelText: 'Website'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Authorized Representative',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: repNameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: repDesigCtrl,
                  decoration: const InputDecoration(labelText: 'Designation'),
                ),
                TextField(
                  controller: repContactCtrl,
                  decoration: const InputDecoration(labelText: 'Contact'),
                ),
                TextField(
                  controller: repEmailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Operations',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hoursCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Operating Hours',
                  ),
                ),
                TextField(
                  controller: testTypesCtrl,
                  decoration: const InputDecoration(labelText: 'Test Types'),
                ),
                TextField(
                  controller: turnaroundCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Turnaround Time',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = _auth.currentUser;
                if (user == null) return;
                await _firestore.collection('users').doc(user.uid).update({
                  'institutionName': institutionNameCtrl.text.trim(),
                  'hotline': hotlineCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'website': websiteCtrl.text.trim(),
                  'repName': repNameCtrl.text.trim(),
                  'repDesignation': repDesigCtrl.text.trim(),
                  'repContact': repContactCtrl.text.trim(),
                  'repEmail': repEmailCtrl.text.trim(),
                  'operatingHours': hoursCtrl.text.trim(),
                  'testTypes': testTypesCtrl.text.trim(),
                  'turnaroundTime': turnaroundCtrl.text.trim(),
                });
                await _loadUserData();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating profile: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.labColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _isLoading = true);
      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance.ref().child(
        'lab_profile_photos/${user.uid}.jpg',
      );
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();
      await _firestore.collection('users').doc(user.uid).update({
        'photoURL': url,
      });
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ──────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────

  IconData _getTestIcon(String testType) {
    final lower = testType.toLowerCase();
    if (lower.contains('blood')) return Icons.water_drop;
    if (lower.contains('cardiac') || lower.contains('heart'))
      return Icons.favorite;
    if (lower.contains('liver')) return Icons.health_and_safety;
    if (lower.contains('urine')) return Icons.science;
    if (lower.contains('xray') || lower.contains('x-ray')) return Icons.image;
    if (lower.contains('mri') || lower.contains('scan')) return Icons.biotech;
    return Icons.science;
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status) {
      case 'requested':
      case 'pending':
        return _StatusConfig('Pending', Colors.orange, Icons.hourglass_empty);
      case 'in_progress':
      case 'processing':
        return _StatusConfig('In Progress', Colors.blue, Icons.autorenew);
      case 'completed':
      case 'uploaded':
        return _StatusConfig('Completed', Colors.green, Icons.check_circle);
      case 'cancelled':
        return _StatusConfig('Cancelled', Colors.red, Icons.cancel);
      default:
        return _StatusConfig('Unknown', Colors.grey, Icons.help_outline);
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }
}

// Helper classes
class _StatusConfig {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusConfig(this.label, this.color, this.icon);
}

class _ProfileField {
  final String label;
  final dynamic value;
  const _ProfileField(this.label, this.value);
}
