import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'add_friend_button.dart';
import 'explorepostclickable.dart';
import 'likehome.dart';
import 'commenthome.dart';
import 'anonymouscompliments.dart'; // 🎁 Import compliments button

class _TagginColors {
  static const bg = Colors.white; // Light background
  static const card = Color(0xFFF9FAFB); // Soft gray-white card
  static const primary = Color(0xFF2B6CB0); // Blue
  static const accent = Color(0xFF38BDF8); // Cyan
  static const text = Color(0xFF1A1A1A); // Dark text
  static const subtext = Color(0xFF6B7280); // Medium gray
}

class CityPosts extends StatefulWidget {
  final String city;
  const CityPosts({Key? key, required this.city}) : super(key: key);

  @override
  State<CityPosts> createState() => _CityPostsState();

  // ✅ For sliver embedding
  static Widget sliver({Key? key, required String city}) {
    return CityPosts(key: key, city: city);
  }
}

class _CityPostsState extends State<CityPosts> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _posts.clear();
    });

    try {
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('city', isEqualTo: widget.city)
          .get();

      final userDocs =
      usersSnap.docs.where((d) => d.id != _currentUserId).toList();
      if (userDocs.isEmpty) {
        setState(() {
          _loading = false;
          _posts = [];
        });
        return;
      }

      final userIds = userDocs.map((d) => d.id).toList();

      final List<List<String>> chunks = [];
      for (int i = 0; i < userIds.length; i += 10) {
        chunks.add(userIds.sublist(
            i, i + 10 > userIds.length ? userIds.length : i + 10));
      }

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> postDocs = [];
      for (final batch in chunks) {
        final snap = await FirebaseFirestore.instance
            .collection('posts')
            .where('userId', whereIn: batch)
            .get();
        postDocs.addAll(snap.docs);
      }

      final Map<String, Map<String, dynamic>> latestPerUser = {};
      for (final d in postDocs) {
        final data = d.data();
        final uid = (data['userId'] ?? '') as String;
        final ts = data['timestamp'] as Timestamp?;
        if (uid.isEmpty || ts == null) continue;

        final enriched = {
          ...data,
          'postId': d.id,
        };

        final existing = latestPerUser[uid];
        if (existing == null ||
            ts.compareTo(existing['timestamp'] as Timestamp) > 0) {
          latestPerUser[uid] = enriched;
        }
      }

      final List<Map<String, dynamic>> withUser = [];
      for (final entry in latestPerUser.entries) {
        final uid = entry.key;
        final post = Map<String, dynamic>.from(entry.value);

        final uDoc = userDocs.firstWhere((d) => d.id == uid,
            orElse: () => throw StateError('user not found'));
        final u = uDoc.data();

        post['userId'] = uid;
        post['username'] = u['username'] ?? 'No Name';
        post['profilePic'] = u['profilePic'] ?? '';
        post['city'] = u['city'] ?? widget.city;
        post['college'] = u['college'] ?? '';

        withUser.add(post);
      }

      withUser.sort((a, b) {
        final at = a['timestamp'] as Timestamp?;
        final bt = b['timestamp'] as Timestamp?;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

      final top = withUser.length > 25 ? withUser.sublist(0, 25) : withUser;

      setState(() {
        _posts = top;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load posts';
        _loading = false;
      });
    }
  }

  void _openPost(Map<String, dynamic> post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: _TagginColors.bg,
            iconTheme: const IconThemeData(color: _TagginColors.text),
            titleTextStyle: const TextStyle(
                color: _TagginColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600),
            title: Text((post['username'] ?? 'Post').toString()),
          ),
          backgroundColor: _TagginColors.bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: ExplorePostClickable(post: post),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 24),
          child: Center(
              child: CircularProgressIndicator(color: _TagginColors.accent)),
        ),
      );
    }
    if (_error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
              child:
              Text(_error!, style: const TextStyle(color: Colors.redAccent))),
        ),
      );
    }
    if (_posts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
              child: Text('No posts yet',
                  style: TextStyle(color: _TagginColors.subtext))),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, i) {
          final p = _posts[i];
          final username = (p['username'] ?? 'No Name').toString();
          final profilePic = (p['profilePic'] ?? '').toString();
          final caption = (p['caption'] ?? '').toString();
          final type = (p['type'] ?? 'image').toString();
          final userId = (p['userId'] ?? '').toString();
          final postId = (p['postId'] ?? '').toString();
          final college = (p['college'] ?? '').toString();
          final image = (p['thumbnailUrl'] ?? '').toString().isNotEmpty
              ? p['thumbnailUrl'].toString()
              : (p['mediaUrl'] ?? '').toString();

          if (image.isEmpty || postId.isEmpty) {
            return const SizedBox.shrink();
          }

          final showFriendBtn = userId.isNotEmpty && userId != _currentUserId;
          final showComplimentBtn =
              userId.isNotEmpty && userId != _currentUserId; // 👈 only others

          return _LightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Instagram style header ---
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/profile',
                          arguments: {'userId': userId},
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: profilePic.isNotEmpty
                              ? CachedNetworkImageProvider(profilePic)
                              : null,
                          backgroundColor: Colors.grey[300],
                          child: profilePic.isEmpty
                              ? const Icon(Icons.person,
                              size: 22, color: Colors.black45)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(username,
                                style: const TextStyle(
                                    color: _TagginColors.text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                            if (college.isNotEmpty)
                              Text(
                                college,
                                style: const TextStyle(
                                    color: _TagginColors.subtext, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                          ],
                        ),
                      ),
                      if (showFriendBtn)
                        AddFriendButton(otherUserId: userId, mini: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // --- Media content ---
                if (type == 'video')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28.0),
                    child: Center(
                      child: Text('Video posts not supported yet',
                          style: TextStyle(
                              color: _TagginColors.subtext, fontSize: 14)),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: image,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => SizedBox(
                            height: 350,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: _TagginColors.accent,
                                strokeWidth: 2.6,
                              ),
                            ),
                          ),
                          errorWidget: (ctx, url, err) => Container(
                            height: 350,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image,
                                  size: 60, color: Colors.black45),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(onTap: () => _openPost(p)),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      LikeHome(
                          postId: postId,
                          iconColor: Colors.black87,
                          textColor: Colors.black54),
                      const SizedBox(width: 22),
                      CommentHome(
                          postId: postId,
                          iconColor: Colors.black87,
                          textColor: Colors.black54),
                      const SizedBox(width: 22),
                      if (showComplimentBtn)
                        AnonymousCompliments(
                          targetUserId: userId,
                        ), // 🎁 gift-style button
                    ],
                  ),
                ),
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 8, right: 8),
                    child: Text(caption,
                        style: const TextStyle(
                            color: _TagginColors.text,
                            fontSize: 15,
                            height: 1.4)),
                  ),
              ],
            ),
          );
        },
        childCount: _posts.length,
      ),
    );
  }
}

class _LightCard extends StatelessWidget {
  final Widget child;
  const _LightCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _TagginColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}
