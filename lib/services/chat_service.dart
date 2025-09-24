import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get contacts based on user role
  static Future<List<Map<String, dynamic>>> getContacts(
    String userType,
    String userId,
  ) async {
    try {
      List<Map<String, dynamic>> contacts = [];

      // First add friends
      contacts.addAll(await _getFriends(userId));

      // Then add role-based contacts
      switch (userType.toLowerCase()) {
        case 'patient':
          // Patients can chat with doctors and caregivers
          contacts.addAll(await _getPatientDoctors(userId));
          contacts.addAll(await _getPatientCaregivers(userId));
          break;

        case 'doctor':
          // Doctors can chat with patients, hospitals, and labs
          contacts.addAll(await _getDoctorPatients(userId));
          contacts.addAll(await _getDoctorHospitals(userId));
          contacts.addAll(await _getDoctorLabs(userId));
          break;

        case 'caregiver':
          // Caregivers can chat with patients
          contacts.addAll(await _getCaregiverPatients(userId));
          break;

        case 'hospital':
          // Hospitals can chat with doctors and patients
          contacts.addAll(await _getHospitalDoctors(userId));
          contacts.addAll(await _getHospitalPatients(userId));
          break;

        case 'pharmacy':
          // Pharmacies can chat with doctors, patients, and suppliers
          contacts.addAll(await _getPharmacyDoctors(userId));
          contacts.addAll(await _getPharmacyPatients(userId));
          contacts.addAll(await _getPharmacySuppliers(userId));
          break;

        case 'lab':
          // Labs can chat with doctors and patients
          contacts.addAll(await _getLabDoctors(userId));
          contacts.addAll(await _getLabPatients(userId));
          break;
      }

      return contacts;
    } catch (e) {
      print('Error getting contacts: $e');
      return [];
    }
  }

  // Patient contacts
  static Future<List<Map<String, dynamic>>> _getPatientDoctors(
    String patientId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'doctor')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['fullName'] ?? data['name'] ?? 'Doctor',
          'type': 'doctor',
          'email': data['email'],
          'specialization': data['specialization'] ?? 'General',
        };
      }).toList();
    } catch (e) {
      print('Error getting patient doctors: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getPatientCaregivers(
    String patientId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'caregiver')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['fullName'] ?? data['name'] ?? 'Caregiver',
          'type': 'caregiver',
          'email': data['email'],
        };
      }).toList();
    } catch (e) {
      print('Error getting patient caregivers: $e');
      return [];
    }
  }

  // Doctor contacts
  static Future<List<Map<String, dynamic>>> _getDoctorPatients(
    String doctorId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'patient')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'type': 'patient',
          'email': data['email'],
        };
      }).toList();
    } catch (e) {
      print('Error getting doctor patients: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getDoctorHospitals(
    String doctorId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'hospital')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['institutionName'] ?? data['name'] ?? 'Hospital',
          'type': 'hospital',
          'email': data['email'],
        };
      }).toList();
    } catch (e) {
      print('Error getting doctor hospitals: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getDoctorLabs(
    String doctorId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'lab')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['institutionName'] ?? data['name'] ?? 'Lab',
          'type': 'lab',
          'email': data['email'],
        };
      }).toList();
    } catch (e) {
      print('Error getting doctor labs: $e');
      return [];
    }
  }

  // Caregiver contacts
  static Future<List<Map<String, dynamic>>> _getCaregiverPatients(
    String caregiverId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'patient')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'type': 'patient',
          'email': data['email'],
        };
      }).toList();
    } catch (e) {
      print('Error getting caregiver patients: $e');
      return [];
    }
  }

  // Hospital contacts
  static Future<List<Map<String, dynamic>>> _getHospitalDoctors(
    String hospitalId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'doctor')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['fullName'] ?? data['name'] ?? 'Doctor',
          'type': 'doctor',
          'email': data['email'],
          'specialization': data['specialization'] ?? 'General',
        };
      }).toList();
    } catch (e) {
      print('Error getting hospital doctors: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getHospitalPatients(
    String hospitalId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'patient')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'type': 'patient',
          'email': data['email'],
        };
      }).toList();
    } catch (e) {
      print('Error getting hospital patients: $e');
      return [];
    }
  }

  // Pharmacy contacts
  static Future<List<Map<String, dynamic>>> _getPharmacyDoctors(
    String pharmacyId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'doctor')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['fullName'] ?? data['name'] ?? 'Doctor',
          'type': 'doctor',
          'email': data['email'],
          'specialization': data['specialization'] ?? 'General',
        };
      }).toList();
    } catch (e) {
      print('Error getting pharmacy doctors: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getPharmacyPatients(
    String pharmacyId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'patient')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'type': 'patient',
          'email': data['email'],
        };
      }).toList();
    } catch (e) {
      print('Error getting pharmacy patients: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getPharmacySuppliers(
    String pharmacyId,
  ) async {
    // For now, return empty list as suppliers might be handled differently
    // This can be expanded when supplier system is implemented
    return [];
  }

  // Lab contacts
  static Future<List<Map<String, dynamic>>> _getLabDoctors(String labId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'doctor')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['fullName'] ?? data['name'] ?? 'Doctor',
          'type': 'doctor',
          'email': data['email'],
          'specialization': data['specialization'] ?? 'General',
        };
      }).toList();
    } catch (e) {
      print('Error getting lab doctors: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getLabPatients(
    String labId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'patient')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'type': 'patient',
          'email': data['email'],
        };
      }).toList();
    } catch (e) {
      print('Error getting lab patients: $e');
      return [];
    }
  }

  // Friends contacts
  static Future<List<Map<String, dynamic>>> _getFriends(String userId) async {
    try {
      final friends = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .get();

      return friends.docs.map((doc) {
        final data = doc.data();
        return {
          'id': data['friendId'],
          'name': data['friendName'] ?? 'Friend',
          'type': data['friendType'] ?? 'unknown',
          'email': '', // Friends don't need email for chat
          'isFriend': true,
        };
      }).toList();
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }

  // Get chat stream between two users
  static Stream<List<Map<String, dynamic>>> getChatStream(
    String currentUserId,
    String otherUserId,
  ) {
    final chatId = _generateChatId(currentUserId, otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Send message
  static Future<void> sendMessage(
    String currentUserId,
    String otherUserId,
    String text,
  ) async {
    if (text.trim().isEmpty) return;

    final chatId = _generateChatId(currentUserId, otherUserId);
    final message = {
      'text': text.trim(),
      'senderId': currentUserId,
      'receiverId': otherUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message);
  }

  // Generate consistent chat ID
  static String _generateChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Mark messages as read
  static Future<void> markMessagesAsRead(
    String currentUserId,
    String otherUserId,
  ) async {
    final chatId = _generateChatId(currentUserId, otherUserId);
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
