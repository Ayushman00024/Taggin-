import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ComplimentProfile
/// Button that opens a bottom sheet for profile compliments.
class ComplimentProfile extends StatelessWidget {
  final String targetUserId; // 👤 The profile owner
  final double iconSize;
  final Color iconColor;

  const ComplimentProfile({
    Key? key,
    required this.targetUserId,
    this.iconSize = 22,
    this.iconColor = Colors.pinkAccent,
  }) : super(key: key);

  static const List<String> compliments = [
    "🌟 Cutest nearby",
    "😁 That smile",
    "👀 Definitely one of the most noticed here",
  ];

  Future<void> _sendCompliment(BuildContext context, String compliment) async {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    if (myId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to send compliments")),
      );
      return;
    }

    try {
      // ✅ Save into unified compliments collection
      await FirebaseFirestore.instance.collection('compliments').add({
        'toUserId': targetUserId,
        'fromUserId': myId,
        'compliment': compliment,
        'anonymous': true,
        'unread': true,
        'type': 'profileCompliment', // differentiate from postCompliment
        'message': "someone complimented you: $compliment",
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Compliment sent: $compliment")),
      );
    } catch (e, st) {
      debugPrint('[ComplimentProfile] failed: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send compliment")),
      );
    }
  }

  void _showComplimentsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  "Send a Compliment",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: compliments.map((c) {
                    return GestureDetector(
                      onTap: () => _sendCompliment(ctx, c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent.withOpacity(0.1),
                          border: Border.all(color: Colors.pinkAccent, width: 1.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          c,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _showComplimentsBottomSheet(context),
      icon: Icon(Icons.card_giftcard, size: iconSize, color: iconColor),
      label: Text(
        "Compliment",
        style: TextStyle(color: iconColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
