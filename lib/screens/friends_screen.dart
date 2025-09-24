import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friend_service.dart';
import '../models/shared_models.dart';
import 'find_friends_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      await FriendService.acceptFriendRequest(requestId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request accepted!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting friend request: $e')),
      );
    }
  }

  Future<void> _declineFriendRequest(String requestId) async {
    try {
      await FriendService.declineFriendRequest(requestId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request declined')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining friend request: $e')),
      );
    }
  }

  Future<void> _removeFriend(String friendId, String friendName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Are you sure you want to remove $friendName from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentUserId != null) {
      try {
        await FriendService.removeFriend(_currentUserId!, friendId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $friendName from friends')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing friend: $e')));
      }
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
    if (_currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FindFriendsScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends', icon: Icon(Icons.people)),
            Tab(text: 'Requests', icon: Icon(Icons.notifications)),
            Tab(text: 'Sent', icon: Icon(Icons.send)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Friends Tab
          StreamBuilder<List<Friend>>(
            stream: FriendService.getFriends(_currentUserId!),
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
                      Text(
                        'Error loading friends: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No friends yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap the + button to find friends',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final friends = snapshot.data!;
              return ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: _buildUserTypeIcon(friend.friendType),
                      title: Text(
                        friend.friendName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        friend.friendType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'remove') {
                            _removeFriend(friend.friendId, friend.friendName);
                          } else if (value == 'chat') {
                            // Navigate to chat
                            // This will be implemented when integrating with chat
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'chat',
                            child: Row(
                              children: [
                                Icon(Icons.chat),
                                SizedBox(width: 8),
                                Text('Chat'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.remove_circle, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Remove Friend'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Received Requests Tab
          StreamBuilder<List<FriendRequest>>(
            stream: FriendService.getReceivedFriendRequests(_currentUserId!),
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
                      Text(
                        'Error loading requests: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No pending requests',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final requests = snapshot.data!;
              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: _buildUserTypeIcon(request.senderType),
                      title: Text(
                        request.senderName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request.senderType.toUpperCase()),
                          Text(
                            'Sent ${request.createdAt.toString().split(' ')[0]}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _acceptFriendRequest(request.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _declineFriendRequest(request.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Sent Requests Tab
          StreamBuilder<List<FriendRequest>>(
            stream: FriendService.getSentFriendRequests(_currentUserId!),
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
                      Text(
                        'Error loading requests: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No sent requests',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final requests = snapshot.data!;
              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: _buildUserTypeIcon(request.receiverType),
                      title: Text(
                        request.receiverName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${request.receiverType.toUpperCase()} • ${request.status}',
                          ),
                          Text(
                            'Sent ${request.createdAt.toString().split(' ')[0]}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        request.status.toUpperCase(),
                        style: TextStyle(
                          color: request.status == 'pending'
                              ? Colors.orange
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
