import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import '../models/shared_models.dart';
import '../services/interconnect_service.dart';
import '../theme/app_theme.dart';
import 'chat_page.dart';
import 'dart:io';

class LabDashboard extends StatefulWidget {
  const LabDashboard({Key? key}) : super(key: key);

  @override
  State<LabDashboard> createState() => _LabDashboardState();
}

class _LabDashboardState extends State<LabDashboard> {
  int _selectedBottomNav = 0;
  bool _isLoading = false;

  // Real-time data
  List<LabReport> _incomingRequests = [];
  List<LabReport> _myLabReports = [];
  Map<String, dynamic>? _userData;
  String? _labId;

  // Remove sample data lists
  List<Map<String, dynamic>> testResults = [];
  List<Map<String, dynamic>> labStaff = [];
  List<Map<String, dynamic>> labAppointments = [];

  // KPI calculations
  int get totalTests => testResults.length;
  int get pendingUploads => testResults
      .where((t) => (t['status'] ?? '').toLowerCase() == 'pending')
      .length;
  int get todaysAppointments => labAppointments.length;
  int get completedTests => testResults
      .where((t) => (t['status'] ?? '').toLowerCase() == 'completed')
      .length;
  int get urgentTests => testResults
      .where((t) => (t['priority'] ?? '').toLowerCase() == 'urgent')
      .length;

  final List<_LabDashboardFeature> _features = [
    _LabDashboardFeature('Report Upload', Icons.upload_file),
    _LabDashboardFeature('Report Management', Icons.folder),
    _LabDashboardFeature('Test Requests', Icons.assignment),
    _LabDashboardFeature('Patient Search', Icons.search),
    _LabDashboardFeature('Appointment Calendar', Icons.calendar_today),
    _LabDashboardFeature('Staff Assignment', Icons.people),
    _LabDashboardFeature('Notifications', Icons.notifications),
  ];

  void _onFeatureTap(String feature) {
    switch (feature) {
      case 'Report Upload':
        _showReportUpload();
        break;
      case 'Report Management':
        _showReportManagement();
        break;
      case 'Test Requests':
        _showTestRequests();
        break;
      case 'Patient Search':
        _showPatientSearch();
        break;
      case 'Appointment Calendar':
        _showAppointmentCalendar();
        break;
      case 'Staff Assignment':
        _showStaffAssignment();
        break;
      case 'Notifications':
        _showNotifications();
        break;
      default:
        _showFeatureModal(feature);
    }
  }

  void _showReportUpload() {
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
                  'Upload Test Results',
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
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Upload New Results',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Patient ID',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Test Type',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                border: OutlineInputBorder(),
                              ),
                              items: ['Normal', 'Urgent', 'Critical']
                                  .map(
                                    (priority) => DropdownMenuItem(
                                      value: priority,
                                      child: Text(priority),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {},
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Simulate file upload
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'File upload functionality would be implemented here',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Attach Report File'),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Results uploaded successfully!',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Upload Results'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Recent Uploads',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...testResults
                        .take(3)
                        .map(
                          (test) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.description),
                              title: Text(
                                '${test['id']} - ${test['testType']}',
                              ),
                              subtitle: Text('Patient: ${test['patientName']}'),
                              trailing: Chip(
                                label: Text(test['status']),
                                backgroundColor: _getStatusColor(
                                  test['status'],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeatureModal(String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Text(
                  '$title feature coming soon!',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: \\$e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showReportManagement() {
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
                  'Report Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Filter by Status',
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', 'Pending', 'In Progress', 'Completed']
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {},
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: testResults.length,
                itemBuilder: (context, index) {
                  final test = testResults[index];
                  return Card(
                    child: ExpansionTile(
                      leading: Icon(
                        _getTestIcon(test['testType']),
                        color: test['priority'] == 'Urgent'
                            ? Colors.red
                            : AppTheme.labColor,
                      ),
                      title: Text('${test['id']} - ${test['patientName']}'),
                      subtitle: Text('${test['testType']} | ${test['date']}'),
                      trailing: Chip(
                        label: Text(test['status']),
                        backgroundColor: _getStatusColor(test['status']),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Priority: ${test['priority']}'),
                              Text('Technician: ${test['technician']}'),
                              Text('Results: ${test['results']}'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.visibility),
                                    label: const Text('View'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.download),
                                    label: const Text('Download'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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

  void _showTestRequests() {
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
                  'Test Requests',
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
              child: ListView.builder(
                itemCount: testResults.length,
                itemBuilder: (context, index) {
                  final test = testResults[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: test['priority'] == 'Urgent'
                            ? Colors.red
                            : AppTheme.labColor,
                        child: Text(test['id'].substring(3)),
                      ),
                      title: Text(test['patientName']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Test: ${test['testType']}'),
                          Text('Priority: ${test['priority']}'),
                          Text('Date: ${test['date']}'),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Chip(
                            label: Text(test['status']),
                            backgroundColor: _getStatusColor(test['status']),
                          ),
                        ],
                      ),
                      onTap: () {
                        _showTestRequestDetails(test);
                      },
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

  void _showPatientSearch() {
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
                  'Patient Search',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by patient name, ID, or test type...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Search Results:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: testResults.length,
                itemBuilder: (context, index) {
                  final test = testResults[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(test['patientName']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${test['id']}'),
                          Text('Test: ${test['testType']}'),
                          Text('Date: ${test['date']}'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () {
                          _showPatientDetails(test);
                        },
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

  void _showAppointmentCalendar() {
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
                  'Lab Appointments',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Today\'s Appointments',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('New Appointment'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: labAppointments.length,
                itemBuilder: (context, index) {
                  final appointment = labAppointments[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getAppointmentStatusColor(
                          appointment['status'],
                        ),
                        child: Text(appointment['time'].substring(0, 2)),
                      ),
                      title: Text(appointment['patientName']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Test: ${appointment['testType']}'),
                          Text('Time: ${appointment['time']}'),
                          if (appointment['fasting'])
                            const Text(
                              '⚠️ Fasting Required',
                              style: TextStyle(color: Colors.orange),
                            ),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(appointment['status']),
                        backgroundColor: _getAppointmentStatusColor(
                          appointment['status'],
                        ),
                      ),
                      onTap: () {
                        _showAppointmentDetails(appointment);
                      },
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

  void _showStaffAssignment() {
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
                  'Lab Staff Assignment',
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
              child: ListView.builder(
                itemCount: labStaff.length,
                itemBuilder: (context, index) {
                  final staff = labStaff[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: staff['status'] == 'Active'
                            ? Colors.green
                            : Colors.orange,
                        child: Text(staff['name'].substring(0, 1)),
                      ),
                      title: Text(staff['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Role: ${staff['role']}'),
                          Text('Department: ${staff['department']}'),
                          Text('Shift: ${staff['shift']}'),
                          Text('Experience: ${staff['experience']}'),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(staff['status']),
                        backgroundColor: staff['status'] == 'Active'
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                      ),
                      onTap: () {
                        _showStaffDetails(staff);
                      },
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

  void _showNotifications() {
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
                  'Lab Notifications',
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
              child: ListView(
                children: [
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.red,
                        child: Icon(Icons.priority_high, color: Colors.white),
                      ),
                      title: const Text('Urgent Test Request'),
                      subtitle: const Text(
                        'Cardiac markers needed for ICU patient',
                      ),
                      trailing: const Text('5 min ago'),
                      onTap: () {},
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.labColor,
                        child: Icon(Icons.assignment, color: Colors.white),
                      ),
                      title: const Text('New Test Assignment'),
                      subtitle: const Text(
                        'Blood work assigned to Tech. Sarah Wilson',
                      ),
                      trailing: const Text('15 min ago'),
                      onTap: () {},
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.check_circle, color: Colors.white),
                      ),
                      title: const Text('Results Uploaded'),
                      subtitle: const Text(
                        'LAB001 results uploaded successfully',
                      ),
                      trailing: const Text('30 min ago'),
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for lab dashboard
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.withOpacity(0.3);
      case 'In Progress':
        return AppTheme.labColor.withOpacity(0.3);
      case 'Completed':
        return Colors.green.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  Color _getAppointmentStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return AppTheme.labColor.withOpacity(0.3);
      case 'Checked In':
        return Colors.orange.withOpacity(0.3);
      case 'Completed':
        return Colors.green.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  IconData _getTestIcon(String testType) {
    if (testType.toLowerCase().contains('blood')) {
      return Icons.water_drop;
    } else if (testType.toLowerCase().contains('cardiac')) {
      return Icons.favorite;
    } else if (testType.toLowerCase().contains('liver')) {
      return Icons.health_and_safety;
    } else {
      return Icons.science;
    }
  }

  void _showTestRequestDetails(Map<String, dynamic> test) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Test Request ${test['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${test['patientName']}'),
            Text('Test Type: ${test['testType']}'),
            Text('Priority: ${test['priority']}'),
            Text('Status: ${test['status']}'),
            Text('Technician: ${test['technician']}'),
            Text('Date: ${test['date']}'),
            Text('Results: ${test['results']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (test['status'] == 'Pending')
            ElevatedButton(
              onPressed: () {
                setState(() {
                  test['status'] = 'In Progress';
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${test['id']} started processing')),
                );
              },
              child: const Text('Start Processing'),
            ),
        ],
      ),
    );
  }

  void _showPatientDetails(Map<String, dynamic> test) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Patient: ${test['patientName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient ID: ${test['id']}'),
            Text('Test Type: ${test['testType']}'),
            Text('Date: ${test['date']}'),
            Text('Status: ${test['status']}'),
            Text('Results: ${test['results']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('View Full History'),
          ),
        ],
      ),
    );
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Appointment ${appointment['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${appointment['patientName']}'),
            Text('Test Type: ${appointment['testType']}'),
            Text('Time: ${appointment['time']}'),
            Text('Date: ${appointment['date']}'),
            Text('Status: ${appointment['status']}'),
            if (appointment['fasting'])
              const Text(
                '⚠️ Fasting Required',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (appointment['status'] == 'Scheduled')
            ElevatedButton(
              onPressed: () {
                setState(() {
                  appointment['status'] = 'Checked In';
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${appointment['patientName']} checked in'),
                  ),
                );
              },
              child: const Text('Check In'),
            ),
        ],
      ),
    );
  }

  void _showStaffDetails(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(staff['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${staff['id']}'),
            Text('Role: ${staff['role']}'),
            Text('Department: ${staff['department']}'),
            Text('Shift: ${staff['shift']}'),
            Text('Experience: ${staff['experience']}'),
            Text('Status: ${staff['status']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Assign Task'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLabDashboardData();
  }

  Future<void> _loadLabDashboardData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final uid = user.uid;
    try {
      // Fetch lab reports
      final reportsSnap = await FirebaseFirestore.instance
          .collection('lab_reports')
          .where('labId', isEqualTo: uid)
          .get();
      testResults = reportsSnap.docs.map((d) => d.data()).toList();

      // Fetch lab staff
      final staffSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'lab_staff')
          .where('labId', isEqualTo: uid)
          .get();
      labStaff = staffSnap.docs.map((d) => d.data()).toList();

      // Fetch lab appointments
      final apptSnap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('labId', isEqualTo: uid)
          .get();
      labAppointments = apptSnap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Error loading lab dashboard data: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadLabRequests() async {
    if (_labId == null) return;

    try {
      setState(() => _isLoading = true);

      // Get lab reports assigned to this lab
      final labReports = await InterconnectService.getUserLabReports(
        _labId!,
        'lab',
      );

      setState(() {
        _myLabReports = labReports;
        _incomingRequests = labReports
            .where((report) => report.status == 'requested')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load lab requests: $e')),
        );
      }
    }
  }

  Future<void> _updateLabReportStatus(String reportId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('lab_reports')
          .doc(reportId)
          .update({'status': status});

      await _loadLabRequests(); // Refresh data

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test status updated to $status'),
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

  Future<void> _uploadLabResult(LabReport report) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() => _isLoading = true);

        // Upload to Firebase Storage
        final file = File(pickedFile.path);
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('lab_reports')
            .child('${report.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(file);
        final downloadUrl = await storageRef.getDownloadURL();

        // Update lab report with results
        await InterconnectService.uploadLabResult(report.id, downloadUrl, {
          'uploaded_by': _userData?['name'] ?? 'Lab Staff',
        }, notes: 'Results uploaded by lab staff');

        await _loadLabRequests(); // Refresh data
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color mainBlue = AppTheme.labColor;
    final Color scaffoldBg = theme.scaffoldBackgroundColor;
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: mainBlue,
        foregroundColor: Colors.white,
        title: const Text('Lab Dashboard'),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive column count based on screen width
                  final screenWidth = constraints.maxWidth;
                  final crossAxisCount = screenWidth > 600 ? 3 : 2;

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Welcome Card - Compact version
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: mainBlue,
                                child: Icon(
                                  Icons.science,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, Lab Staff!',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Laboratory Department',
                                      style: TextStyle(
                                        fontSize: 14,
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
                      const SizedBox(height: 16),
                      // Statistics Cards - Responsive grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: crossAxisCount == 3 ? 1.1 : 1.3,
                        children: [
                          _buildStatCard(
                            'Total Tests',
                            '$totalTests',
                            Icons.assignment_turned_in,
                            Colors.green,
                          ),
                          _buildStatCard(
                            'Pending Uploads',
                            '$pendingUploads',
                            Icons.upload_file,
                            Colors.orange,
                          ),
                          _buildStatCard(
                            "Today's Appointments",
                            '$todaysAppointments',
                            Icons.calendar_today,
                            AppTheme.labColor,
                          ),
                          _buildStatCard(
                            'Completed',
                            '${totalTests - pendingUploads}',
                            Icons.check_circle,
                            Colors.teal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Quick Actions - Responsive grid
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: crossAxisCount == 3 ? 0.9 : 1.0,
                        ),
                        itemCount: _features.length,
                        itemBuilder: (context, index) {
                          final feature = _features[index];
                          return GestureDetector(
                            onTap: () => _onFeatureTap(feature.label),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(feature.icon, size: 28, color: mainBlue),
                                    const SizedBox(height: 6),
                                    Text(
                                      feature.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            )
          : _selectedBottomNav == 1
          ? const ChatPage()
          : const LabProfilePage(),
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

class _LabDashboardFeature {
  final String label;
  final IconData icon;
  const _LabDashboardFeature(this.label, this.icon);
}

class LabProfilePage extends StatefulWidget {
  const LabProfilePage({Key? key}) : super(key: key);

  @override
  State<LabProfilePage> createState() => _LabProfilePageState();
}

class _LabProfilePageState extends State<LabProfilePage> {
  Map<String, dynamic>? labData;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadLabData();
  }

  Future<void> _loadLabData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final uid = user.uid;
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (docSnap.exists) {
        labData = docSnap.data();
      }
    } catch (e) {
      print('Error loading lab profile: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoURL': url},
      );
      await _loadLabData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      }
    }
    if (mounted) setState(() => _isUploading = false);
  }

  void _showEditProfileDialog() {
    final _institutionNameController = TextEditingController(
      text: labData?['institutionName'] ?? '',
    );
    final _hotlineController = TextEditingController(
      text: labData?['hotline'] ?? '',
    );
    final _addressController = TextEditingController(
      text: labData?['address'] ?? '',
    );
    final _websiteController = TextEditingController(
      text: labData?['website'] ?? '',
    );
    final _repNameController = TextEditingController(
      text: labData?['repName'] ?? '',
    );
    final _repDesignationController = TextEditingController(
      text: labData?['repDesignation'] ?? '',
    );
    final _repContactController = TextEditingController(
      text: labData?['repContact'] ?? '',
    );
    final _repEmailController = TextEditingController(
      text: labData?['repEmail'] ?? '',
    );
    final _hoursController = TextEditingController(
      text: labData?['operatingHours'] ?? '',
    );
    final _testTypesController = TextEditingController(
      text: labData?['testTypes'] ?? '',
    );
    final _turnaroundController = TextEditingController(
      text: labData?['turnaroundTime'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Lab Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lab Details
              TextField(
                controller: _institutionNameController,
                decoration: const InputDecoration(
                  labelText: 'Institution Name',
                ),
              ),
              TextField(
                controller: _hotlineController,
                decoration: const InputDecoration(labelText: 'Hotline'),
              ),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: _websiteController,
                decoration: const InputDecoration(labelText: 'Website'),
              ),
              const SizedBox(height: 12),
              // Authorized Representative
              Text(
                'Authorized Representative',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _repNameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _repDesignationController,
                decoration: const InputDecoration(labelText: 'Designation'),
              ),
              TextField(
                controller: _repContactController,
                decoration: const InputDecoration(labelText: 'Contact'),
              ),
              TextField(
                controller: _repEmailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              // Other editable fields
              TextField(
                controller: _hoursController,
                decoration: const InputDecoration(labelText: 'Operating Hours'),
              ),
              TextField(
                controller: _testTypesController,
                decoration: const InputDecoration(
                  labelText: 'Test Types Offered',
                ),
              ),
              TextField(
                controller: _turnaroundController,
                decoration: const InputDecoration(
                  labelText: 'Report Turnaround Time',
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF7B61FF),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              elevation: 1,
            ),
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                final uid = user.uid;
                final updatedData = {
                  'institutionName': _institutionNameController.text.trim(),
                  'hotline': _hotlineController.text.trim(),
                  'address': _addressController.text.trim(),
                  'website': _websiteController.text.trim(),
                  'repName': _repNameController.text.trim(),
                  'repDesignation': _repDesignationController.text.trim(),
                  'repContact': _repContactController.text.trim(),
                  'repEmail': _repEmailController.text.trim(),
                  'operatingHours': _hoursController.text.trim(),
                  'testTypes': _testTypesController.text.trim(),
                  'turnaroundTime': _turnaroundController.text.trim(),
                };
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update(updatedData);
                await _loadLabData();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lab profile updated!')),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDarkMode = brightness == Brightness.dark;
    final Color mainBlue = const Color(0xFF7B61FF);
    final Color cardBg = isDarkMode
        ? const Color(0xFF232A34)
        : const Color(0xFFF5F9FF);
    final Color scaffoldBg = isDarkMode
        ? const Color(0xFF181C22)
        : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : mainBlue;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Profile'),
        backgroundColor: isDarkMode ? const Color(0xFF232A34) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: mainBlue),
        titleTextStyle: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: labData == null ? null : _showEditProfileDialog,
            tooltip: 'Edit Lab Details',
          ),
        ],
      ),
      backgroundColor: scaffoldBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : labData == null
          ? const Center(child: Text('No profile data found.'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadPhoto,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundImage: NetworkImage(
                            labData?['photoURL'] ??
                                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(labData?['institutionName'] ?? 'Lab')}&background=7B61FF&color=fff',
                          ),
                          child: _isUploading
                              ? const CircularProgressIndicator()
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: mainBlue,
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    labData?['institutionName'] ?? 'Lab Name',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    labData?['officialEmail'] ?? 'Email not set',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  color: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lab Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _profileRow(
                          'Institution Name',
                          labData?['institutionName'],
                        ),
                        _profileRow(
                          'License Number',
                          labData?['licenseNumber'],
                        ),
                        _profileRow('Hotline', labData?['hotline']),
                        _profileRow('Address', labData?['address']),
                        _profileRow('Website', labData?['website']),
                        const SizedBox(height: 16),
                        Text(
                          'Authorized Representative',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _profileRow('Name', labData?['repName']),
                        _profileRow('Designation', labData?['repDesignation']),
                        _profileRow('Contact', labData?['repContact']),
                        _profileRow('Email', labData?['repEmail']),
                        const SizedBox(height: 16),
                        Text(
                          'Operating Hours:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labData?['operatingHours'] ?? 'Not set',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Test Types Offered:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (labData?['testTypes'] as String? ?? 'Not set'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Report Turnaround Time:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labData?['turnaroundTime'] ?? 'Not set',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'User Management:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add/remove lab technicians (admin only) - Coming soon',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _profileRow(String label, dynamic value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        Text(
          value?.toString() ?? 'Not set',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
