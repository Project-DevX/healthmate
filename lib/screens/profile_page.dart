import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? hospitalData;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _docExists = true;

  @override
  void initState() {
    super.initState();
    _loadHospitalData();
  }

  Future<void> _loadHospitalData() async {
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
        hospitalData = docSnap.data();
        _docExists = true;
      } else {
        hospitalData = null;
        _docExists = false;
      }
    } catch (e) {
      print('Error loading hospital profile: $e');
      hospitalData = null;
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
        'hospital_profile_photos/${user.uid}.jpg',
      );
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoURL': url},
      );
      await _loadHospitalData();
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
    final _nameController = TextEditingController(text: hospitalData?['institutionName'] ?? '');
    final _licenseController = TextEditingController(text: hospitalData?['licenseNumber'] ?? '');
    final _hotlineController = TextEditingController(text: hospitalData?['hotline'] ?? '');
    final _addressController = TextEditingController(text: hospitalData?['address'] ?? '');
    final _websiteController = TextEditingController(text: hospitalData?['website'] ?? '');
    final _repNameController = TextEditingController(text: hospitalData?['repName'] ?? '');
    final _repDesignationController = TextEditingController(text: hospitalData?['repDesignation'] ?? '');
    final _repContactController = TextEditingController(text: hospitalData?['repContact'] ?? '');
    final _repEmailController = TextEditingController(text: hospitalData?['repEmail'] ?? '');
    final _hoursController = TextEditingController(text: hospitalData?['operatingHours'] ?? '');
    final _servicesController = TextEditingController(text: hospitalData?['services'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Hospital Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Hospital Name'),
              ),
              TextField(
                controller: _licenseController,
                decoration: const InputDecoration(labelText: 'License Number'),
                enabled: false,
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
                  'institutionName': _nameController.text.trim(),
                  'licenseNumber': _licenseController.text.trim(),
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
                await _loadHospitalData();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hospital profile updated!')),
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
        title: const Text('Hospital Profile'),
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
            tooltip: 'Edit Hospital Details',
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
                                hospitalData?['photoURL'] ??
                                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(hospitalData?['institutionName'] ?? 'Hospital')}&background=7B61FF&color=fff',
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
                        hospitalData?['institutionName'] ?? 'Hospital Name',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        hospitalData?['officialEmail'] ?? 'Email not set',
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
                            Text('Hospital Details', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                            const SizedBox(height: 8),
                            _profileRow('Institution Type', hospitalData?['institutionType']),
                            _profileRow('License Number', hospitalData?['licenseNumber']),
                            _profileRow('Hotline', hospitalData?['hotline']),
                            _profileRow('Address', hospitalData?['address']),
                            _profileRow('Website', hospitalData?['website']),
                            const SizedBox(height: 16),
                            Text('Authorized Representative', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                            const SizedBox(height: 8),
                            _profileRow('Name', hospitalData?['repName']),
                            _profileRow('Designation', hospitalData?['repDesignation']),
                            _profileRow('Contact', hospitalData?['repContact']),
                            _profileRow('Email', hospitalData?['repEmail']),
                            const SizedBox(height: 16),
                            Text('Operating Hours:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text(hospitalData?['operatingHours'] ?? 'Not set', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            Text('Services Offered:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text((hospitalData?['services'] as String? ?? 'Not set'), style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            Text('User Management:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 4),
                            Text('Add/remove hospital staff (admin only) - Coming soon', style: const TextStyle(color: Colors.grey)),
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
