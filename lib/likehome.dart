import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ import your profile screen
import 'profilescreenui.dart';

class LikeHome extends StatefulWidget {
  final String postId;
  final double iconSize;
  final Color iconColor;
  final Color textColor;

  const LikeHome({
    Key? key,
    required this.postId,
    this.iconSize = 26,
    this.iconColor = Colors.white,
    this.textColor = Colors.white70,
  }) : super(key: key);

  @override
  State<LikeHome> createState() => _LikeHomeState();
}

class _LikeHomeState extends State<LikeHome> {
  final _auth = FirebaseAuth.instance;
  bool _liked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _seedLiked();
  }

  Future<void> _seedLiked() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _liked = false;
        _loading = false;
      });
      return;
    }
    try {
      final likeRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('likes')
          .doc(uid);
      final snap = await likeRef.get();
      setState(() {
        _liked = snap.exists;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final postRef =
    FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final likeRef = postRef.collection('likes').doc(uid);

    setState(() => _liked = !_liked); // optimistic

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likesCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {
          'userId': uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {'likesCount': FieldValue.increment(1)});
      }
    }).catchError((_) {
      setState(() => _liked = !_liked); // revert
    });
  }

  void _showLikesDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final likesRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('likes')
            .orderBy('timestamp', descending: true);

        return StreamBuilder<QuerySnapshot>(
          stream: likesRef.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text("No likes yet"));
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final userId = data['userId'] ?? "Unknown";

                // 🔑 Fetch user data from /users/{userId}
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get(),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) {
                      return const ListTile(
                        leading: CircularProgressIndicator(),
                        title: Text("Loading..."),
                      );
                    }

                    final userData =
                    userSnap.data!.data() as Map<String, dynamic>?;

                    final username = userData?['username'] ?? userId;
                    final profilePic = userData?['profilePic'] ??
                        "https://via.placeholder.com/150";

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(profilePic),
                      ),
                      title: Text(username),
                      onTap: () {
                        // 🚀 Navigate to Profile Screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreenUI(),
                            settings:
                            RouteSettings(arguments: {'userId': userId}),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final postRef =
    FirebaseFirestore.instance.collection('posts').doc(widget.postId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: postRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          // ✅ Show placeholder while waiting
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _liked ? Icons.favorite : Icons.favorite_border,
                size: widget.iconSize,
                color: _liked ? Colors.redAccent : widget.iconColor,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showLikesDialog,
                child: Text(
                  "0",
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          );
        }

        final doc = snap.data;
        final map = (doc != null && doc.exists) ? doc.data() : null;
        final likes = (map?['likesCount'] ?? 0) as int;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: _loading ? null : _toggleLike,
              icon: Icon(
                _liked ? Icons.favorite : Icons.favorite_border,
                size: widget.iconSize,
                color: _liked ? Colors.redAccent : widget.iconColor,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _showLikesDialog, // ✅ Always clickable
              child: Text(
                likes.toString(),
                style: TextStyle(
                  color: widget.textColor,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
