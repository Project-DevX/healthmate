import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/pharmacy_service.dart';
import '../widgets/add_medicine_form.dart';
import '../widgets/edit_medicine_form.dart';
import '../widgets/restock_medicine_dialog.dart';

class PharmacyDashboardNew extends StatefulWidget {
  const PharmacyDashboardNew({Key? key}) : super(key: key);

  @override
  State<PharmacyDashboardNew> createState() => _PharmacyDashboardNewState();
}

class _PharmacyDashboardNewState extends State<PharmacyDashboardNew> {
  final PharmacyService _pharmacyService = PharmacyService();
  int _selectedBottomNav = 0;

  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Dashboard'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => _showNotifications(context),
          ),
          IconButton(
            icon: const Icon(Icons.data_usage),
            onPressed: () => _initializeSampleData(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomNav,
        onTap: (index) => setState(() => _selectedBottomNav = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Prescriptions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Orders'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedBottomNav) {
      case 0:
        return _buildPrescriptionsPage();
      case 1:
        return _buildInventoryPage();
      case 2:
        return _buildOrdersPage();
      case 3:
        return _buildAnalyticsPage();
      case 4:
        return _buildProfilePage();
      default:
        return _buildPrescriptionsPage();
    }
  }

  Widget _buildPrescriptionsPage() {
    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search prescriptions...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  _buildFilterChip('Pending', 'pending'),
                  _buildFilterChip('Ready', 'ready'),
                  _buildFilterChip('Delivered', 'delivered'),
                ],
              ),
            ],
          ),
        ),
        // Prescriptions List
        Expanded(
          child: StreamBuilder<List<PharmacyPrescription>>(
            stream: _pharmacyService.getPrescriptionsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final prescriptions = snapshot.data ?? [];
              final filteredPrescriptions = _filterPrescriptions(prescriptions);

              if (filteredPrescriptions.isEmpty) {
                return const Center(child: Text('No prescriptions found'));
              }

              return ListView.builder(
                itemCount: filteredPrescriptions.length,
                itemBuilder: (context, index) {
                  final prescription = filteredPrescriptions[index];
                  return _buildPrescriptionCard(prescription);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionCard(PharmacyPrescription prescription) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${prescription.orderNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _buildStatusChip(prescription.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Patient: ${prescription.patientInfo.name}'),
            Text('Doctor: ${prescription.doctorInfo.name}'),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(prescription.prescriptionDate)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Medicines (${prescription.medicines.length}):',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            ...prescription.medicines.map(
              (medicine) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• ${medicine.name} (${medicine.dosage})'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: \$${prescription.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    if (prescription.status == 'pending')
                      ElevatedButton(
                        onPressed: () =>
                            _updatePrescriptionStatus(prescription.id, 'ready'),
                        child: const Text('Mark Ready'),
                      ),
                    if (prescription.status == 'ready')
                      ElevatedButton(
                        onPressed: () => _updatePrescriptionStatus(
                          prescription.id,
                          'delivered',
                        ),
                        child: const Text('Deliver'),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.receipt),
                      onPressed: () => _generateBill(prescription),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inventory Management',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: () => _showAddMedicineDialog(),
                child: const Text('Add Medicine'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _pharmacyService.getInventoryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(child: Text('No inventory items'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id; // Add document ID to the data
                    return _buildInventoryCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final lowStock = (item['quantity'] ?? 0) < (item['minStock'] ?? 10);

    return Card(
      color: lowStock ? Colors.red[50] : null,
      child: ListTile(
        leading: Icon(
          Icons.medication,
          color: lowStock ? Colors.red : Colors.blue,
        ),
        title: Text(item['name'] ?? 'Unknown Medicine'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quantity: ${item['quantity'] ?? 0}'),
            Text('Price: \$${(item['unitPrice'] ?? 0).toStringAsFixed(2)}'),
            Text('Category: ${item['category'] ?? 'N/A'}'),
            if (lowStock)
              const Text(
                'LOW STOCK!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'restock', child: Text('Restock')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          onSelected: (value) => _handleInventoryAction(value, item),
        ),
      ),
    );
  }

  Widget _buildOrdersPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Management',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where(
                    'pharmacyId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data?.docs ?? [];

                if (orders.isEmpty) {
                  return const Center(child: Text('No orders found'));
                }

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index].data() as Map<String, dynamic>;
                    return _buildOrderCard(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Card(
      child: ListTile(
        title: Text('Order #${order['orderNumber'] ?? 'N/A'}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order['customerName'] ?? 'Unknown'}'),
            Text('Amount: \$${(order['totalAmount'] ?? 0).toStringAsFixed(2)}'),
            Text('Status: ${order['status'] ?? 'Unknown'}'),
          ],
        ),
        trailing: _buildStatusChip(order['status'] ?? 'unknown'),
      ),
    );
  }

  Widget _buildAnalyticsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics Dashboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Daily Sales',
                  '\$1,234',
                  Icons.attach_money,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard('Orders', '45', Icons.shopping_cart),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Prescriptions',
                  '78',
                  Icons.medical_services,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard('Low Stock', '12', Icons.warning),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildActivityList(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList() {
    return Card(
      child: Column(
        children: [
          _buildActivityItem('New prescription received', '2 min ago'),
          _buildActivityItem('Order #1234 completed', '15 min ago'),
          _buildActivityItem('Low stock alert: Aspirin', '1 hour ago'),
          _buildActivityItem('Payment received: \$89.50', '2 hours ago'),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String activity, String time) {
    return ListTile(
      leading: const CircleAvatar(radius: 4, backgroundColor: Colors.blue),
      title: Text(activity),
      trailing: Text(
        time,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
    );
  }

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 16),
          const Text(
            'Pharmacy Name',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text('License: #PHM12345'),
          const SizedBox(height: 24),
          _buildProfileOption('Edit Profile', Icons.edit),
          _buildProfileOption('Business Hours', Icons.schedule),
          _buildProfileOption('Notifications', Icons.notifications),
          _buildProfileOption('Reports', Icons.analytics),
          _buildProfileOption('Settings', Icons.settings),
          _buildProfileOption('Help & Support', Icons.help),
          _buildProfileOption('Logout', Icons.logout),
        ],
      ),
    );
  }

  Widget _buildProfileOption(String title, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Handle profile option tap
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _selectedFilter == value,
        onSelected: (selected) {
          setState(() => _selectedFilter = selected ? value : 'all');
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'ready':
        color = Colors.blue;
        break;
      case 'delivered':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
    );
  }

  List<PharmacyPrescription> _filterPrescriptions(
    List<PharmacyPrescription> prescriptions,
  ) {
    var filtered = prescriptions;

    if (_selectedFilter != 'all') {
      filtered = filtered.where((p) => p.status == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (p) =>
                p.patientInfo.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                p.doctorInfo.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                p.orderNumber.toString().contains(_searchQuery),
          )
          .toList();
    }

    return filtered;
  }

  Future<void> _updatePrescriptionStatus(
    String prescriptionId,
    String newStatus,
  ) async {
    try {
      await _pharmacyService.updatePrescriptionStatus(
        prescriptionId,
        newStatus,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prescription status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
    }
  }

  Future<void> _generateBill(PharmacyPrescription prescription) async {
    try {
      final bill = await _pharmacyService.generateBill(prescription);
      _showBillDialog(bill);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating bill: $e')));
    }
  }

  void _showBillDialog(PharmacyBill bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bill #${bill.billNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${bill.patientName}'),
            Text('Date: ${DateFormat('MMM dd, yyyy').format(bill.billDate)}'),
            const Divider(),
            Text('Subtotal: \$${bill.subtotal.toStringAsFixed(2)}'),
            Text('Tax: \$${bill.tax.toStringAsFixed(2)}'),
            Text(
              'Total: \$${bill.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
              // Print or share bill
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }

  void _showAddMedicineDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddMedicineForm(
        onMedicineAdded: () {
          // Refresh inventory data
          setState(() {
            // This will trigger a rebuild and refresh the inventory stream
          });
        },
      ),
    );
  }

  void _handleInventoryAction(String action, Map<String, dynamic> item) {
    switch (action) {
      case 'edit':
        _showEditMedicineDialog(item);
        break;
      case 'restock':
        _showRestockMedicineDialog(item);
        break;
      case 'delete':
        _showDeleteConfirmationDialog(item);
        break;
    }
  }

  void _showEditMedicineDialog(Map<String, dynamic> medicine) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditMedicineForm(
        medicine: medicine,
        onMedicineUpdated: () {
          // Refresh inventory data
          setState(() {
            // This will trigger a rebuild and refresh the inventory stream
          });
        },
      ),
    );
  }

  void _showRestockMedicineDialog(Map<String, dynamic> medicine) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RestockMedicineDialog(
        medicine: medicine,
        onMedicineRestocked: () {
          // Refresh inventory data
          setState(() {
            // This will trigger a rebuild and refresh the inventory stream
          });
        },
      ),
    );
  }

  void _showDeleteConfirmationDialog(Map<String, dynamic> medicine) {
    final medicineName = medicine['name'] ?? 'Unknown Medicine';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text(
          'Are you sure you want to delete "$medicineName"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteMedicine(medicine),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMedicine(Map<String, dynamic> medicine) async {
    Navigator.pop(context); // Close confirmation dialog

    try {
      await _pharmacyService.deleteMedicine(medicine['id'] ?? '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Medicine "${medicine['name']}" deleted successfully!',
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        // Refresh inventory data
        setState(() {
          // This will trigger a rebuild and refresh the inventory stream
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting medicine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: const Text('No new notifications'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Settings page would go here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeSampleData() async {
    try {
      await _pharmacyService.initializeSampleData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample data initialized successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error initializing data: $e')));
    }
  }
}
