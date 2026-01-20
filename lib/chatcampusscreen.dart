// lib/chatcampusscreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatCampusScreen extends StatefulWidget {
  final String collegeId; // passed from CampusPostScreen

  const ChatCampusScreen({super.key, required this.collegeId});

  @override
  State<ChatCampusScreen> createState() => _ChatCampusScreenState();
}

class _ChatCampusScreenState extends State<ChatCampusScreen> {
  final TextEditingController _chatController = TextEditingController();
  bool _isPosting = false;

  Future<void> _sendChat() async {
    if (_chatController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch extra profile info
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final profileData = userDoc.data() ?? {};

      // Pick best available profile picture field
      final profilePic = (profileData['profilePic'] ??
          profileData['profilePicUrl'] ??
          (profileData['profilePics'] is List &&
              (profileData['profilePics'] as List).isNotEmpty
              ? profileData['profilePics'][0]
              : '')) ??
          '';

      final message = {
        'chatId': FirebaseFirestore.instance.collection('dummy').doc().id,
        'text': _chatController.text.trim(),
        'userId': user.uid,
        'username': profileData['username'] ?? user.displayName ?? 'Anonymous',
        'profilePic': profilePic,
        'collegeId': widget.collegeId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'chat',
      };

      await FirebaseFirestore.instance
          .collection('campusChats')
          .doc(widget.collegeId)
          .collection('messages')
          .add(message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Chat uploaded successfully!")),
        );
      }

      _chatController.clear();
      Navigator.pop(context); // close after posting
    } catch (e) {
      debugPrint('Error sending chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send chat: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "New Campus Chat",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              /// Big text input card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, height: 1.4),
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      hintText: "Write your message to campus...",
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 16),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// Preview card
              if (_chatController.text.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chat_bubble, color: Colors.blue, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _chatController.text.trim(),
                          style: const TextStyle(
                              fontSize: 15, color: Colors.black87, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

              /// Upload button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _sendChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                      : const Text(
                    "Upload Chat",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
