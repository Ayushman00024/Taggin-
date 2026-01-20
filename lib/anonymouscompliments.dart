import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A screen for sending anonymous compliments
class ComplimentScreen extends StatelessWidget {
  final String targetUserId; // 👤 Recipient of compliment
  final String? postId; // 📝 Optional postId (if compliment is for a post)

  const ComplimentScreen({
    Key? key,
    required this.targetUserId,
    this.postId,
  }) : super(key: key);

  /// 🔥 Predefined compliments
  static const List<String> compliments = [
    // Profile compliments
    "🌟 Cutest nearby",
    "😁 That smile",
    "👀 Definitely one of the most noticed here",
    "🤝 You give positive vibes",
    "✨ Aesthetic energy",
    "🌸 Looking awesome today",

    // Post compliments
    "😊 That smile",
    "💪 Fit goals",
    "🔥 Slaying",
    "🌸 Cutesy",
    "✨ You light up the feed",
  ];

  Future<void> _sendCompliment(BuildContext context, String compliment) async {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to send compliments")),
      );
      return;
    }

    final isPost = postId != null;

    try {
      await FirebaseFirestore.instance.collection('compliments').add({
        'toUserId': targetUserId,
        'fromUserId': myId,
        'compliment': compliment,
        'anonymous': true,
        'type': isPost ? 'postCompliment' : 'profileCompliment',
        if (isPost) 'postId': postId,
        'message': isPost
            ? "someone complimented your post: $compliment"
            : "someone complimented you: $compliment",
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Compliment sent 💌",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.pinkAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      debugPrint('[ComplimentScreen] failed: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send compliment"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPost = postId != null;

    return Scaffold(
      backgroundColor: Colors.black, // 🌑 Dark background
      appBar: AppBar(
        title: Text(
          isPost ? "Compliment this Post" : "Send a Compliment",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.pinkAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              // 🩷 Top white text
              const Text(
                "Send Anonymous Compliment 💌",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Compliment chips
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: compliments.map((text) {
                  return GestureDetector(
                    onTap: () => _sendCompliment(context, text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent.withOpacity(0.2),
                        border: Border.all(color: Colors.pinkAccent, width: 1.2),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pinkAccent.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
