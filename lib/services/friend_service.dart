import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shared_models.dart';

class FriendService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send friend request
  static Future<void> sendFriendRequest({
    required String senderId,
    required String senderName,
    required String senderType,
    required String receiverId,
    required String receiverName,
    required String receiverType,
  }) async {
    // Check if request already exists
    final existingRequest = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('Friend request already exists');
    }

    // Check if they are already friends
    final existingFriend = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: senderId)
        .where('friendId', isEqualTo: receiverId)
        .get();

    if (existingFriend.docs.isNotEmpty) {
      throw Exception('Already friends');
    }

    final request = FriendRequest(
      id: '',
      senderId: senderId,
      senderName: senderName,
      senderType: senderType,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverType: receiverType,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _firestore.collection('friend_requests').add(request.toMap());
  }

  // Accept friend request
  static Future<void> acceptFriendRequest(String requestId) async {
    final requestDoc = await _firestore.collection('friend_requests').doc(requestId).get();
    if (!requestDoc.exists) {
      throw Exception('Friend request not found');
    }

    final request = FriendRequest.fromFirestore(requestDoc);

    // Update request status
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'accepted',
      'respondedAt': Timestamp.now(),
    });

    // Add to friends collection for both users
    final friend1 = Friend(
      id: '',
      userId: request.senderId,
      friendId: request.receiverId,
      friendName: request.receiverName,
      friendType: request.receiverType,
      addedAt: DateTime.now(),
    );

    final friend2 = Friend(
      id: '',
      userId: request.receiverId,
      friendId: request.senderId,
      friendName: request.senderName,
      friendType: request.senderType,
      addedAt: DateTime.now(),
    );

    await _firestore.collection('friends').add(friend1.toMap());
    await _firestore.collection('friends').add(friend2.toMap());
  }

  // Decline friend request
  static Future<void> declineFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'declined',
      'respondedAt': Timestamp.now(),
    });
  }

  // Get sent friend requests
  static Stream<List<FriendRequest>> getSentFriendRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs.map((doc) => FriendRequest.fromFirestore(doc)).toList();
          // Sort in memory to avoid composite index requirement
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  // Get received friend requests
  static Stream<List<FriendRequest>> getReceivedFriendRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs.map((doc) => FriendRequest.fromFirestore(doc)).toList();
          // Sort in memory to avoid composite index requirement
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  // Get friends list
  static Stream<List<Friend>> getFriends(String userId) {
    return _firestore
        .collection('friends')
        .where('userId', isEqualTo: userId)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Friend.fromFirestore(doc)).toList());
  }

  // Search users for friend requests
  static Future<List<Map<String, dynamic>>> searchUsers(String query, String currentUserId) async {
    if (query.trim().isEmpty) return [];

    try {
      // Search by name or email
      final nameQuery = await _firestore
          .collection('users')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(20)
          .get();

      final emailQuery = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(20)
          .get();

      final users = <String, Map<String, dynamic>>{};

      // Add name matches
      for (final doc in nameQuery.docs) {
        if (doc.id != currentUserId) {
          final data = doc.data();
          users[doc.id] = {
            'id': doc.id,
            'name': data['fullName'] ?? data['name'] ?? 'Unknown',
            'email': data['email'] ?? '',
            'type': data['userType'] ?? 'unknown',
          };
        }
      }

      // Add email matches
      for (final doc in emailQuery.docs) {
        if (doc.id != currentUserId) {
          final data = doc.data();
          users[doc.id] = {
            'id': doc.id,
            'name': data['fullName'] ?? data['name'] ?? 'Unknown',
            'email': data['email'] ?? '',
            'type': data['userType'] ?? 'unknown',
          };
        }
      }

      return users.values.toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Check if users are friends
  static Future<bool> areFriends(String userId1, String userId2) async {
    final friend = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: userId1)
        .where('friendId', isEqualTo: userId2)
        .get();

    return friend.docs.isNotEmpty;
  }

  // Check if friend request exists
  static Future<FriendRequest?> getFriendRequest(String senderId, String receiverId) async {
    final request = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (request.docs.isNotEmpty) {
      return FriendRequest.fromFirestore(request.docs.first);
    }
    return null;
  }

  // Remove friend
  static Future<void> removeFriend(String userId, String friendId) async {
    // Remove from both users' friend lists
    final friend1 = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: userId)
        .where('friendId', isEqualTo: friendId)
        .get();

    final friend2 = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: friendId)
        .where('friendId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in friend1.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in friend2.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}