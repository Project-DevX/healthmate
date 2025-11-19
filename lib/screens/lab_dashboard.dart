import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/shared_models.dart';
import '../services/interconnect_service.dart';
import '../theme/app_theme.dart';
import 'chat_page.dart';

final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _statusLabel(String status) => status.replaceAll('_', ' ').toUpperCase();

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'requested':
      return AppTheme.warningOrange;
    case 'in_progress':
      return AppTheme.infoBlue;
    case 'completed':
    case 'uploaded':
      return AppTheme.successGreen;
    default:
      return AppTheme.textMedium;
  }
}

Color _notificationColor(String type) {
  switch (type.toLowerCase()) {
    case 'warning':
    case 'alert':
      return AppTheme.warningOrange;
    case 'success':
    case 'lab_result':
      return AppTheme.successGreen;
    case 'appointment':
    case 'info':
      return AppTheme.infoBlue;
    default:
      return AppTheme.labColor;
  }
}

class LabDashboard extends StatefulWidget {
  const LabDashboard({Key? key}) : super(key: key);

  @override
  State<LabDashboard> createState() => _LabDashboardState();
}

class _LabDashboardState extends State<LabDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isRefreshing = false;
  int _selectedIndex = 0;

  Map<String, dynamic>? _labData;
  List<LabReport> _labReports = [];
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<QuerySnapshot>? _labReportsSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupLabReportsStream();
  }

  @override
  void dispose() {
    _labReportsSubscription?.cancel();
    super.dispose();
  }

  void _setupLabReportsStream() {
    final user = _auth.currentUser;
    if (user == null) return;

    print(
      '🔍 LAB DASHBOARD: Setting up real-time stream for labId: ${user.uid}',
    );

    // Create real-time stream for lab reports
    _labReportsSubscription = _firestore
        .collection('lab_reports')
        .where('labId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            print(
              '🔄 LAB DASHBOARD: Stream update - ${snapshot.docs.length} documents',
            );

            final labReports = <LabReport>[];
            for (final doc in snapshot.docs) {
              try {
                // Log key fields for debugging
                final rawData = doc.data() as Map<String, dynamic>;
                final reportLabId = rawData['labId']?.toString() ?? 'NULL';
                final reportStatus = rawData['status']?.toString() ?? 'NULL';
                final reportTestName =
                    rawData['testName']?.toString() ?? 'NULL';
                print(
                  '📋 LAB DASHBOARD: Stream - Report ${doc.id}: labId=$reportLabId, status=$reportStatus, testName=$reportTestName',
                );

                labReports.add(LabReport.fromFirestore(doc));
              } catch (e, stackTrace) {
                print('⚠️ LAB DASHBOARD: Error parsing report ${doc.id}: $e');
                print('⚠️ LAB DASHBOARD: Stack trace: $stackTrace');
              }
            }

            // Sort by creation date (newest first)
            labReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (mounted) {
              setState(() {
                _labReports = labReports;
              });

              print(
                '✅ LAB DASHBOARD: Stream update complete - ${labReports.length} reports loaded',
              );

              // Log breakdown
              final requestedCount = labReports
                  .where((r) => r.status.toLowerCase() == 'requested')
                  .length;
              final inProgressCount = labReports
                  .where((r) => r.status.toLowerCase() == 'in_progress')
                  .length;
              final completedCount = labReports
                  .where(
                    (r) =>
                        r.status.toLowerCase() == 'completed' ||
                        r.status.toLowerCase() == 'uploaded',
                  )
                  .length;
              print(
                '📊 LAB DASHBOARD: Stream - Requested: $requestedCount, In Progress: $inProgressCount, Completed: $completedCount',
              );
            }
          },
          onError: (error) {
            print('❌ LAB DASHBOARD: Stream error: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error loading lab reports: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
  }

  Future<void> _loadDashboardData({bool showLoader = true}) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    if (showLoader) {
      if (!mounted) return;
      setState(() => _isLoading = true);
    } else {
      if (!mounted) return;
      setState(() => _isRefreshing = true);
    }

    try {
      print('🔍 LAB DASHBOARD: Loading data for user: ${user.uid}');

      // Load lab user data
      final labDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!labDoc.exists) {
        throw Exception('Lab user document not found');
      }

      final labData = labDoc.data();
      if (labData == null) {
        throw Exception('Lab user data is null');
      }

      // Verify user type
      final userType = labData['userType'];
      if (userType != 'lab') {
        print('⚠️ LAB DASHBOARD: User type is "$userType", expected "lab"');
      }

      labData['uid'] = user.uid;
      print(
        '✅ LAB DASHBOARD: Lab user data loaded: ${labData['institutionName'] ?? labData['name'] ?? 'Unknown'}',
      );

      // Lab reports are now loaded via real-time stream in _setupLabReportsStream()
      // No need to fetch them here - the stream will update automatically
      print(
        '🔍 LAB DASHBOARD: Lab reports will be loaded via real-time stream',
      );
      print('🔍 LAB DASHBOARD: Lab user email: ${labData['email'] ?? 'N/A'}');
      print(
        '🔍 LAB DASHBOARD: Lab user name: ${labData['institutionName'] ?? labData['name'] ?? 'N/A'}',
      );

      // Load notifications
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: user.uid)
          .get();

      final notifications = notificationsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      notifications.sort((a, b) {
        DateTime dateA;
        DateTime dateB;

        final rawA = a['createdAt'];
        final rawB = b['createdAt'];

        if (rawA is Timestamp) {
          dateA = rawA.toDate();
        } else if (rawA is DateTime) {
          dateA = rawA;
        } else {
          dateA = DateTime.fromMillisecondsSinceEpoch(0);
        }

        if (rawB is Timestamp) {
          dateB = rawB.toDate();
        } else if (rawB is DateTime) {
          dateB = rawB;
        } else {
          dateB = DateTime.fromMillisecondsSinceEpoch(0);
        }

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;
      setState(() {
        _labData = labData;
        // _labReports is updated by the stream, don't overwrite it here
        _notifications = notifications;
        _isLoading = false;
        _isRefreshing = false;
      });

      print('✅ LAB DASHBOARD: Dashboard data loaded successfully');
    } catch (e, stackTrace) {
      print('❌ LAB DASHBOARD: Error loading dashboard: $e');
      print('❌ LAB DASHBOARD: Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      // Show more detailed error message
      final errorMessage = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load lab dashboard: $errorMessage'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleUpdateStatus(LabReport report, String newStatus) async {
    try {
      if (!mounted) return;
      setState(() => _isRefreshing = true);
      // Use InterconnectService to update status with notifications
      await InterconnectService.updateLabReportStatus(report.id, newStatus);
      // No need to reload data - the stream will update automatically
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report marked as ${_statusLabel(newStatus)}. Doctor and patient have been notified.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  Future<void> _handleUploadResult(LabReport report) async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      if (!mounted) return;
      setState(() => _isRefreshing = true);

      final file = File(pickedFile.path);
      final storageRef = FirebaseStorage.instance.ref().child(
        'lab_reports/${report.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await InterconnectService.uploadLabResult(
        report.id,
        downloadUrl,
        null,
        notes: 'Uploaded via lab dashboard',
      );

      // No need to reload data - the stream will update automatically
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lab result uploaded successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload result: $e')));
    }
  }

  void _showReportDetails(LabReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final statusColor = _statusColor(report.status);

        Widget detailRow(String label, String value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(value, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.15),
                      child: Icon(Icons.science, color: statusColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.testName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _statusLabel(report.status),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                detailRow('Patient', report.patientName),
                detailRow(
                  'Requested By',
                  report.doctorName != null && report.doctorName!.isNotEmpty
                      ? 'Dr. ${report.doctorName}'
                      : '—',
                ),
                detailRow('Test Type', report.testType),
                detailRow('Test Date', _dateFormat.format(report.testDate)),
                if (report.results != null && report.results!.isNotEmpty)
                  detailRow(
                    'Results',
                    report.results!.entries
                        .map((entry) {
                          final value = entry.value;
                          return '${entry.key}: $value';
                        })
                        .join('\n'),
                  ),
                if (report.notes != null && report.notes!.isNotEmpty)
                  detailRow('Notes', report.notes!),
                if (report.reportUrl != null && report.reportUrl!.isNotEmpty)
                  detailRow('Report URL', report.reportUrl!),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility),
                      label: const Text('View Details'),
                      onPressed: () {},
                    ),
                    if (report.status == 'requested')
                      FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Processing'),
                        onPressed: () {
                          Navigator.pop(context);
                          _handleUpdateStatus(report, 'in_progress');
                        },
                      ),
                    if (report.status == 'in_progress')
                      FilledButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark Completed'),
                        onPressed: () {
                          Navigator.pop(context);
                          _handleUpdateStatus(report, 'completed');
                        },
                      ),
                    if (report.status == 'requested' ||
                        report.status == 'in_progress')
                      FilledButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Result'),
                        onPressed: () {
                          Navigator.pop(context);
                          _handleUploadResult(report);
                        },
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

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lab Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_notifications.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No notifications yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 360,
                    child: ListView.separated(
                      itemCount: _notifications.length,
                      separatorBuilder: (context, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _buildNotificationTile(_notifications[index]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notification) {
    final title = notification['title'] as String? ?? 'Notification';
    final message = notification['message'] as String? ?? '';
    final type = notification['type'] as String? ?? 'info';
    final color = _notificationColor(type);

    DateTime? createdAt;
    final raw = notification['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else if (raw is DateTime) {
      createdAt = raw;
    }

    final timeLabel = createdAt != null
        ? DateFormat('MMM d, h:mm a').format(createdAt)
        : '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(Icons.notifications, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isNotEmpty) Text(message),
          if (timeLabel.isNotEmpty)
            Text(
              timeLabel,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
        ],
      ),
    );
  }

  String get _labDisplayName =>
      _labData?['institutionName'] ?? _labData?['name'] ?? 'Lab Team';

  List<LabReport> get _requestedReports {
    final requested = _labReports
        .where((report) => report.status.toLowerCase() == 'requested')
        .toList();

    // Debug: Log if we have reports but none are requested
    if (_labReports.isNotEmpty && requested.isEmpty) {
      print(
        '⚠️ LAB DASHBOARD: Have ${_labReports.length} reports but none are "requested"',
      );
      print(
        '⚠️ LAB DASHBOARD: Report statuses: ${_labReports.map((r) => r.status).toList()}',
      );
    }

    return requested;
  }

  List<LabReport> get _inProgressReports => _labReports
      .where((report) => report.status.toLowerCase() == 'in_progress')
      .toList();

  List<LabReport> get _completedReports => _labReports
      .where(
        (report) =>
            report.status.toLowerCase() == 'completed' ||
            report.status.toLowerCase() == 'uploaded',
      )
      .toList();

  List<LabReport> get _todayReports => _labReports
      .where((report) => _isSameDay(report.testDate, DateTime.now()))
      .toList();

  void _navigateToRequests() {
    setState(() => _selectedIndex = 1);
  }

  void _openChat() {
    setState(() => _selectedIndex = 2);
  }

  void _uploadNextPending() {
    LabReport? target;
    if (_inProgressReports.isNotEmpty) {
      target = _inProgressReports.first;
    } else if (_requestedReports.isNotEmpty) {
      target = _requestedReports.first;
    }

    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending reports to upload')),
      );
      return;
    }

    _handleUploadResult(target);
  }

  List<Widget> get _pages => [
    LabDashboardContent(
      labName: _labDisplayName,
      onRefresh: () => _loadDashboardData(showLoader: false),
      allReports: _labReports,
      requestedReports: _requestedReports,
      inProgressReports: _inProgressReports,
      completedReports: _completedReports,
      todayReports: _todayReports,
      notifications: _notifications,
      onShowReport: _showReportDetails,
      onViewRequests: _navigateToRequests,
      onOpenChat: _openChat,
      onUploadPending: _uploadNextPending,
      isRefreshing: _isRefreshing,
    ),
    LabRequestsView(
      reports: _labReports,
      onRefresh: () => _loadDashboardData(showLoader: false),
      onUpdateStatus: _handleUpdateStatus,
      onUploadResult: _handleUploadResult,
      onShowReport: _showReportDetails,
    ),
    const ChatPage(),
    LabProfilePage(
      onProfileUpdated: () => _loadDashboardData(showLoader: false),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppWidgets.buildAppBar(
        title: 'HealthMate - Lab',
        userType: 'lab',
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _showNotificationsSheet,
              ),
              if (_notifications.isNotEmpty)
                Positioned(
                  right: 10,
                  top: 12,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppTheme.warningOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing
                ? null
                : () => _loadDashboardData(showLoader: false),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.labColor,
        unselectedItemColor: AppTheme.textMedium,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class LabDashboardContent extends StatelessWidget {
  const LabDashboardContent({
    super.key,
    required this.labName,
    required this.onRefresh,
    required this.allReports,
    required this.requestedReports,
    required this.inProgressReports,
    required this.completedReports,
    required this.todayReports,
    required this.notifications,
    required this.onShowReport,
    required this.onViewRequests,
    required this.onOpenChat,
    required this.onUploadPending,
    required this.isRefreshing,
  });

  final String labName;
  final Future<void> Function() onRefresh;
  final List<LabReport> allReports;
  final List<LabReport> requestedReports;
  final List<LabReport> inProgressReports;
  final List<LabReport> completedReports;
  final List<LabReport> todayReports;
  final List<Map<String, dynamic>> notifications;
  final ValueChanged<LabReport> onShowReport;
  final VoidCallback onViewRequests;
  final VoidCallback onOpenChat;
  final VoidCallback onUploadPending;
  final bool isRefreshing;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.labColor;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildWelcomeCard(accent),
          const SizedBox(height: 16),
          _buildStatsSection(context),
          const SizedBox(height: 24),
          _buildQuickActions(context),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            title: 'Incoming Requests',
            icon: Icons.pending_actions,
            action: requestedReports.isNotEmpty ? 'View all' : null,
            onActionTap: requestedReports.isNotEmpty ? onViewRequests : null,
          ),
          if (requestedReports.isEmpty)
            _buildEmptyState(
              icon: Icons.inbox_outlined,
              message: 'No pending requests right now.',
            )
          else
            ...requestedReports
                .take(3)
                .map((report) => _buildReportCard(report))
                .toList(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            title: 'In Progress',
            icon: Icons.timelapse,
          ),
          if (inProgressReports.isEmpty)
            _buildEmptyState(
              icon: Icons.hourglass_empty,
              message: 'No tests are currently in progress.',
            )
          else
            ...inProgressReports
                .take(3)
                .map((report) => _buildReportCard(report))
                .toList(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            title: 'Completed Recently',
            icon: Icons.check_circle,
          ),
          if (completedReports.isEmpty)
            _buildEmptyState(
              icon: Icons.auto_graph,
              message: 'Completed tests will appear here.',
            )
          else
            ...completedReports
                .take(3)
                .map((report) => _buildReportCard(report))
                .toList(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            title: 'Recent Activity',
            icon: Icons.notifications,
            action: notifications.isNotEmpty ? 'View all' : null,
            onActionTap: notifications.isNotEmpty ? onViewRequests : null,
          ),
          if (notifications.isEmpty)
            _buildEmptyState(
              icon: Icons.notifications_none,
              message: 'No recent activity to show.',
            )
          else
            ...notifications.take(4).map(_buildNotificationCard).toList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(Color accent) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: accent.withOpacity(0.15),
              child: Icon(Icons.science, color: accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting()},',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    labName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Here\'s a quick view of today\'s workloads.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final stats = [
      _DashboardStat(
        label: 'Total Reports',
        value: allReports.length.toString(),
        icon: Icons.analytics,
        color: AppTheme.labColor,
      ),
      _DashboardStat(
        label: 'Pending',
        value: requestedReports.length.toString(),
        icon: Icons.pending_actions,
        color: AppTheme.warningOrange,
      ),
      _DashboardStat(
        label: 'In Progress',
        value: inProgressReports.length.toString(),
        icon: Icons.timelapse,
        color: AppTheme.infoBlue,
      ),
      _DashboardStat(
        label: 'Today\'s Tests',
        value: todayReports.length.toString(),
        icon: Icons.calendar_today,
        color: AppTheme.successGreen,
      ),
    ];

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: stats.map((stat) => stat.build()).toList(),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickAction(
                  icon: Icons.assignment,
                  label: 'Review Requests',
                  color: AppTheme.labColor,
                  onTap: onViewRequests,
                ),
                _QuickAction(
                  icon: Icons.upload_file,
                  label: 'Upload Results',
                  color: AppTheme.infoBlue,
                  onTap: onUploadPending,
                ),
                _QuickAction(
                  icon: Icons.today,
                  label: 'Today\'s Tests (${todayReports.length})',
                  color: AppTheme.warningOrange,
                  onTap: onViewRequests,
                ),
                _QuickAction(
                  icon: Icons.chat,
                  label: 'Open Chat',
                  color: AppTheme.accentPurple,
                  onTap: onOpenChat,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    String? action,
    VoidCallback? onActionTap,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.labColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (action != null && onActionTap != null)
          TextButton(onPressed: onActionTap, child: Text(action)),
      ],
    );
  }

  Widget _buildReportCard(LabReport report) {
    final statusColor = _statusColor(report.status);

    return Card(
      child: ListTile(
        onTap: () => onShowReport(report),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.15),
          child: Icon(Icons.description, color: statusColor),
        ),
        title: Text(
          report.patientName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.doctorName != null && report.doctorName!.isNotEmpty)
              Text('Requested by Dr. ${report.doctorName}'),
            Text('${report.testName} • ${_dateFormat.format(report.testDate)}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            _statusLabel(report.status),
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
          ),
          backgroundColor: statusColor.withOpacity(0.12),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final title = notification['title'] as String? ?? 'Notification';
    final message = notification['message'] as String? ?? '';
    final type = notification['type'] as String? ?? 'info';
    final color = _notificationColor(type);

    DateTime? createdAt;
    final raw = notification['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else if (raw is DateTime) {
      createdAt = raw;
    }

    final timeLabel = createdAt != null
        ? DateFormat('MMM d, h:mm a').format(createdAt)
        : '';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(Icons.notifications, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isNotEmpty) Text(message),
            if (timeLabel.isNotEmpty)
              Text(
                timeLabel,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _DashboardStat {
  const _DashboardStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  Widget build() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LabRequestsView extends StatefulWidget {
  const LabRequestsView({
    super.key,
    required this.reports,
    required this.onRefresh,
    required this.onUpdateStatus,
    required this.onUploadResult,
    required this.onShowReport,
  });

  final List<LabReport> reports;
  final Future<void> Function() onRefresh;
  final Future<void> Function(LabReport, String) onUpdateStatus;
  final Future<void> Function(LabReport) onUploadResult;
  final ValueChanged<LabReport> onShowReport;

  @override
  State<LabRequestsView> createState() => _LabRequestsViewState();
}

class _LabRequestsViewState extends State<LabRequestsView>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final requested = widget.reports
        .where((report) => report.status.toLowerCase() == 'requested')
        .toList();
    final inProgress = widget.reports
        .where((report) => report.status.toLowerCase() == 'in_progress')
        .toList();
    final completed = widget.reports
        .where(
          (report) =>
              report.status.toLowerCase() == 'completed' ||
              report.status.toLowerCase() == 'uploaded',
        )
        .toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              labelColor: AppTheme.labColor,
              unselectedLabelColor: AppTheme.textMedium,
              tabs: [
                Tab(text: 'Requested (${requested.length})'),
                Tab(text: 'In Progress (${inProgress.length})'),
                Tab(text: 'Completed (${completed.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildReportList(requested, 'requested'),
                _buildReportList(inProgress, 'in_progress'),
                _buildReportList(completed, 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportList(List<LabReport> reports, String filter) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppTheme.labColor,
      child: reports.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.medical_information,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        filter == 'requested'
                            ? 'No pending lab requests.'
                            : filter == 'in_progress'
                            ? 'No tests in progress.'
                            : 'No completed reports yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = reports[index];
                final statusColor = _statusColor(report.status);

                return Card(
                  elevation: 1,
                  child: ListTile(
                    onTap: () => widget.onShowReport(report),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.15),
                      child: Icon(Icons.science, color: statusColor),
                    ),
                    title: Text(
                      report.patientName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${report.testName} • ${_dateFormat.format(report.testDate)}',
                        ),
                        if (report.doctorName != null &&
                            report.doctorName!.isNotEmpty)
                          Text('Doctor: Dr. ${report.doctorName}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => _handleAction(value, report),
                      itemBuilder: (context) {
                        final actions = <PopupMenuEntry<String>>[];
                        if (report.status == 'requested') {
                          actions.add(
                            const PopupMenuItem(
                              value: 'start',
                              child: ListTile(
                                leading: Icon(Icons.play_arrow),
                                title: Text('Start Processing'),
                              ),
                            ),
                          );
                        }
                        if (report.status == 'in_progress') {
                          actions.addAll([
                            const PopupMenuItem(
                              value: 'complete',
                              child: ListTile(
                                leading: Icon(Icons.check_circle),
                                title: Text('Mark Completed'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'upload',
                              child: ListTile(
                                leading: Icon(Icons.upload_file),
                                title: Text('Upload Result'),
                              ),
                            ),
                          ]);
                        }
                        actions.add(
                          const PopupMenuItem(
                            value: 'view',
                            child: ListTile(
                              leading: Icon(Icons.visibility),
                              title: Text('View Details'),
                            ),
                          ),
                        );
                        return actions;
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _handleAction(String value, LabReport report) {
    switch (value) {
      case 'start':
        widget.onUpdateStatus(report, 'in_progress');
        break;
      case 'complete':
        widget.onUpdateStatus(report, 'completed');
        break;
      case 'upload':
        widget.onUploadResult(report);
        break;
      case 'view':
        widget.onShowReport(report);
        break;
    }
  }
}

class LabProfilePage extends StatefulWidget {
  const LabProfilePage({super.key, this.onProfileUpdated});

  final VoidCallback? onProfileUpdated;

  @override
  State<LabProfilePage> createState() => _LabProfilePageState();
}

class _LabProfilePageState extends State<LabProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _labData;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadLabData();
  }

  Future<void> _loadLabData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) return;
      setState(() {
        _labData = snapshot.data();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance.ref().child(
        'lab_profile_photos/${user.uid}.jpg',
      );

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).update({
        'photoURL': url,
      });

      await _loadLabData();
      widget.onProfileUpdated?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isUploading = false);
    }
  }

  void _showEditProfileDialog() {
    final institutionController = TextEditingController(
      text: _labData?['institutionName'] ?? '',
    );
    final hotlineController = TextEditingController(
      text: _labData?['hotline'] ?? '',
    );
    final addressController = TextEditingController(
      text: _labData?['address'] ?? '',
    );
    final websiteController = TextEditingController(
      text: _labData?['website'] ?? '',
    );
    final repNameController = TextEditingController(
      text: _labData?['repName'] ?? '',
    );
    final repEmailController = TextEditingController(
      text: _labData?['repEmail'] ?? '',
    );
    final operatingHoursController = TextEditingController(
      text: _labData?['operatingHours'] ?? '',
    );
    final testTypesController = TextEditingController(
      text: _labData?['testTypes'] ?? '',
    );
    final turnaroundController = TextEditingController(
      text: _labData?['turnaroundTime'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Lab Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: institutionController,
                decoration: const InputDecoration(
                  labelText: 'Institution Name',
                ),
              ),
              TextField(
                controller: hotlineController,
                decoration: const InputDecoration(labelText: 'Hotline'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: websiteController,
                decoration: const InputDecoration(labelText: 'Website'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repNameController,
                decoration: const InputDecoration(
                  labelText: 'Representative Name',
                ),
              ),
              TextField(
                controller: repEmailController,
                decoration: const InputDecoration(
                  labelText: 'Representative Email',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: operatingHoursController,
                decoration: const InputDecoration(labelText: 'Operating Hours'),
              ),
              TextField(
                controller: testTypesController,
                decoration: const InputDecoration(
                  labelText: 'Test Types Offered',
                ),
              ),
              TextField(
                controller: turnaroundController,
                decoration: const InputDecoration(
                  labelText: 'Average Turnaround Time',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user == null) return;

              try {
                await _firestore.collection('users').doc(user.uid).update({
                  'institutionName': institutionController.text.trim(),
                  'hotline': hotlineController.text.trim(),
                  'address': addressController.text.trim(),
                  'website': websiteController.text.trim(),
                  'repName': repNameController.text.trim(),
                  'repEmail': repEmailController.text.trim(),
                  'operatingHours': operatingHoursController.text.trim(),
                  'testTypes': testTypesController.text.trim(),
                  'turnaroundTime': turnaroundController.text.trim(),
                });

                if (!mounted) return;
                Navigator.pop(context);
                await _loadLabData();
                widget.onProfileUpdated?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lab profile updated')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update profile: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_labData == null) {
      return const Center(child: Text('No lab profile data found.'));
    }

    final photoUrl = _labData?['photoURL'] as String?;
    final displayName = _labData?['institutionName'] ?? 'Lab';
    final officialEmail =
        _labData?['officialEmail'] ?? _labData?['email'] ?? 'Not set';

    return RefreshIndicator(
      onRefresh: _loadLabData,
      color: AppTheme.labColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  backgroundColor: AppTheme.labColor.withOpacity(0.15),
                  child: photoUrl == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'L',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.labColor,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.labColor,
                      padding: const EdgeInsets.all(8),
                    ),
                    onPressed: _isUploading ? null : _pickAndUploadPhoto,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  officialEmail,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _showEditProfileDialog,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Institution Details',
            items: [
              _InfoEntry('Institution Name', _labData?['institutionName']),
              _InfoEntry('License Number', _labData?['licenseNumber']),
              _InfoEntry('Hotline', _labData?['hotline']),
              _InfoEntry('Address', _labData?['address']),
              _InfoEntry('Website', _labData?['website']),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Authorized Representative',
            items: [
              _InfoEntry('Name', _labData?['repName']),
              _InfoEntry('Email', _labData?['repEmail']),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Operations',
            items: [
              _InfoEntry('Operating Hours', _labData?['operatingHours']),
              _InfoEntry('Test Types', _labData?['testTypes']),
              _InfoEntry('Avg Turnaround Time', _labData?['turnaroundTime']),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need Changes?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.labColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Update lab contact details to keep doctors and patients informed. '
                    'Accurate operating hours help doctors schedule tests seamlessly.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<_InfoEntry> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        (item.value as String?)?.isNotEmpty ?? false
                            ? item.value as String
                            : 'Not set',
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
}

class _InfoEntry {
  const _InfoEntry(this.label, this.value);

  final String label;
  final dynamic value;
}
