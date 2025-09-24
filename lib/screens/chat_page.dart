import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  String? selectedContactId;
  String? selectedContactName;
  String? selectedContactType;
  List<Map<String, dynamic>> contacts = [];
  String? currentUserType;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    currentUserId = user.uid;

    try {
      // Get user data to determine user type
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        currentUserType = userData?['userType'] ?? 'patient';

        // Load contacts based on user type
        await _loadContacts();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadContacts() async {
    if (currentUserType == null || currentUserId == null) return;

    try {
      final loadedContacts = await ChatService.getContacts(
        currentUserType!,
        currentUserId!,
      );
      setState(() {
        contacts = loadedContacts;
        if (contacts.isNotEmpty) {
          selectedContactId = contacts[0]['id'];
          selectedContactName = contacts[0]['name'];
          selectedContactType = contacts[0]['type'];
        }
      });
    } catch (e) {
      print('Error loading contacts: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> _chatStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedContactId == null) {
      return const Stream.empty();
    }
    return ChatService.getChatStream(user.uid, selectedContactId!);
  }

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedContactId == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await ChatService.sendMessage(user.uid, selectedContactId!, text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDarkMode = brightness == Brightness.dark;
    final Color mainBlue = AppTheme.getUserTypeColor(
      currentUserType ?? 'patient',
    );
    final Color cardBg = isDarkMode
        ? const Color(0xFF232A34)
        : const Color(0xFFF5F9FF);
    final Color scaffoldBg = isDarkMode
        ? const Color(0xFF181C22)
        : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          selectedContactName != null
              ? 'Chat with $selectedContactName'
              : 'Chat',
        ),
        backgroundColor: isDarkMode ? const Color(0xFF232A34) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: mainBlue),
        titleTextStyle: TextStyle(
          color: isDarkMode ? Colors.white : mainBlue,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      body: Column(
        children: [
          // Contact selector
          if (contacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButton<String>(
                value: selectedContactId,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: contacts.map((contact) {
                  return DropdownMenuItem<String>(
                    value: contact['id'],
                    child: Row(
                      children: [
                        Text(contact['name'] ?? 'Contact'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: mainBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            contact['type']?.toUpperCase() ?? 'USER',
                            style: TextStyle(
                              color: mainBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedContactId = val;
                    final contact = contacts.firstWhere((c) => c['id'] == val);
                    selectedContactName = contact['name'];
                    selectedContactType = contact['type'];
                  });
                },
              ),
            ),
          if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No contacts found.'),
            ),
          // Chat messages
          Expanded(
            child: selectedContactId == null
                ? const SizedBox.shrink()
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _chatStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = snapshot.data ?? [];
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe =
                              msg['senderId'] ==
                              FirebaseAuth.instance.currentUser?.uid;
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? mainBlue : cardBg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                msg['text'] ?? '',
                                style: TextStyle(
                                  color: isMe ? Colors.white : textColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          // Message input
          if (selectedContactId != null)
            Container(
              color: isDarkMode ? const Color(0xFF232A34) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[700],
                        ),
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 0,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send, color: mainBlue),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
