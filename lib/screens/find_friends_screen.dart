import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friend_service.dart';

class FindFriendsScreen extends StatefulWidget {
  const FindFriendsScreen({Key? key}) : super(key: key);

  @override
  State<FindFriendsScreen> createState() => _FindFriendsScreenState();
}

class _FindFriendsScreenState extends State<FindFriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty || _currentUserId == null) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await FriendService.searchUsers(query, _currentUserId!);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching users: $e')),
      );
    }
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> user) async {
    if (_currentUserId == null) return;

    try {
      // For now, we'll use a simple name. In a real app, you'd fetch the user's profile
      final senderName = FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 'User';

      await FriendService.sendFriendRequest(
        senderId: _currentUserId!,
        senderName: senderName,
        senderType: 'patient', // This should be dynamic based on user type
        receiverId: user['id'],
        receiverName: user['name'],
        receiverType: user['type'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );

      // Remove from search results
      setState(() {
        _searchResults.removeWhere((element) => element['id'] == user['id']);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending friend request: $e')),
      );
    }
  }

  Widget _buildUserTypeIcon(String userType) {
    IconData iconData;
    Color iconColor;

    switch (userType.toLowerCase()) {
      case 'doctor':
        iconData = Icons.local_hospital;
        iconColor = Colors.blue;
        break;
      case 'patient':
        iconData = Icons.person;
        iconColor = Colors.green;
        break;
      case 'caregiver':
        iconData = Icons.people;
        iconColor = Colors.orange;
        break;
      case 'hospital':
        iconData = Icons.business;
        iconColor = Colors.red;
        break;
      case 'pharmacy':
        iconData = Icons.local_pharmacy;
        iconColor = Colors.purple;
        break;
      case 'lab':
        iconData = Icons.science;
        iconColor = Colors.teal;
        break;
      default:
        iconData = Icons.person;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.1),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Friends'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: (value) {
                _searchUsers(value);
              },
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(
                        child: Text('No users found'),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: _buildUserTypeIcon(user['type']),
                              title: Text(
                                user['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['email']),
                                  Text(
                                    user['type'].toString().toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _sendFriendRequest(user),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Add Friend'),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}