import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../models/shared_models.dart';
import '../services/interconnect_service.dart';
import '../services/pharmacy_service.dart';
import '../theme/app_theme.dart';
import 'chat_page.dart';

class PharmacyDashboardPage extends StatefulWidget {
  const PharmacyDashboardPage({Key? key}) : super(key: key);

  @override
  State<PharmacyDashboardPage> createState() => _PharmacyDashboardPageState();
}

class _PharmacyDashboardPageState extends State<PharmacyDashboardPage> {
  int _selectedBottomNav = 0;
  bool _isLoading = false;

  // Real-time data
  List<Prescription> _incomingPrescriptions = [];
  List<Prescription> _myPrescriptions = [];
  Map<String, dynamic>? _userData;
  String? _pharmacyId;

  // Remove sample data lists
  List<Map<String, dynamic>> prescriptions = [];
  List<Map<String, dynamic>> inventory = [];
  List<Map<String, dynamic>> notifications = [];

  // KPI calculations
  int get totalPrescriptions => prescriptions.length;
  int get fulfilledPrescriptions => prescriptions
      .where((p) => (p['status'] ?? '').toLowerCase() == 'fulfilled')
      .length;
  int get pendingPrescriptions => prescriptions
      .where((p) => (p['status'] ?? '').toLowerCase() == 'pending')
      .length;
  int get outOfStockAlerts =>
      inventory.where((i) => (i['stock'] ?? 0) <= (i['minStock'] ?? 0)).length;
  int get todaysPickups => prescriptions
      .where((p) => (p['status'] ?? '').toLowerCase() == 'ready')
      .length;

  final List<_PharmacyDashboardFeature> _features = [
    _PharmacyDashboardFeature('E-Prescriptions', Icons.receipt_long),
    _PharmacyDashboardFeature('Fulfillment Tracker', Icons.track_changes),
    _PharmacyDashboardFeature('Inventory', Icons.inventory),
    _PharmacyDashboardFeature('Search & Filter', Icons.search),
    _PharmacyDashboardFeature('Notifications', Icons.notifications),
    _PharmacyDashboardFeature('Messaging', Icons.chat),
    _PharmacyDashboardFeature('Reports', Icons.bar_chart),
    _PharmacyDashboardFeature('Profile & Settings', Icons.settings),
  ];

  void _onFeatureTap(String feature) {
    switch (feature) {
      case 'E-Prescriptions':
        _showEPrescriptions();
        break;
      case 'Fulfillment Tracker':
        _showFulfillmentTracker();
        break;
      case 'Inventory':
        _showInventoryManagement();
        break;
      case 'Search & Filter':
        _showSearchAndFilter();
        break;
      case 'Notifications':
        _showNotifications();
        break;
      case 'Messaging':
        _showMessaging();
        break;
      case 'Reports':
        _showReports();
        break;
      case 'Profile & Settings':
        _showProfileSettings();
        break;
      default:
        _showFeatureModal(feature);
    }
  }

  void _showEPrescriptions() {
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
                  'E-Prescriptions',
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
                itemCount: prescriptions.length,
                itemBuilder: (context, index) {
                  final prescription = prescriptions[index];
                  final isPriority = prescription['priority'] == 'High';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPriority
                            ? Colors.red
                            : AppTheme.pharmacyColor,
                        child: Text(prescription['id'].substring(2)),
                      ),
                      title: Text(prescription['patientName']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prescription['medication']),
                          Text('Qty: ${prescription['quantity']}'),
                          Text('Dr: ${prescription['doctor']}'),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(prescription['status']),
                        backgroundColor: _getStatusColor(
                          prescription['status'],
                        ),
                      ),
                      onTap: () => _showPrescriptionDetails(prescription),
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

  void _showFulfillmentTracker() {
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
                  'Fulfillment Tracker',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Status filter tabs
            Row(
              children: [
                Expanded(child: _buildStatusTab('All', prescriptions.length)),
                Expanded(
                  child: _buildStatusTab('Pending', pendingPrescriptions),
                ),
                Expanded(child: _buildStatusTab('Ready', todaysPickups)),
                Expanded(
                  child: _buildStatusTab('Fulfilled', fulfilledPrescriptions),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: prescriptions.length,
                itemBuilder: (context, index) {
                  final prescription = prescriptions[index];
                  return Card(
                    child: ExpansionTile(
                      title: Text(
                        '${prescription['id']} - ${prescription['patientName']}',
                      ),
                      subtitle: Text(prescription['medication']),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildTrackingStep('Prescription Received', true),
                              _buildTrackingStep(
                                'Verification Complete',
                                prescription['status'] != 'Pending',
                              ),
                              _buildTrackingStep(
                                'Medication Prepared',
                                prescription['status'] == 'Ready' ||
                                    prescription['status'] == 'Fulfilled',
                              ),
                              _buildTrackingStep(
                                'Ready for Pickup',
                                prescription['status'] == 'Ready' ||
                                    prescription['status'] == 'Fulfilled',
                              ),
                              _buildTrackingStep(
                                'Dispensed',
                                prescription['status'] == 'Fulfilled',
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

  void _showInventoryManagement() {
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
                  'Inventory Management',
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
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddMedicationDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Stock'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showLowStockReport(),
                    icon: const Icon(Icons.warning),
                    label: const Text('Low Stock'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: inventory.length,
                itemBuilder: (context, index) {
                  final item = inventory[index];
                  final isLowStock = item['stock'] <= item['minStock'];
                  return Card(
                    color: isLowStock ? Colors.red.withOpacity(0.1) : null,
                    child: ListTile(
                      leading: Icon(
                        Icons.medication,
                        color: isLowStock ? Colors.red : AppTheme.pharmacyColor,
                      ),
                      title: Text(item['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stock: ${item['stock']} | Min: ${item['minStock']}',
                          ),
                          Text('Category: ${item['category']}'),
                          Text('Expires: ${item['expiry']}'),
                        ],
                      ),
                      trailing: isLowStock
                          ? const Icon(Icons.warning, color: Colors.red)
                          : const Icon(Icons.check_circle, color: Colors.green),
                      onTap: () => _showMedicationDetails(item),
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
                  'Notifications',
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
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getNotificationColor(
                          notification['type'],
                        ),
                        child: Icon(
                          _getNotificationIcon(notification['type']),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        notification['title'],
                        style: TextStyle(
                          fontWeight: notification['read']
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification['message']),
                          Text(
                            notification['time'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: notification['read']
                          ? null
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.pharmacyColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                      onTap: () {
                        setState(() {
                          notifications[index]['read'] = true;
                        });
                        Navigator.pop(context);
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

  void _showSearchAndFilter() {
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
                  'Search & Filter',
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
                hintText: 'Search prescriptions, patients, medications...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', 'Pending', 'Ready', 'Fulfilled']
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
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', 'High', 'Normal', 'Low']
                        .map(
                          (priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(priority),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Search Results:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: prescriptions.length,
                itemBuilder: (context, index) {
                  final prescription = prescriptions[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${prescription['id']} - ${prescription['patientName']}',
                      ),
                      subtitle: Text(prescription['medication']),
                      trailing: Chip(
                        label: Text(prescription['status']),
                        backgroundColor: _getStatusColor(
                          prescription['status'],
                        ),
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

  void _showMessaging() {
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
                  'Messages',
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
                        child: Icon(Icons.local_hospital),
                      ),
                      title: const Text('Dr. Smith'),
                      subtitle: const Text('Patient inquiry about RX001'),
                      trailing: const Text('2 min ago'),
                      onTap: () {
                        // Open chat with doctor
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: const Text('Jane Wilson'),
                      subtitle: const Text(
                        'When will my prescription be ready?',
                      ),
                      trailing: const Text('15 min ago'),
                      onTap: () {
                        // Open chat with patient
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.business)),
                      title: const Text('Supplier - PharmaCorp'),
                      subtitle: const Text('Delivery scheduled for tomorrow'),
                      trailing: const Text('1 hour ago'),
                      onTap: () {
                        // Open chat with supplier
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Compose new message
                },
                icon: const Icon(Icons.add),
                label: const Text('New Message'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReports() {
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
                  'Reports & Analytics',
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
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildReportCard(
                    'Daily Sales',
                    '₹15,420',
                    Icons.monetization_on,
                    Colors.green,
                  ),
                  _buildReportCard(
                    'Monthly Revenue',
                    '₹4,25,650',
                    Icons.trending_up,
                    AppTheme.pharmacyColor,
                  ),
                  _buildReportCard(
                    'Top Medications',
                    '12 items',
                    Icons.star,
                    Colors.orange,
                  ),
                  _buildReportCard(
                    'Customer Satisfaction',
                    '4.8/5',
                    Icons.thumb_up,
                    Colors.purple,
                  ),
                  _buildReportCard(
                    'Inventory Turnover',
                    '8.5x',
                    Icons.repeat,
                    Colors.teal,
                  ),
                  _buildReportCard(
                    'Processing Time',
                    '2.3 hrs avg',
                    Icons.timer,
                    Colors.indigo,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Generate detailed report
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export PDF'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Email report
                      },
                      icon: const Icon(Icons.email),
                      label: const Text('Email Report'),
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

  void _showProfileSettings() {
    Navigator.pushNamed(context, '/profile');
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

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.withOpacity(0.3);
      case 'Ready':
        return AppTheme.pharmacyColor.withOpacity(0.3);
      case 'Fulfilled':
        return Colors.green.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'warning':
        return Colors.orange;
      case 'info':
        return AppTheme.pharmacyColor;
      case 'success':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      case 'success':
        return Icons.check_circle;
      case 'error':
        return Icons.error;
      default:
        return Icons.notifications;
    }
  }

  Widget _buildStatusTab(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTrackingStep(String label, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isCompleted ? Colors.green : Colors.grey,
              fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrescriptionDetails(Map<String, dynamic> prescription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Prescription ${prescription['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${prescription['patientName']}'),
            Text('Medication: ${prescription['medication']}'),
            Text('Quantity: ${prescription['quantity']}'),
            Text('Doctor: ${prescription['doctor']}'),
            Text('Status: ${prescription['status']}'),
            Text('Priority: ${prescription['priority']}'),
            Text('Date: ${prescription['date']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (prescription['status'] == 'Pending')
            ElevatedButton(
              onPressed: () {
                setState(() {
                  prescription['status'] = 'Ready';
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${prescription['id']} marked as ready'),
                  ),
                );
              },
              child: const Text('Mark Ready'),
            ),
        ],
      ),
    );
  }

  void _showMedicationDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Stock: ${item['stock']}'),
            Text('Minimum Stock: ${item['minStock']}'),
            Text('Category: ${item['category']}'),
            Text('Expiry Date: ${item['expiry']}'),
            Text('Supplier: ${item['supplier']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showAddStockDialog(item);
            },
            child: const Text('Add Stock'),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog(Map<String, dynamic> item) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Stock - ${item['name']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity to add',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(controller.text) ?? 0;
              if (quantity > 0) {
                setState(() {
                  item['stock'] += quantity;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added $quantity units to ${item['name']}'),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddMedicationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Medication'),
        content: const Text(
          'This feature allows adding new medications to inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showLowStockReport() {
    final lowStockItems = inventory
        .where((item) => item['stock'] <= item['minStock'])
        .toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Low Stock Report'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: lowStockItems.length,
            itemBuilder: (context, index) {
              final item = lowStockItems[index];
              return ListTile(
                title: Text(item['name']),
                subtitle: Text(
                  'Stock: ${item['stock']} (Min: ${item['minStock']})',
                ),
                trailing: const Icon(Icons.warning, color: Colors.red),
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
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _loadPharmacyDashboardData();
  }

  Future<void> _loadPharmacyDashboardData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final uid = user.uid;
    try {
      // Fetch prescriptions
      final prescSnap = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where('pharmacyId', isEqualTo: uid)
          .get();
      prescriptions = prescSnap.docs.map((d) => d.data()).toList();

      // Fetch inventory
      final invSnap = await FirebaseFirestore.instance
          .collection('inventory')
          .where('pharmacyId', isEqualTo: uid)
          .get();
      inventory = invSnap.docs.map((d) => d.data()).toList();

      // Fetch notifications
      final notifSnap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: uid)
          .get();
      notifications = notifSnap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Error loading pharmacy dashboard data: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadPrescriptions() async {
    if (_pharmacyId == null) return;

    try {
      setState(() => _isLoading = true);

      // Get prescriptions assigned to this pharmacy
      final prescriptions = await InterconnectService.getUserPrescriptions(
        _pharmacyId!,
        'pharmacy',
      );

      setState(() {
        _myPrescriptions = prescriptions;
        _incomingPrescriptions = prescriptions
            .where((prescription) => prescription.status == 'prescribed')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load prescriptions: $e')),
        );
      }
    }
  }

  Future<void> _updatePrescriptionStatus(
    String prescriptionId,
    String status,
  ) async {
    try {
      // Update pharmacy assignment if not already assigned
      if (status == 'filled') {
        await FirebaseFirestore.instance
            .collection('prescriptions')
            .doc(prescriptionId)
            .update({
              'pharmacyId': _pharmacyId,
              'pharmacyName': _userData?['name'] ?? 'Pharmacy',
            });
      }

      await InterconnectService.updatePrescriptionStatus(
        prescriptionId,
        status,
      );
      await _loadPrescriptions(); // Refresh data

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription status updated to $status'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update prescription: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color mainBlue = AppTheme.pharmacyColor;
    final Color scaffoldBg = theme.scaffoldBackgroundColor;
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final Color cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: mainBlue,
        foregroundColor: Colors.white,
        title: const Text('Pharmacy Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              // Toggle theme (this would require a theme provider)
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
                    color: cardColor,
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
                            child: const Icon(
                              Icons.local_pharmacy,
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
                                  'Welcome, Pharmacy Staff!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pharmacy Department',
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
                          'Total Prescriptions',
                          '$totalPrescriptions',
                          Icons.receipt_long,
                          AppTheme.pharmacyColor,
                          textColor,
                          cardColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Fulfilled',
                          '$fulfilledPrescriptions',
                          Icons.check_circle,
                          Colors.green,
                          textColor,
                          cardColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Pending',
                          '$pendingPrescriptions',
                          Icons.pending_actions,
                          Colors.orange,
                          textColor,
                          cardColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Out of Stock',
                          '$outOfStockAlerts',
                          Icons.warning,
                          Colors.red,
                          textColor,
                          cardColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "Today's Pickups",
                          '$todaysPickups',
                          Icons.local_shipping,
                          Colors.teal,
                          textColor,
                          cardColor,
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
                          color: cardColor,
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
          ? const ChatPage()
          : const PharmacyProfilePage(),
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
    Color textColor,
    Color cardColor,
  ) {
    return Card(
      elevation: 2,
      color: cardColor,
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
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PharmacyDashboardFeature {
  final String label;
  final IconData icon;
  const _PharmacyDashboardFeature(this.label, this.icon);
}

class PharmacyProfilePage extends StatefulWidget {
  const PharmacyProfilePage({Key? key}) : super(key: key);

  @override
  State<PharmacyProfilePage> createState() => _PharmacyProfilePageState();
}

class _PharmacyProfilePageState extends State<PharmacyProfilePage> {
  Map<String, dynamic>? pharmacyData;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _docExists = true;

  @override
  void initState() {
    super.initState();
    _loadPharmacyData();
  }

  Future<void> _loadPharmacyData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _docExists = false;
      });
      return;
    }
    final uid = user.uid;
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (docSnap.exists) {
        pharmacyData = docSnap.data();
        _docExists = true;
      } else {
        pharmacyData = null;
        _docExists = false;
      }
    } catch (e) {
      print('Error loading pharmacy profile: $e');
      pharmacyData = null;
      _docExists = false;
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
        'pharmacy_profile_photos/${user.uid}.jpg',
      );
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoURL': url},
      );
      await _loadPharmacyData();
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
      text: pharmacyData?['institutionName'] ?? '',
    );
    final _repDesignationController = TextEditingController(
      text: pharmacyData?['repDesignation'] ?? '',
    );
    final _repEmailController = TextEditingController(
      text: pharmacyData?['repEmail'] ?? '',
    );
    final _hotlineController = TextEditingController(
      text: pharmacyData?['hotline'] ?? '',
    );
    final _addressController = TextEditingController(
      text: pharmacyData?['address'] ?? '',
    );
    final _websiteController = TextEditingController(
      text: pharmacyData?['website'] ?? '',
    );
    final _repNameController = TextEditingController(
      text: pharmacyData?['repName'] ?? '',
    );
    final _repContactController = TextEditingController(
      text: pharmacyData?['repContact'] ?? '',
    );
    final _hoursController = TextEditingController(
      text: pharmacyData?['operatingHours'] ?? '',
    );
    final _servicesController = TextEditingController(
      text: pharmacyData?['services'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Pharmacy Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              TextField(
                controller: _hoursController,
                decoration: const InputDecoration(labelText: 'Operating Hours'),
              ),
              TextField(
                controller: _servicesController,
                decoration: const InputDecoration(
                  labelText: 'Services Offered',
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
                  'services': _servicesController.text.trim(),
                };
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update(updatedData);
                await _loadPharmacyData();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pharmacy profile updated!')),
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
        title: const Text('Pharmacy Profile'),
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
            onPressed: _docExists ? _showEditProfileDialog : null,
            tooltip: 'Edit Pharmacy Details',
          ),
        ],
      ),
      backgroundColor: scaffoldBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_docExists
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
                            pharmacyData?['photoURL'] ??
                                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(pharmacyData?['institutionName'] ?? 'Pharmacy')}&background=7B61FF&color=fff',
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
                    pharmacyData?['institutionName'] ?? 'Pharmacy Name',
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
                    pharmacyData?['officialEmail'] ?? 'Email not set',
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
                          'Pharmacy Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _profileRow(
                          'Institution Name',
                          pharmacyData?['institutionName'],
                        ),
                        _profileRow(
                          'License Number',
                          pharmacyData?['licenseNumber'],
                        ),
                        _profileRow('Hotline', pharmacyData?['hotline']),
                        _profileRow('Address', pharmacyData?['address']),
                        _profileRow('Website', pharmacyData?['website']),
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
                        _profileRow('Name', pharmacyData?['repName']),
                        _profileRow(
                          'Designation',
                          pharmacyData?['repDesignation'],
                        ),
                        _profileRow('Contact', pharmacyData?['repContact']),
                        _profileRow('Email', pharmacyData?['repEmail']),
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
                          pharmacyData?['operatingHours'] ?? 'Not set',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Services Offered:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (pharmacyData?['services'] as String? ?? 'Not set'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'User Management:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add/remove pharmacy staff (admin only) - Coming soon',
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
