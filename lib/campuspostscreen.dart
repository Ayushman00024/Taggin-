// lib/campuspostscreen.dart (🎓 Campus Feed styled like Global Posts)
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import 'profilescreenui.dart';
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

class CampusPostScreen extends StatefulWidget {
  const CampusPostScreen({Key? key}) : super(key: key);

  @override
  State<CampusPostScreen> createState() => _CampusPostScreenState();

  static void scrollToTop() {
    _CampusPostScreenState.scrollToTop();
  }
}

class _CampusPostScreenState extends State<CampusPostScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  static _CampusPostScreenState? _instance;
  String? _myUid;
  String? _mySelectedCollege;
  bool _loading = true;
  List<Map<String, dynamic>> _feedItems = [];

  @override
  void initState() {
    super.initState();
    _instance = this;
    _loadAndFetch();
  }

  static void scrollToTop() {
    if (_instance != null && _instance!._scrollController.hasClients) {
      _instance!._scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _instance = null;
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAndFetch() async {
    setState(() {
      _loading = true;
      _feedItems.clear();
    });

    try {
      final u = _auth.currentUser;
      _myUid = u?.uid;
      if (_myUid == null) {
        setState(() => _loading = false);
        return;
      }

      final doc = await _fire.collection('users').doc(_myUid).get();
      _mySelectedCollege =
          (doc.data()?['selectedCollege'] ?? '').toString().trim().toUpperCase();

      if (_mySelectedCollege == null || _mySelectedCollege!.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final usersSnap = await _fire
          .collection('users')
          .where('selectedCollege', isEqualTo: _mySelectedCollege)
          .get();

      final userIds =
      usersSnap.docs.map((d) => d.id).where((id) => id != _myUid).toList();

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> postDocs = [];
      for (int i = 0; i < userIds.length; i += 10) {
        final batch = userIds.sublist(
          i,
          i + 10 > userIds.length ? userIds.length : i + 10,
        );
        final snap =
        await _fire.collection('posts').where('userId', whereIn: batch).get();
        postDocs.addAll(snap.docs);
      }

      final Map<String, Map<String, dynamic>> latestPerUser = {};
      for (final d in postDocs) {
        final data = d.data();
        final uid = (data['userId'] ?? '').toString();
        final ts = data['timestamp'] as Timestamp?;
        if (uid.isEmpty || ts == null) continue;

        final enriched = {...data, 'postId': d.id, 'type': 'post'};

        final existing = latestPerUser[uid];
        if (existing == null ||
            ts.compareTo(existing['timestamp'] as Timestamp) > 0) {
          latestPerUser[uid] = enriched;
        }
      }

      final posts = latestPerUser.values.toList();
      posts.sort((a, b) {
        final at = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bt = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bt.compareTo(at);
      });

      setState(() {
        _feedItems = posts.take(25).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading feed: $e');
      setState(() => _loading = false);
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreenUI(),
        settings: RouteSettings(arguments: {'userId': userId}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noCollege = _mySelectedCollege == null || _mySelectedCollege!.isEmpty;

    return Scaffold(
      backgroundColor: _TagginColors.bg,
      body: RefreshIndicator(
        onRefresh: _loadAndFetch,
        color: _TagginColors.primary,
        backgroundColor: _TagginColors.bg,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: _TagginColors.bg,
              floating: true,
              snap: true,
              elevation: 0,
              centerTitle: true,
              title: Text(
                "Students Network",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _TagginColors.text,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _TagginColors.accent),
                ),
              )
            else if (noCollege)
              const SliverFillRemaining(child: _AddCollegeState())
            else if (_feedItems.isEmpty)
                const SliverFillRemaining(child: _EmptyState())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      final item = _feedItems[i];
                      return _DarkCard(
                        child: _PostCard(
                          userId: (item['userId'] ?? '').toString(),
                          username: (item['username'] ?? 'No Name').toString(),
                          selectedCollege:
                          (item['selectedCollege'] ?? '').toString(),
                          caption: (item['caption'] ?? '').toString(),
                          mediaUrl: (item['mediaUrl'] ?? '').toString(),
                          profilePic: (item['profilePic'] ?? '').toString(),
                          postId: (item['postId'] ?? '').toString(),
                          onOpenProfile: _openProfile,
                          currentUserId: _myUid ?? '',
                        ),
                      );
                    },
                    childCount: _feedItems.length,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AddCollegeState extends StatelessWidget {
  const _AddCollegeState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_rounded,
                color: _TagginColors.primary, size: 70),
            const SizedBox(height: 20),
            const Text(
              "Add Your College 🎓",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _TagginColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "To view students and campus posts, please select your college in Edit Profile.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _TagginColors.subtext,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _TagginColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/editProfile');
              },
              icon: const Icon(Icons.edit_rounded, color: Colors.black87),
              label: const Text(
                "Go to Edit Profile",
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          "No posts available yet.\nStart a conversation with your campus community!",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _TagginColors.subtext,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String userId;
  final String username;
  final String selectedCollege;
  final String caption;
  final String mediaUrl;
  final String profilePic;
  final String postId;
  final void Function(String userId) onOpenProfile;
  final String currentUserId;

  const _PostCard({
    required this.userId,
    required this.username,
    required this.selectedCollege,
    required this.caption,
    required this.mediaUrl,
    required this.profilePic,
    required this.postId,
    required this.onOpenProfile,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final showComplimentBtn = userId.isNotEmpty && userId != currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => onOpenProfile(userId),
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: profilePic.isNotEmpty
                      ? CachedNetworkImageProvider(profilePic)
                      : null,
                  backgroundColor: Colors.grey[800],
                  child: profilePic.isEmpty
                      ? const Icon(Icons.person,
                      size: 22, color: Colors.white)
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
                    if (selectedCollege.isNotEmpty)
                      Text(selectedCollege,
                          style: const TextStyle(
                              color: _TagginColors.subtext, fontSize: 13)),
                  ],
                ),
              ),
              AddFriendButton(otherUserId: userId, mini: true),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Image with gradient
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: mediaUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (ctx, url) => SizedBox(
                  height: 350,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: _TagginColors.accent, strokeWidth: 2.6),
                  ),
                ),
                errorWidget: (ctx, url, err) => Container(
                  height: 350,
                  color: Colors.grey[900],
                  child: const Center(
                      child: Icon(Icons.broken_image,
                          size: 60, color: Colors.white38)),
                ),
              ),
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
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Actions bar with blur
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withOpacity(0.05),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            builder: (_) =>
                                ComplimentScreen(targetUserId: userId, postId: postId),
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
                  final isTag = word.startsWith('#') || word.startsWith('@');
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
    );
  }
}

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
