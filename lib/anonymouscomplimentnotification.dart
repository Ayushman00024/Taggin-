import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AnonymousComplimentNotification extends StatefulWidget {
  const AnonymousComplimentNotification({Key? key}) : super(key: key);

  @override
  State<AnonymousComplimentNotification> createState() =>
      _AnonymousComplimentNotificationState();
}

class _AnonymousComplimentNotificationState
    extends State<AnonymousComplimentNotification> {
  final _auth = FirebaseAuth.instance;

  Future<void> _deleteCompliment(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('compliments')
          .doc(id)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Compliment deleted"),
          backgroundColor: Colors.pinkAccent,
        ),
      );
    } catch (e) {
      debugPrint('Error deleting compliment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to delete compliment"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            'Please log in to view compliments',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Anonymous Compliments 💌',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.pinkAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('compliments')
            .where('toUserId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                "Error loading compliments 😕",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.pinkAccent),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No compliments yet 😶",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final compliments = List.from(docs)
            ..sort((a, b) {
              final aTime =
              (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final bTime =
              (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final aDate = aTime?.toDate();
              final bDate = bTime?.toDate();
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: compliments.length,
            itemBuilder: (context, index) {
              final doc = compliments[index];
              final data = doc.data() as Map<String, dynamic>;
              final message = data['message'] ?? 'Anonymous compliment 💬';
              final compliment = data['compliment'] ?? '';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final formattedTime = timestamp != null
                  ? DateFormat('MMM d, h:mm a').format(timestamp)
                  : 'Just now';

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart, // 👈 Swipe left to delete
                background: Container(
                  alignment: Alignment.centerRight, // 👈 Delete icon on right
                  padding: const EdgeInsets.only(right: 24),
                  color: Colors.redAccent.withOpacity(0.8),
                  child: const Icon(Icons.delete, color: Colors.white, size: 26),
                ),
                onDismissed: (_) => _deleteCompliment(doc.id),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                    Border.all(color: Colors.pinkAccent.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pinkAccent.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.favorite, color: Colors.pinkAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (compliment.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                compliment,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
