// lib/mycampuschat.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyCampusChat extends StatefulWidget {
  final String userId;    // ✅ who owns the profile
  final String collegeId; // ✅ which college to fetch from

  const MyCampusChat({
    super.key,
    required this.userId,
    required this.collegeId,
  });

  @override
  State<MyCampusChat> createState() => _MyCampusChatState();
}

class _MyCampusChatState extends State<MyCampusChat> {
  bool _fallbackMode = false; // ✅ if true, skip orderBy

  Stream<QuerySnapshot> _chatStream() {
    final baseQuery = FirebaseFirestore.instance
        .collection('campusChats')
        .doc(widget.collegeId)
        .collection('messages')
        .where('userId', isEqualTo: widget.userId);

    // ✅ fallback removes orderBy if index not ready
    if (_fallbackMode) {
      return baseQuery.snapshots();
    } else {
      return baseQuery.orderBy('timestamp', descending: true).snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final errMsg = snapshot.error.toString();

          // 🔥 detect Firestore missing index error
          if (errMsg.contains("FAILED_PRECONDITION") ||
              errMsg.contains("requires an index")) {
            // switch to fallback mode
            Future.microtask(() {
              if (!_fallbackMode) {
                setState(() => _fallbackMode = true);
              }
            });
            return const Center(
              child: Text(
                "Index is still building… showing unsorted chats.",
                style: TextStyle(color: Colors.orange, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Error loading chats:\n$errMsg",
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No campus chats yet.",
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final msg = docs[index].data() as Map<String, dynamic>? ?? {};
            final text = (msg['text'] ?? '').toString();
            final username = (msg['username'] ?? 'Unknown').toString();
            final profilePic = (msg['profilePic'] ?? '').toString();
            final timestamp = (msg['timestamp'] as Timestamp?)?.toDate();

            final timeStr = timestamp != null
                ? "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}"
                : "";

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundImage: profilePic.isNotEmpty
                        ? NetworkImage(profilePic)
                        : null,
                    backgroundColor: Colors.blue.shade200,
                    child: profilePic.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(text,
                            style: const TextStyle(
                                fontSize: 15, color: Colors.black87)),
                        if (timeStr.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              timeStr,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black54),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
