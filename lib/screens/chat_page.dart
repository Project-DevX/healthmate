import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  String? selectedPatientId;
  String? selectedPatientName;
  List<Map<String, dynamic>> patients = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    try {
      final patSnap = await FirebaseFirestore.instance
          .collection('patients')
          .where('doctorId', isEqualTo: uid)
          .get();
      setState(() {
        patients = patSnap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
        if (patients.isNotEmpty) {
          selectedPatientId = patients[0]['id'];
          selectedPatientName = patients[0]['name'] ?? 'Patient';
        }
      });
    } catch (e) {
      print('Error loading patients: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> _chatStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedPatientId == null) {
      return const Stream.empty();
    }
    final chatId = '${user.uid}_$selectedPatientId';
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedPatientId == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final chatId = '${user.uid}_$selectedPatientId';
    final message = {
      'text': text,
      'senderId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDarkMode = brightness == Brightness.dark;
    final Color mainBlue = const Color(0xFF2196F3);
    final Color cardBg = isDarkMode ? const Color(0xFF232A34) : const Color(0xFFF5F9FF);
    final Color scaffoldBg = isDarkMode ? const Color(0xFF181C22) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Chat'),
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
          // Patient selector
          if (patients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButton<String>(
                value: selectedPatientId,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                items: patients.map((p) {
                  return DropdownMenuItem<String>(
                    value: p['id'],
                    child: Text(p['name'] ?? 'Patient'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedPatientId = val;
                    selectedPatientName = patients.firstWhere((p) => p['id'] == val)['name'] ?? 'Patient';
                  });
                },
              ),
            ),
          if (patients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No patients found.'),
            ),
          // Chat messages
          Expanded(
            child: selectedPatientId == null
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
                          final isMe = msg['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          if (selectedPatientId != null)
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
                        hintStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
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