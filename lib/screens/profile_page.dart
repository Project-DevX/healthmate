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
  Map<String, dynamic>? doctorData;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final uid = user.uid;
    try {
      final docSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (docSnap.exists) {
        doctorData = docSnap.data();
      }
    } catch (e) {
      print('Error loading doctor profile: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _isUploading = true);
    try {
      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance.ref().child('profile_photos/${user.uid}.jpg');
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoURL': url});
      setState(() {
        doctorData?['photoURL'] = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated!')));
    } catch (e) {
      print('Error uploading photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update photo.')));
    }
    setState(() => _isUploading = false);
  }

  void _showEditProfileDialog() {
    final _phoneController = TextEditingController(text: doctorData?['phone'] ?? '');
    final _specializationController = TextEditingController(text: doctorData?['specialization'] ?? '');
    final _affiliationController = TextEditingController(text: doctorData?['affiliation'] ?? '');
    final _licenseController = TextEditingController(text: doctorData?['licenseNumber'] ?? '');
    final _experienceController = TextEditingController(text: doctorData?['experienceYears']?.toString() ?? '');
    final _subSpecializationController = TextEditingController(text: doctorData?['subSpecialization'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: _affiliationController,
                decoration: const InputDecoration(labelText: 'Affiliation'),
              ),
              TextField(
                controller: _experienceController,
                decoration: const InputDecoration(labelText: 'Experience (years)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _subSpecializationController,
                decoration: const InputDecoration(labelText: 'Sub-specialization'),
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
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final uid = user.uid;
              final updatedData = {
                'phone': _phoneController.text.trim(),
                'affiliation': _affiliationController.text.trim(),
                'experienceYears': int.tryParse(_experienceController.text.trim()) ?? 0,
                'subSpecialization': _subSpecializationController.text.trim(),
              };
              await FirebaseFirestore.instance.collection('users').doc(uid).update(updatedData);
              setState(() {
                doctorData?.addAll(updatedData);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
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
    final Color mainBlue = const Color(0xFF2196F3);
    final Color successGreen = const Color(0xFF4CAF50);
    final Color cardBg = isDarkMode ? const Color(0xFF232A34) : const Color(0xFFF5F9FF);
    final Color scaffoldBg = isDarkMode ? const Color(0xFF181C22) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : mainBlue;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
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
            onPressed: doctorData == null ? null : _showEditProfileDialog,
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      backgroundColor: scaffoldBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : doctorData == null
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
                                doctorData?['photoURL'] ??
                                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(doctorData?['fullName'] ?? 'Doctor')}&background=2196F3&color=fff',
                              ),
                              child: _isUploading
                                  ? const CircularProgressIndicator()
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: mainBlue,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(Icons.edit, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        doctorData?['fullName'] ?? 'Doctor',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        doctorData?['specialization'] ?? '',
                        style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.grey[300] : Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      color: cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _profileField('Email', doctorData?['email'] ?? '', textColor),
                            _profileField('Phone', doctorData?['phone'] ?? '', textColor),
                            _profileField('License', doctorData?['licenseNumber'] ?? '', textColor),
                            _profileField('Experience', doctorData?['experienceYears'] != null ? '${doctorData?['experienceYears']} years' : '', textColor),
                            _profileField('Affiliation', doctorData?['affiliation'] ?? '', textColor),
                            _profileField('Sub-specialization', doctorData?['subSpecialization'] ?? '', textColor),
                            _profileField('Date of Birth', _formatDate(doctorData?['dateOfBirth']), textColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _profileField(String label, String value, Color textColor) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return date.toString();
  }
} 