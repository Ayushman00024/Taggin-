import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'editprofilescreen.dart';
import 'settings.dart';
import 'myposts.dart';
import 'likeprofile.dart';
import 'anonymouscompliments.dart';
import 'profilevisit.dart'; // ✅ new once-per-day visit logic

class TagginColors {
  static const bg = Color(0xFF000000);
  static const cardGlass = Color(0xFF121212);
  static const primary = Colors.white;
  static const accent = Colors.white;
  static const text = Colors.white;
  static const subtext = Colors.white70;
  static const divider = Colors.white24;
}

class ProfileScreenUI extends StatefulWidget {
  const ProfileScreenUI({Key? key}) : super(key: key);

  @override
  State<ProfileScreenUI> createState() => _ProfileScreenUIState();
}

class _ProfileScreenUIState extends State<ProfileScreenUI> {
  bool _visitRecorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleProfileVisit());
  }

  Future<void> _handleProfileVisit() async {
    if (_visitRecorded) return;

    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final argUserId =
    args != null && args['userId'] != null ? args['userId'] as String : null;

    final viewedUserId = argUserId ?? currentUid;
    final isOwnProfile = (viewedUserId == currentUid);

    if (!isOwnProfile && viewedUserId.isNotEmpty) {
      _visitRecorded = true;
      await ProfileVisitTracker.recordVisit(viewedUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final argUserId =
    args != null && args['userId'] != null ? args['userId'] as String : null;
    final viewedUserId = argUserId ?? currentUid ?? '';
    final isOwnProfile = (viewedUserId == currentUid);

    return Scaffold(
      backgroundColor: TagginColors.bg,
      appBar: AppBar(
        backgroundColor: TagginColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        centerTitle: true,
        title: Text(
          isOwnProfile ? 'Profile' : '',
          style: const TextStyle(
            color: TagginColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: TagginColors.primary),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: TagginColors.primary),
              tooltip: 'Edit Profile',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
            ),
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.menu, color: TagginColors.primary),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _buildProfile(context, viewedUserId, isOwnProfile),
      ),
    );
  }

  // ==================== Helpers ====================

  String _vFromData(Map<String, dynamic> data) {
    final v = data['pfpUpdatedAt'] ?? data['updatedAt'] ?? data['lastUpdated'];
    if (v == null) return '';
    try {
      final ms = (v is Timestamp)
          ? v.millisecondsSinceEpoch
          : DateTime.tryParse(v.toString())?.millisecondsSinceEpoch;
      return ms?.toString() ?? v.toString();
    } catch (_) {
      return v.toString();
    }
  }

  String _withCacheBuster(String url, Map<String, dynamic> data) {
    final v = _vFromData(data);
    if (v.isEmpty) return url;
    return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
  }

  String? _firstNonEmpty(Iterable<dynamic> vals) {
    for (final v in vals) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  String? _extractRawPfp(Map<String, dynamic> data) {
    final flat = _firstNonEmpty([
      data['profilePicUrl'],
      data['profilePicURL'],
      data['profilePic'],
      data['photoURL'],
      data['photoUrl'],
      data['avatar'],
      data['avatarURL'],
      data['avatarUrl'],
      data['pfp'],
      data['pfpURL'],
      data['pfpUrl'],
    ]);
    if (flat != null) return flat;

    final profile = data['profile'];
    if (profile is Map) {
      final nested = _firstNonEmpty([
        profile['photoURL'],
        profile['photoUrl'],
        profile['avatar'],
        profile['avatarUrl'],
        profile['pfp'],
        profile['pfpUrl'],
      ]);
      if (nested != null) return nested;
    }

    final pics = data['profilePics'];
    if (pics is List && pics.isNotEmpty) {
      for (final item in pics) {
        if (item is String && item.trim().isNotEmpty) return item.trim();
        if (item is Map) {
          final fromMap = _firstNonEmpty([
            item['url'],
            item['downloadURL'],
            item['downloadUrl'],
            item['src'],
          ]);
          if (fromMap != null) return fromMap;
        }
      }
    }
    return null;
  }

  Future<String> _toHttpsUrl(String raw) async {
    try {
      final s = raw.trim();
      if (s.startsWith('http://') || s.startsWith('https://')) return s;
      if (s.startsWith('gs://')) {
        return FirebaseStorage.instance.refFromURL(s).getDownloadURL();
      }
      final cleaned = s.startsWith('/') ? s.substring(1) : s;
      return FirebaseStorage.instance.ref(cleaned).getDownloadURL();
    } catch (e) {
      debugPrint('[Profile] _toHttpsUrl error for "$raw": $e');
      rethrow;
    }
  }

  // ✅ Expressive visit text
  String _visitText(int count, bool isOwnProfile) {
    if (isOwnProfile) {
      if (count <= 0) return "No one’s viewed your profile yet 👀";
      if (count == 1) return "1 visit • One curious soul noticed you";
      if (count < 5) return "$count visits • A few people checked you out ✨";
      if (count < 10) return "$count visits • You’re getting attention 🔥";
      if (count < 25) return "$count visits • You’re becoming popular 👀";
      if (count < 50) return "$count visits • You’re on fire 🔥";
      return "$count visits • You’re trending around 🚀";
    } else {
      if (count <= 0) return "No profile visits yet";
      if (count == 1) return "1 visit • Someone viewed this profile 👀";
      if (count < 5) return "$count visits • A few people peeked here ✨";
      if (count < 10) return "$count visits • This profile’s getting noticed 🔥";
      if (count < 25) return "$count visits • Catching some eyes 👀";
      if (count < 50) return "$count visits • Quite popular nearby 🔥";
      return "$count visits • Trending around 🚀";
    }
  }

  Widget _avatarFrame(Widget child) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _networkAvatar(String url, {double size = 120, String? heroTag}) {
    final avatar = Container(
      width: size,
      height: size,
      decoration:
      const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (ctx, _) => CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.white12,
          child: const Icon(Icons.person, size: 40, color: Colors.white),
        ),
        errorWidget: (ctx, _, __) => CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.white12,
          child: const Icon(Icons.person_off, size: 40, color: Colors.grey),
        ),
        memCacheWidth: 512,
        memCacheHeight: 512,
      ),
    );
    final wrapped = heroTag == null ? avatar : Hero(tag: heroTag, child: avatar);
    return _avatarFrame(wrapped);
  }

  Widget _buildAvatar(Map<String, dynamic> data,
      {required String userId, required bool isOwnProfile, double size = 120}) {
    final raw = _extractRawPfp(data);
    final heroTag = userId.isNotEmpty ? 'avatar_$userId' : 'avatar_fallback';

    Widget avatarWidget;

    if (raw == null || raw.isEmpty) {
      avatarWidget = _avatarFrame(
        CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.white12,
          child: const Icon(Icons.person, size: 40, color: Colors.white70),
        ),
      );
    } else if (raw.startsWith('http')) {
      final shown = _withCacheBuster(raw, data);
      avatarWidget = _networkAvatar(shown, size: size, heroTag: heroTag);
    } else {
      avatarWidget = FutureBuilder<String>(
        future: _toHttpsUrl(raw),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return CircleAvatar(
              radius: size / 2,
              backgroundColor: Colors.white12,
              child: const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            );
          }
          if (snap.hasError || !snap.hasData || (snap.data ?? '').isEmpty) {
            return CircleAvatar(
              radius: size / 2,
              backgroundColor: Colors.white12,
              child: const Icon(Icons.person_off, size: 40, color: Colors.grey),
            );
          }
          final finalUrl = _withCacheBuster(snap.data!, data);
          return _networkAvatar(finalUrl, size: size, heroTag: heroTag);
        },
      );
    }

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () {
        if (isOwnProfile) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          );
        } else if (raw != null && raw.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: TagginColors.bg,
                appBar: AppBar(
                  backgroundColor: TagginColors.bg,
                  iconTheme: const IconThemeData(color: Colors.white),
                ),
                body: Center(
                  child: Hero(
                    tag: heroTag,
                    child: InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: raw,
                        fit: BoxFit.contain,
                        errorWidget: (ctx, _, __) =>
                        const Icon(Icons.person_off, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
      child: avatarWidget,
    );
  }

  Widget _buildProfile(
      BuildContext context, String viewedUserId, bool isOwnProfile) {
    if (viewedUserId.isEmpty) {
      return const Center(
        child: Text('No user found',
            style: TextStyle(color: TagginColors.subtext)),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(viewedUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        final doc = snapshot.data!;
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final username = (data['username'] ?? '').toString();
        final city = (data['city'] ?? '').toString();
        final college = (data['selectedCollege'] ??
            data['institutionName'] ??
            data['college'] ??
            '')
            .toString();
        final bio = (data['bio'] ?? '').toString().trim();
        final profileViews = data['profileViews'] ?? 0;

        return Column(
          children: [
            const SizedBox(height: 20),
            _buildAvatar(data,
                userId: doc.id, isOwnProfile: isOwnProfile, size: 120),
            const SizedBox(height: 14),
            Text(
              username.isEmpty ? 'Username' : username,
              style: const TextStyle(
                color: TagginColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            if (city.isNotEmpty || college.isNotEmpty)
              Text(
                [
                  if (city.isNotEmpty) city,
                  if (college.isNotEmpty) ' • $college',
                ].join(''),
                style: const TextStyle(
                  color: TagginColors.subtext,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            if (bio.isNotEmpty)
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6),
                child: Text(
                  bio,
                  style: const TextStyle(
                      color: TagginColors.subtext,
                      fontSize: 14,
                      height: 1.35),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.remove_red_eye,
                      color: TagginColors.subtext, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _visitText(profileViews, isOwnProfile),
                    style: const TextStyle(
                      color: TagginColors.subtext,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (!isOwnProfile)
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ComplimentScreen(targetUserId: viewedUserId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.card_giftcard, color: Colors.black),
                      label: const Text(
                        "Send Compliment",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 18),
                    LikeProfile(
                        profileUserId: viewedUserId,
                        textColor: TagginColors.text),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: LikeProfile(
                  profileUserId: viewedUserId,
                  textColor: TagginColors.text,
                ),
              ),
            const Divider(height: 1, color: TagginColors.divider),
            Expanded(child: MyPosts(userId: viewedUserId)),
          ],
        );
      },
    );
  }
}
