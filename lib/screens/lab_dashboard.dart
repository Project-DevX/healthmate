import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class LabDashboard extends StatefulWidget {
  const LabDashboard({Key? key}) : super(key: key);

  @override
  State<LabDashboard> createState() => _LabDashboardState();
}

class _LabDashboardState extends State<LabDashboard> {
  bool isDarkMode = false;
  int _selectedBottomNav = 0;
  bool _isLoading = false;

  // Placeholder data for KPIs
  int totalTests = 120;
  int pendingUploads = 8;
  int todaysAppointments = 15;

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
        _showFeatureModal('Report Upload Module');
        return;
      case 'Report Management':
        _showFeatureModal('Report Management Table');
        return;
      case 'Test Requests':
        _showFeatureModal('Test Request Viewer');
        return;
      case 'Patient Search':
        _showFeatureModal('Patient Search Tool');
        return;
      case 'Appointment Calendar':
        _showFeatureModal('Appointment Calendar');
        return;
      case 'Staff Assignment':
        _showFeatureModal('Lab Staff Assignment');
        return;
      case 'Notifications':
        _showFeatureModal('Notifications Panel');
        return;
    }
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
    // TODO: Implement logout logic
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
        title: const Text('Lab Dashboard'),
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
                                  Icons.science,
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
                                      'Welcome, Lab Staff!',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Laboratory Department',
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
                              'Total Tests',
                              '$totalTests',
                              Icons.assignment_turned_in,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Pending Uploads',
                              '$pendingUploads',
                              Icons.upload_file,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              "Today's Appointments",
                              '$todaysAppointments',
                              Icons.calendar_today,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Completed',
                              '${totalTests - pendingUploads}',
                              Icons.check_circle,
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
              // Other editable fields
              TextField(
                controller: _hoursController,
                decoration: const InputDecoration(labelText: 'Operating Hours'),
              ),
              TextField(
                controller: _testTypesController,
                decoration: const InputDecoration(labelText: 'Test Types Offered'),
              ),
              TextField(
                controller: _turnaroundController,
                decoration: const InputDecoration(labelText: 'Report Turnaround Time'),
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
    final Color cardBg = isDarkMode ? const Color(0xFF232A34) : const Color(0xFFF5F9FF);
    final Color scaffoldBg = isDarkMode ? const Color(0xFF181C22) : Colors.white;
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
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        labData?['institutionName'] ?? 'Lab Name',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lab Details', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                            const SizedBox(height: 8),
                            _profileRow('Institution Type', labData?['institutionType']),
                            _profileRow('License Number', labData?['licenseNumber']),
                            _profileRow('Hotline', labData?['hotline']),
                            _profileRow('Address', labData?['address']),
                            _profileRow('Website', labData?['website']),
                            const SizedBox(height: 16),
                            Text('Authorized Representative', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                            const SizedBox(height: 8),
                            _profileRow('Name', labData?['repName']),
                            _profileRow('Designation', labData?['repDesignation']),
                            _profileRow('Contact', labData?['repContact']),
                            _profileRow('Email', labData?['repEmail']),
                            const SizedBox(height: 16),
                            Text('Operating Hours:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text(labData?['operatingHours'] ?? 'Not set', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            Text('Test Types Offered:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text((labData?['testTypes'] as String? ?? 'Not set'), style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            Text('Report Turnaround Time:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text(labData?['turnaroundTime'] ?? 'Not set', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            Text('User Management:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text('Add/remove lab technicians (admin only) - Coming soon', style: const TextStyle(color: Colors.grey)),
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