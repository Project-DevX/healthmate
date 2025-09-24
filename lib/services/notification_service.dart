import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shared_models.dart';

/// Service for managing real-time notifications
class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get real-time stream of notifications for a user
  static Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();

          // Sort by creation date (newest first)
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return notifications.take(50).toList();
        });
  }

  /// Get unread notification count
  static Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  static Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();

      final unreadSnapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadSnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Send notification directly (for testing)
  static Future<void> sendTestNotification(
    String recipientId,
    String recipientType,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final notification = NotificationModel(
        id: '',
        recipientId: recipientId,
        recipientType: recipientType,
        senderId: currentUser.uid,
        senderType: 'system',
        senderName: 'System',
        title: 'Test Notification',
        message:
            'This is a test notification to verify your notification settings.',
        type: 'test',
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('notifications').add(notification.toMap());
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }

  /// Get notification by ID
  static Future<NotificationModel?> getNotificationById(
    String notificationId,
  ) async {
    try {
      final doc = await _firestore
          .collection('notifications')
          .doc(notificationId)
          .get();

      if (doc.exists) {
        return NotificationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting notification by ID: $e');
      return null;
    }
  }
}
