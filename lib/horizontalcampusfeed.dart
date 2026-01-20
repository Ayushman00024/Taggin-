// lib/horizontal_campus_feed.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'profilescreenui.dart';
import 'add_friend_button.dart';
import 'search_campus.dart';

class HorizontalCampusFeed extends StatefulWidget {
  const HorizontalCampusFeed({Key? key}) : super(key: key);

  @override
  State<HorizontalCampusFeed> createState() => _HorizontalCampusFeedState();
}

class _HorizontalCampusFeedState extends State<HorizontalCampusFeed> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String? _myUid;
  String? _myCollege;
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = _auth.currentUser;
      _myUid = u?.uid;
      if (_myUid == null) {
        setState(() => _loading = false);
        return;
      }

      final selfDoc = await _fire.collection('users').doc(_myUid).get();
      _myCollege =
          (selfDoc['selectedCollege'] ?? '').toString().trim().toUpperCase();

      if (_myCollege == null || _myCollege!.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final snap = await _fire
          .collection('users')
          .where('selectedCollege', isEqualTo: _myCollege)
          .limit(50)
          .get();

      final list = snap.docs
          .where((d) => d.id != _myUid)
          .map((d) {
        final data = d.data();
        return {
          'uid': d.id,
          'username': (data['username'] ?? '').toString(),
          'profilePic': _bestPhoto(data),
        };
      }).toList();

      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error loading HorizontalCampusFeed: $e");
      setState(() => _loading = false);
    }
  }

  String? _bestPhoto(Map<String, dynamic> d) {
    for (final key in ['profilePicUrl', 'profilePic', 'photoUrl']) {
      final v = (d[key] ?? '').toString();
      if (v.isNotEmpty) return v;
    }
    final pics = d['profilePics'];
    if (pics is List && pics.isNotEmpty) {
      final first = pics.first;
      if (first is String && first.isNotEmpty) return first;
      if (first is Map && (first['url'] ?? '') != '') {
        return first['url'].toString();
      }
    }
    return null;
  }

  void _openProfile(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreenUI(),
        settings: RouteSettings(arguments: {'userId': uid}),
      ),
    );
  }

  void _openMore() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchCampusScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 190,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_users.isEmpty) {
      return const SizedBox.shrink();
    }

    final limited = _users.length > 20 ? _users.sublist(0, 20) : _users;

    return SizedBox(
      height: 190, // ✅ more room for avatar + text + button
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: limited.length + (_users.length > 20 ? 1 : 0),
        itemBuilder: (context, i) {
          // "More" tile
          if (_users.length > 20 && i == limited.length) {
            return GestureDetector(
              onTap: _openMore,
              child: Container(
                width: 90,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.black12,
                      child: Icon(Icons.more_horiz, color: Colors.black),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "More",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.black),
                    ),
                  ],
                ),
              ),
            );
          }

          final u = limited[i];
          final photo = u['profilePic'];

          return Container(
            width: 90,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _openProfile(u['uid']),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundImage: (photo != null && photo.isNotEmpty)
                        ? CachedNetworkImageProvider(photo)
                        : null,
                    backgroundColor: Colors.grey.shade200,
                    child: (photo == null || photo.isEmpty)
                        ? const Icon(Icons.person, color: Colors.black54)
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  u['username'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 28, // ✅ fixed height so Android doesn't stretch
                  child: AddFriendButton(otherUserId: u['uid']),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
