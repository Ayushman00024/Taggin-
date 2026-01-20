// lib/likeprofile.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ Import profile screen
import 'profilescreenui.dart';

class LikeProfile extends StatefulWidget {
  final String profileUserId; // Whose profile is being viewed
  final double iconSize;
  final Color textColor;

  const LikeProfile({
    Key? key,
    required this.profileUserId,
    this.iconSize = 26,
    this.textColor = Colors.black87,
  }) : super(key: key);

  @override
  State<LikeProfile> createState() => _LikeProfileState();
}

class _LikeProfileState extends State<LikeProfile> {
  final _auth = FirebaseAuth.instance;

  CollectionReference get likesRef => FirebaseFirestore.instance
      .collection('profiles')
      .doc(widget.profileUserId)
      .collection('likes');

  // ✅ Toggle like system
  Future<void> _toggleLike(String type) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final likeDoc = likesRef.doc(uid);
    final snap = await likeDoc.get();
    bool added = false;

    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      List<String> types = List<String>.from(data['types'] ?? []);

      if (types.contains(type)) {
        types.remove(type);
        if (types.isEmpty) {
          await likeDoc.delete();
        } else {
          await likeDoc.set({'userId': uid, 'types': types},
              SetOptions(merge: true));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You unliked the profile 💔"),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
        return;
      } else {
        if (types.length >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You can only give 3 likes total")),
          );
          return;
        }
        types.add(type);
        added = true;
        await likeDoc.set({'userId': uid, 'types': types},
            SetOptions(merge: true));
      }
    } else {
      await likeDoc.set({'userId': uid, 'types': [type]});
      added = true;
    }

    if (added) {
      String message = "";
      if (type == "like") message = "You liked the profile ❤️";
      else if (type == "star") message = "You star liked the profile ⭐";
      else if (type == "super") message = "You super liked the profile 🔥";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 15)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showLikesDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final likesStream = likesRef.snapshots();

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const Text(
                  "Profile Likes",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: likesStream,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(child: Text("No likes yet"));
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final userId = data['userId'];
                          final types = List<String>.from(data['types'] ?? []);

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData) {
                                return const ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey,
                                  ),
                                  title: Text("Loading..."),
                                );
                              }

                              final userData =
                              userSnap.data!.data() as Map<String, dynamic>?;
                              final username = userData?['username'] ?? userId;
                              final profilePic = userData?['profilePic'] ??
                                  "https://via.placeholder.com/150";

                              final typeIcons = types.map((t) {
                                switch (t) {
                                  case "like":
                                    return "❤️";
                                  case "star":
                                    return "⭐";
                                  case "super":
                                    return "🔥";
                                  default:
                                    return "👍";
                                }
                              }).join("  ");

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(profilePic),
                                  radius: 24,
                                ),
                                title: Text(
                                  username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  typeIcons,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ProfileScreenUI(),
                                      settings: RouteSettings(
                                          arguments: {'userId': userId}),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: likesRef.snapshots(),
      builder: (context, snap) {
        int totalLikes = 0;
        if (snap.hasData) {
          for (var doc in snap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalLikes += (data['types'] as List).length;
          }
        }

        final isOwnProfile = currentUid == widget.profileUserId;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  iconSize: widget.iconSize,
                  onPressed: () => _toggleLike("like"),
                ),
                IconButton(
                  icon: const Icon(Icons.star, color: Colors.amber),
                  iconSize: widget.iconSize,
                  onPressed: () => _toggleLike("star"),
                ),
                IconButton(
                  icon: const Icon(Icons.whatshot, color: Colors.deepOrange),
                  iconSize: widget.iconSize,
                  onPressed: () => _toggleLike("super"),
                ),
              ],
            ),

            // ✅ Only clickable for own profile
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: isOwnProfile ? _showLikesDialog : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Text(
                      "$totalLikes Likes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.textColor,
                        fontSize: 16,
                        decoration:
                        isOwnProfile ? TextDecoration.underline : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
