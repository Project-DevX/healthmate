import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/pharmacy_service.dart';
import '../services/prescription_service.dart';
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
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Bills'),
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
        return _buildBillsPage();
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    _buildFilterChip('Pending', 'pending'),
                    _buildFilterChip('Processing', 'processing'),
                    _buildFilterChip('Ready', 'ready'),
                    _buildFilterChip('Delivered', 'delivered'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Prescriptions List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: PrescriptionService.getPrescriptionsForPharmacy(
              FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final allPrescriptions = snapshot.data ?? [];
              final filteredPrescriptions = _filterPrescriptionMaps(
                allPrescriptions,
              );

              if (filteredPrescriptions.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medical_services,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No prescriptions found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Prescriptions will appear here when doctors send them',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredPrescriptions.length,
                itemBuilder: (context, index) {
                  final prescription = filteredPrescriptions[index];
                  return _buildEnhancedPrescriptionCard(prescription);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedPrescriptionCard(Map<String, dynamic> prescription) {
    final status = prescription['status'] ?? 'pending';
    final medicines = prescription['medicines'] as List<dynamic>? ?? [];
    final prescriptionDate = prescription['prescriptionDate'] as Timestamp?;
    final orderNumber = prescription['orderNumber'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with order number and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${orderNumber.toString().padLeft(3, '0')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 12),

            // Patient and Doctor Info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '👤 ${prescription['patientName'] ?? 'Unknown Patient'}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '👨‍⚕️ Dr. ${prescription['doctorName'] ?? 'Unknown Doctor'}',
                      ),
                      if (prescriptionDate != null)
                        Text(
                          '📅 ${DateFormat('MMM dd, yyyy - hh:mm a').format(prescriptionDate.toDate())}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Medicines List
            const Text(
              'Prescribed Medicines:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...medicines.take(3).map((medicine) {
              return Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text(
                  '• ${medicine['name']} (${medicine['dosage']}) - Qty: ${medicine['quantity']}',
                ),
              );
            }),
            if (medicines.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  '... and ${medicines.length - 3} more medicines',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'pending')
                  ElevatedButton(
                    onPressed: () => _updatePrescriptionStatus(
                      prescription['id'],
                      'processing',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Start Processing'),
                  ),
                if (status == 'processing')
                  ElevatedButton(
                    onPressed: () =>
                        _updatePrescriptionStatus(prescription['id'], 'ready'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Mark Ready'),
                  ),
                if (status == 'ready')
                  ElevatedButton(
                    onPressed: () => _updatePrescriptionStatus(
                      prescription['id'],
                      'delivered',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Mark Delivered'),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () => _showPrescriptionDetails(prescription),
                ),
                IconButton(
                  icon: const Icon(Icons.receipt),
                  onPressed: () => _generateBillFromMap(prescription),
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

  Widget _buildBillsPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Management',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: _pharmacyService.getBillsStream(),
              builder: (context, snapshot) {
                // Show loading only on initial load
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error loading bills: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}), // Trigger rebuild
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final bills = snapshot.data ?? [];

                if (bills.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No bills found'),
                        SizedBox(height: 8),
                        Text(
                          'Bills will appear here when prescriptions are delivered.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: bills.length,
                  itemBuilder: (context, index) {
                    final bill = bills[index];
                    return _buildBillCard(bill);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(dynamic bill) {
    // Handle both PharmacyBill objects and Map representations
    String billNumber = '';
    String customerName = '';
    double totalAmount = 0.0;
    String doctorName = '';
    DateTime? timestamp;

    if (bill is Map<String, dynamic>) {
      billNumber = bill['billNumber'] ?? 'N/A';
      customerName = bill['patientName'] ?? 'Unknown';
      totalAmount = (bill['totalAmount'] ?? 0).toDouble();
      doctorName = bill['doctorName'] ?? 'Unknown';
      timestamp = bill['timestamp']?.toDate();
    } else {
      // Assuming it's a PharmacyBill object
      billNumber = bill.billNumber ?? 'N/A';
      customerName = bill.patientInfo?.name ?? 'Unknown';
      totalAmount = bill.totalAmount ?? 0.0;
      doctorName = bill.doctorInfo?.name ?? 'Unknown';
      timestamp = bill.timestamp;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('Bill #$billNumber'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: $customerName'),
            Text('Doctor: $doctorName'),
            Text('Amount: \$${totalAmount.toStringAsFixed(2)}'),
            if (timestamp != null)
              Text(
                'Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(timestamp)}',
              ),
          ],
        ),
        trailing: const Icon(Icons.receipt_long, color: Colors.green),
        onTap: () => _showBillDetails(bill),
      ),
    );
  }

  void _showBillDetails(dynamic bill) {
    print(
      '🔍 BILL DETAILS: Showing bill details for bill type: ${bill.runtimeType}',
    );

    String billNumber = '';
    String customerName = '';
    double totalAmount = 0.0;
    String doctorName = '';
    DateTime? timestamp;
    List<dynamic> medicines = [];

    if (bill is Map<String, dynamic>) {
      print('🔍 BILL DETAILS: Processing Map bill data');
      billNumber = bill['billNumber'] ?? 'N/A';
      customerName = bill['patientName'] ?? 'Unknown';
      totalAmount = (bill['totalAmount'] ?? 0).toDouble();
      doctorName = bill['doctorName'] ?? 'Unknown';
      timestamp = bill['timestamp']?.toDate();
      medicines = bill['medicines'] ?? [];
      print(
        '🔍 BILL DETAILS: Map medicines type: ${medicines.runtimeType}, length: ${medicines.length}',
      );
    } else {
      print('🔍 BILL DETAILS: Processing PharmacyBill object');
      billNumber = bill.billNumber ?? 'N/A';
      customerName = bill.patientInfo?.name ?? 'Unknown';
      totalAmount = bill.totalAmount ?? 0.0;
      doctorName = bill.doctorInfo?.name ?? 'Unknown';
      timestamp = bill.timestamp;
      medicines = bill.medicines ?? [];
      print(
        '🔍 BILL DETAILS: Object medicines type: ${medicines.runtimeType}, length: ${medicines.length}',
      );
    }

    // Debug each medicine
    for (int i = 0; i < medicines.length; i++) {
      final medicine = medicines[i];
      print('🔍 BILL DETAILS: Medicine $i type: ${medicine.runtimeType}');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bill Details - #$billNumber'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Patient: $customerName',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Doctor: $doctorName'),
              if (timestamp != null)
                Text(
                  'Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(timestamp)}',
                ),
              const SizedBox(height: 16),
              const Text(
                'Medicines:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...medicines.map((medicine) {
                String medicineName = 'Unknown';
                int medicineQuantity = 0;

                if (medicine is Map<String, dynamic>) {
                  medicineName = medicine['name'] ?? 'Unknown';
                  medicineQuantity = medicine['quantity'] ?? 0;
                } else if (medicine is Medicine) {
                  medicineName = medicine.name;
                  medicineQuantity = medicine.quantity;
                }

                return Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• $medicineName - Qty: $medicineQuantity'),
                );
              }),
              const SizedBox(height: 16),
              Text(
                'Total Amount: \$${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
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
                child: _buildAnalyticsCard('Bills', '45', Icons.receipt_long),
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
          // Profile header
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.local_pharmacy, size: 50),
          ),
          const SizedBox(height: 16),
          const Text(
            'HealthCare Pharmacy',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text('License: #PHM12345'),
          const SizedBox(height: 24),

          // Profile options
          _buildProfileOption('Edit Profile', Icons.edit, () {}),
          _buildProfileOption('Business Hours', Icons.schedule, () {}),
          _buildProfileOption('Notifications', Icons.notifications, () {}),
          _buildProfileOption('Reports', Icons.analytics, () {}),
          _buildProfileOption('Settings', Icons.settings, () {}),
          _buildProfileOption('Help & Support', Icons.help, () {}),

          const SizedBox(height: 16),

          // Logout Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.logout, color: Colors.red, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _showLogoutDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption(String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
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
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.2);
        textColor = Colors.orange[800]!;
        displayText = 'Pending';
        break;
      case 'processing':
        backgroundColor = Colors.blue.withOpacity(0.2);
        textColor = Colors.blue[800]!;
        displayText = 'Processing';
        break;
      case 'ready':
        backgroundColor = Colors.purple.withOpacity(0.2);
        textColor = Colors.purple[800]!;
        displayText = 'Ready';
        break;
      case 'delivered':
        backgroundColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green[800]!;
        displayText = 'Delivered';
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.2);
        textColor = Colors.grey[800]!;
        displayText = status.toUpperCase();
    }

    return Chip(
      label: Text(
        displayText,
        style: TextStyle(color: textColor, fontSize: 12),
      ),
      backgroundColor: backgroundColor,
    );
  }

  List<Map<String, dynamic>> _filterPrescriptionMaps(
    List<Map<String, dynamic>> prescriptions,
  ) {
    return prescriptions.where((prescription) {
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final patientName = (prescription['patientName'] ?? '')
            .toString()
            .toLowerCase();
        final doctorName = (prescription['doctorName'] ?? '')
            .toString()
            .toLowerCase();
        final orderNumber = (prescription['orderNumber'] ?? 0).toString();

        if (!patientName.contains(_searchQuery.toLowerCase()) &&
            !doctorName.contains(_searchQuery.toLowerCase()) &&
            !orderNumber.contains(_searchQuery)) {
          return false;
        }
      }

      // Filter by status
      if (_selectedFilter != 'all') {
        final status = prescription['status'] ?? 'pending';
        if (status != _selectedFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _updatePrescriptionStatus(
    String prescriptionId,
    String newStatus,
  ) async {
    try {
      // Get prescription data to extract medicines for inventory check
      final prescriptionDoc = await FirebaseFirestore.instance
          .collection('prescriptions')
          .doc(prescriptionId)
          .get();

      if (!prescriptionDoc.exists) {
        throw Exception('Prescription not found');
      }

      final prescriptionData = prescriptionDoc.data()!;
      final medicinesData =
          prescriptionData['medicines'] as List<dynamic>? ?? [];

      // Convert to Medicine objects for inventory checking
      final medicines = medicinesData.map((data) {
        final medicineData = data as Map<String, dynamic>;
        return Medicine(
          id: medicineData['id'] ?? '',
          name: medicineData['name'] ?? '',
          quantity: medicineData['quantity'] ?? 0,
          dosage: medicineData['dosage'] ?? '',
          duration: medicineData['duration'] ?? '7 days',
          instructions: medicineData['instructions'] ?? '',
          price: (medicineData['price'] ?? 0.0).toDouble(),
        );
      }).toList();

      // Use inventory checking method for status updates to 'ready' or 'delivered'
      if (newStatus.toLowerCase() == 'ready' ||
          newStatus.toLowerCase() == 'delivered') {
        final result = await _pharmacyService
            .updatePrescriptionStatusWithInventoryCheck(
              prescriptionId,
              newStatus,
              medicines,
            );

        if (result['success'] == true) {
          // Status updated successfully
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Prescription status updated to $newStatus'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (result['requiresConfirmation'] == true) {
          // Show inventory warning dialog
          await _showInventoryWarningDialog(
            prescriptionId,
            newStatus,
            medicines,
            result['inventoryCheck'],
          );
        } else {
          // Handle other errors
          throw Exception(result['error'] ?? 'Unknown error occurred');
        }
      } else {
        // For other status updates, use the regular method
        await PrescriptionService.updatePrescriptionStatus(
          prescriptionId,
          newStatus,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Prescription status updated to $newStatus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPrescriptionDetails(Map<String, dynamic> prescription) {
    final medicines = prescription['medicines'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Prescription #${prescription['orderNumber']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Patient: ${prescription['patientName']}'),
              Text('Doctor: Dr. ${prescription['doctorName']}'),
              if (prescription['diagnosis'] != null &&
                  prescription['diagnosis'].toString().isNotEmpty)
                Text('Diagnosis: ${prescription['diagnosis']}'),
              const SizedBox(height: 16),
              const Text(
                'Medicines:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...medicines.map((medicine) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ${medicine['name']} (${medicine['dosage']})'),
                      Text('  Quantity: ${medicine['quantity']}'),
                      Text('  Frequency: ${medicine['frequency']}'),
                      Text('  Duration: ${medicine['duration']}'),
                      if (medicine['instructions'] != null &&
                          medicine['instructions'].toString().isNotEmpty)
                        Text('  Instructions: ${medicine['instructions']}'),
                    ],
                  ),
                );
              }),
              if (prescription['notes'] != null &&
                  prescription['notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(prescription['notes']),
              ],
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

  void _generateBillFromMap(Map<String, dynamic> prescription) {
    // Placeholder for bill generation - can be enhanced later
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Bill'),
        content: Text(
          'Generate bill for prescription #${prescription['orderNumber']}?\n\nThis feature will calculate medicine costs and create a bill for the patient.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bill generation feature coming soon!'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInventoryWarningDialog(
    String prescriptionId,
    String newStatus,
    List<Medicine> medicines,
    Map<String, dynamic> inventoryCheck,
  ) async {
    final warnings = inventoryCheck['warnings'] as List<String>;
    final availableMedicines =
        inventoryCheck['availableMedicines'] as List<Medicine>;
    final hasUnavailable = inventoryCheck['hasUnavailable'] as bool;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Inventory Warning'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Some medicines have inventory issues:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $warning',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (availableMedicines.isNotEmpty) ...[
                  const Text(
                    'Available medicines that can be processed:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...availableMedicines.map(
                    (med) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${med.name} (${med.availableQuantity}/${med.quantity})',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            if (availableMedicines.isNotEmpty)
              TextButton(
                child: Text(
                  hasUnavailable ? 'Process Available Only' : 'Continue',
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Process with available medicines only - always use partial method since we have availability issues
                  try {
                    // Always use the partial quantities method when there are inventory issues
                    await _pharmacyService
                        .updatePrescriptionStatusWithPartialQuantities(
                          prescriptionId,
                          newStatus,
                          availableMedicines,
                        );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          hasUnavailable
                              ? 'Prescription updated with available medicines only'
                              : 'Prescription status updated to $newStatus',
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating status: $e')),
                    );
                  }
                },
              ),
          ],
        );
      },
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notification Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to notification settings
              },
            ),
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
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
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
