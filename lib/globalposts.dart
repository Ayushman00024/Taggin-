// lib/globalposts.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'add_friend_button.dart';
import 'likehome.dart';
import 'commenthome.dart';
import 'anonymouscompliments.dart';

class _TagginColors {
  static const bg = Color(0xFF0D0D0D);
  static const card = Color(0xFF1A1A1A);
  static const primary = Color(0xFF38BDF8);
  static const accent = Color(0xFFFF4081);
  static const text = Color(0xFFEAEAEA);
  static const subtext = Color(0xFF9CA3AF);
}

class GlobalPosts extends StatefulWidget {
  const GlobalPosts({Key? key}) : super(key: key);

  @override
  State<GlobalPosts> createState() => _GlobalPostsState();

  static Widget sliver({Key? key}) {
    return GlobalPosts(key: key);
  }
}

class _GlobalPostsState extends State<GlobalPosts> {
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
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();

      final docs = snap.docs;
      final Map<String, Map<String, dynamic>> latestPerUser = {};

      for (final d in docs) {
        final data = d.data();
        final uid = (data['userId'] ?? '') as String;
        if (uid.isEmpty || uid == _currentUserId) continue;
        if (latestPerUser.containsKey(uid)) continue;

        final uDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (!uDoc.exists) continue;
        final u = uDoc.data() ?? {};

        final username = (u['username'] ?? '').toString().trim();
        if (username.isEmpty) continue;

        final ts = data['timestamp'] as Timestamp?;
        if (ts == null) continue;

        final post = {
          ...data,
          'postId': d.id,
          'userId': uid,
          'username': username,
          'profilePic': u['profilePic'] ?? '',
          'city': u['city'] ?? '',
          'college': u['college'] ?? '',
          'timestamp': ts,
        };

        latestPerUser[uid] = post;
      }

      final sortedPosts = latestPerUser.values.toList()
        ..sort((a, b) {
          final at = a['timestamp'] as Timestamp?;
          final bt = b['timestamp'] as Timestamp?;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });

      final top =
      sortedPosts.length > 40 ? sortedPosts.sublist(0, 40) : sortedPosts;

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 24),
          child: Center(
            child: CircularProgressIndicator(color: _TagginColors.accent),
          ),
        ),
      );
    }
    if (_error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Failed to load posts',
              style: TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          ),
        ),
      );
    }
    if (_posts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text('No posts yet',
                style: TextStyle(color: _TagginColors.subtext)),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, i) => _buildPostCard(_posts[i]),
        childCount: _posts.length,
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> p) {
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

    if (image.isEmpty || postId.isEmpty) return const SizedBox.shrink();

    final showFriendBtn = userId.isNotEmpty && userId != _currentUserId;
    final showComplimentBtn = userId.isNotEmpty && userId != _currentUserId;

    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
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
                    backgroundColor: Colors.grey[800],
                    child: profilePic.isEmpty
                        ? const Icon(Icons.person, size: 22, color: Colors.white)
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

          // Post Image (non-clickable now)
          if (type == 'video')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28.0),
              child: Center(
                child: Text('Video posts not supported yet',
                    style:
                    TextStyle(color: _TagginColors.subtext, fontSize: 14)),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
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
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(Icons.broken_image,
                            size: 60, color: Colors.white38),
                      ),
                    ),
                  ),
                  // gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  if (college.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Text(
                          college.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // Like/Comment/Compliment bar
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.white.withOpacity(0.05),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    LikeHome(
                        postId: postId,
                        iconColor: _TagginColors.primary,
                        textColor: Colors.white70),
                    CommentHome(
                        postId: postId,
                        iconColor: _TagginColors.accent,
                        textColor: Colors.white70),
                    if (showComplimentBtn)
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ComplimentScreen(
                                targetUserId: userId,
                                postId: postId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.card_giftcard,
                            color: Colors.amberAccent),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (caption.isNotEmpty)
            Padding(
              padding:
              const EdgeInsets.only(top: 10, left: 8, right: 8, bottom: 6),
              child: RichText(
                text: TextSpan(
                  children: caption.split(' ').map((word) {
                    final isTag =
                        word.startsWith('#') || word.startsWith('@');
                    return TextSpan(
                      text: '$word ',
                      style: TextStyle(
                        color: isTag
                            ? _TagginColors.primary
                            : _TagginColors.text,
                        fontWeight:
                        isTag ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ✨ Animated Card
class _DarkCard extends StatefulWidget {
  final Widget child;
  const _DarkCard({required this.child});

  @override
  State<_DarkCard> createState() => _DarkCardState();
}

class _DarkCardState extends State<_DarkCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1C1C1C), Color(0xFF121212)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.05),
                blurRadius: 30,
                spreadRadius: -10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: widget.child,
        ),
      ),
    );
  }
}
