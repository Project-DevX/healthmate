import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class PharmacyDashboardPage extends StatefulWidget {
  const PharmacyDashboardPage({Key? key}) : super(key: key);

  @override
  State<PharmacyDashboardPage> createState() => _PharmacyDashboardPageState();
}

class _PharmacyDashboardPageState extends State<PharmacyDashboardPage> {
  bool isDarkMode = false;
  int _selectedBottomNav = 0;
  bool _isLoading = false;

  // Placeholder data for KPIs
  int totalPrescriptions = 200;
  int fulfilledPrescriptions = 150;
  int pendingPrescriptions = 30;
  int outOfStockAlerts = 5;
  int todaysPickups = 12;

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
    _showFeatureModal(feature);
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final Color mainBlue = const Color(0xFF7B61FF);
    final Color scaffoldBg = isDarkMode ? Colors.black : Colors.grey.shade50;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: mainBlue,
        foregroundColor: Colors.white,
        title: const Text('Pharmacy Dashboard'),
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
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Fulfilled',
                              '$fulfilledPrescriptions',
                              Icons.check_circle,
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
                              'Pending',
                              '$pendingPrescriptions',
                              Icons.pending_actions,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Out of Stock',
                              '$outOfStockAlerts',
                              Icons.warning,
                              Colors.red,
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
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  ? const Center(child: Text('Chat System (Stub)', style: TextStyle(fontSize: 20)))
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
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e')),
        );
      }
    }
    if (mounted) setState(() => _isUploading = false);
  }

  void _showEditProfileDialog() {
    final _institutionNameController = TextEditingController(text: pharmacyData?['institutionName'] ?? '');
    final _repDesignationController = TextEditingController(text: pharmacyData?['repDesignation'] ?? '');
    final _repEmailController = TextEditingController(text: pharmacyData?['repEmail'] ?? '');
    final _hotlineController = TextEditingController(text: pharmacyData?['hotline'] ?? '');
    final _addressController = TextEditingController(text: pharmacyData?['address'] ?? '');
    final _websiteController = TextEditingController(text: pharmacyData?['website'] ?? '');
    final _repNameController = TextEditingController(text: pharmacyData?['repName'] ?? '');
    final _repContactController = TextEditingController(text: pharmacyData?['repContact'] ?? '');
    final _hoursController = TextEditingController(text: pharmacyData?['operatingHours'] ?? '');
    final _servicesController = TextEditingController(text: pharmacyData?['services'] ?? '');

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
                decoration: const InputDecoration(labelText: 'Institution Name'),
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
              Text('Authorized Representative', style: TextStyle(fontWeight: FontWeight.bold)),
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
                decoration: const InputDecoration(labelText: 'Services Offered'),
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
    final Color cardBg = isDarkMode ? const Color(0xFF232A34) : const Color(0xFFF5F9FF);
    final Color scaffoldBg = isDarkMode ? const Color(0xFF181C22) : Colors.white;
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
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        pharmacyData?['institutionName'] ?? 'Pharmacy Name',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pharmacy Details', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                            const SizedBox(height: 8),
                            _profileRow('Institution Name', pharmacyData?['institutionName']),
                            _profileRow('License Number', pharmacyData?['licenseNumber']),
                            _profileRow('Hotline', pharmacyData?['hotline']),
                            _profileRow('Address', pharmacyData?['address']),
                            _profileRow('Website', pharmacyData?['website']),
                            const SizedBox(height: 16),
                            Text('Authorized Representative', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                            const SizedBox(height: 8),
                            _profileRow('Name', pharmacyData?['repName']),
                            _profileRow('Designation', pharmacyData?['repDesignation']),
                            _profileRow('Contact', pharmacyData?['repContact']),
                            _profileRow('Email', pharmacyData?['repEmail']),
                            const SizedBox(height: 16),
                            Text('Operating Hours:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text(pharmacyData?['operatingHours'] ?? 'Not set', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            Text('Services Offered:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text((pharmacyData?['services'] as String? ?? 'Not set'), style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            Text('User Management:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text('Add/remove pharmacy staff (admin only) - Coming soon', style: const TextStyle(color: Colors.grey)),
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
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(value?.toString() ?? 'Not set', style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
} 