import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendSectionMessages extends StatelessWidget {
  const FriendSectionMessages({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final sentStream = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('status', isEqualTo: 'accepted')
        .where('senderId', isEqualTo: userId)
        .snapshots();

    final receivedStream = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('status', isEqualTo: 'accepted')
        .where('receiverId', isEqualTo: userId)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Messages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: sentStream,
        builder: (context, sentSnapshot) {
          if (!sentSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: receivedStream,
            builder: (context, receivedSnapshot) {
              if (!receivedSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final friendIds = <String>{};
              for (var doc in sentSnapshot.data!.docs) {
                friendIds.add((doc.data() as Map<String, dynamic>)['receiverId']);
              }
              for (var doc in receivedSnapshot.data!.docs) {
                friendIds.add((doc.data() as Map<String, dynamic>)['senderId']);
              }

              if (friendIds.isEmpty) {
                return Center(
                  child: Text(
                    "No messages yet!\nAdd friends to start chatting.",
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.only(top: 12, bottom: 18),
                children: friendIds.map((friendId) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(friendId)
                        .get(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData || !userSnap.data!.exists) {
                        return SizedBox();
                      }
                      final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                      final name = userData['name'] ?? userData['username'] ?? 'User';
                      final profilePic = userData['profilePicUrl'] ?? userData['profilePic'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            // TODO: Open chat with friendId
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Open chat with $name')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: profilePic.isNotEmpty
                                      ? NetworkImage(profilePic)
                                      : null,
                                  backgroundColor: Colors.grey[800],
                                  radius: 30,
                                  child: profilePic.isEmpty
                                      ? Icon(Icons.person, color: Colors.white, size: 28)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Tap to chat",
                                        style: TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.white38)
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
