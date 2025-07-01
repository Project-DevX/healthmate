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
  Map<String, dynamic>? caregiverData;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCaregiverData();
  }

  Future<void> _loadCaregiverData() async {
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
        caregiverData = docSnap.data();
      }
    } catch (e) {
      print('Error loading caregiver profile: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _isUploading = true);
    try {
      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_photos/${user.uid}.jpg',
      );
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoURL': url},
      );
      setState(() {
        caregiverData?['photoURL'] = url;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated!')));
    } catch (e) {
      print('Error uploading photo: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update photo.')));
    }
    setState(() => _isUploading = false);
  }

  void _showEditProfileDialog() {
    final _phoneController = TextEditingController(
      text: caregiverData?['phone'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Phone Number'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
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
              foregroundColor: const Color(0xFF2196F3), // mainBlue
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              elevation: 1,
            ),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final uid = user.uid;
              final updatedData = {
                'phone': _phoneController.text.trim(),
              };
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update(updatedData);
              setState(() {
                caregiverData?.addAll(updatedData);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Phone number updated!')));
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
    final Color cardBg = isDarkMode
        ? const Color(0xFF232A34)
        : const Color(0xFFF5F9FF);
    final Color scaffoldBg = isDarkMode
        ? const Color(0xFF181C22)
        : Colors.white;
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
            onPressed: caregiverData == null ? null : _showEditProfileDialog,
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      backgroundColor: scaffoldBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : caregiverData == null
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
                            caregiverData?['photoURL'] ??
                                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(caregiverData?['fullName'] ?? 'Caregiver')}&background=2196F3&color=fff',
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
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    caregiverData?['fullName'] ?? 'Caregiver',
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
                    caregiverData?['caregiverType'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  color: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _profileField(
                          'Email',
                          caregiverData?['email'] ?? '',
                          textColor,
                        ),
                        _profileField(
                          'Phone',
                          caregiverData?['phone'] ?? '',
                          textColor,
                        ),
                        _profileField(
                          'NIC/Passport',
                          caregiverData?['nicOrPassport'] ?? '',
                          textColor,
                        ),
                        _profileField(
                          'Date of Birth',
                          _formatDate(caregiverData?['dateOfBirth']),
                          textColor,
                        ),
                        _profileField(
                          'Gender',
                          caregiverData?['gender'] ?? '',
                          textColor,
                        ),
                        _profileField(
                          'Caregiver Type',
                          caregiverData?['caregiverType'] ?? '',
                          textColor,
                        ),
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
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      return date.toDate().toLocal().toString().split(' ')[0];
    } else if (date is DateTime) {
      return date.toLocal().toString().split(' ')[0];
    } else if (date is String) {
      return date.split(' ')[0];
    }
    return '';
  }
}
