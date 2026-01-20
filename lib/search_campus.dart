// lib/search_campus.dart
// 🌙 Dark Mode Campus Search – Text White, Background Black

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'profilescreenui.dart';
import 'add_friend_button.dart';

class SearchCampusScreen extends StatefulWidget {
  const SearchCampusScreen({Key? key}) : super(key: key);

  @override
  State<SearchCampusScreen> createState() => _SearchCampusScreenState();
}

class _SearchCampusScreenState extends State<SearchCampusScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String? _myUid;
  String? _mySelectedCollege;

  final _searchCtrl = TextEditingController();
  String _q = '';
  Timer? _debounce;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSelf();
    _searchCtrl.addListener(_onType);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onType);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onType() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _q = _searchCtrl.text.trim().toLowerCase());
    });
  }

  Future<void> _loadSelf() async {
    try {
      final u = _auth.currentUser;
      _myUid = u?.uid;
      if (_myUid == null) {
        setState(() => _loading = false);
        return;
      }
      final doc = await _fire.collection('users').doc(_myUid).get();
      final data = doc.data() ?? {};
      _mySelectedCollege =
          (data['selectedCollege'] ?? '').toString().trim().toUpperCase();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _userStream() async* {
    if (_mySelectedCollege == null || _mySelectedCollege!.isEmpty) {
      yield [];
      return;
    }

    final query = _fire
        .collection('users')
        .where('selectedCollege', isEqualTo: _mySelectedCollege)
        .limit(100);

    await for (final snap in query.snapshots()) {
      final filtered = snap.docs.where((d) {
        if (d.id == _myUid) return false;
        final data = d.data();
        if (_q.isEmpty) return true;
        final uname = (data['username_lower'] ?? data['username'] ?? '')
            .toString()
            .toLowerCase();
        return uname.startsWith(_q);
      }).toList();

      filtered.sort((a, b) {
        final ta = (a.data()['timestamp'] as Timestamp?);
        final tb = (b.data()['timestamp'] as Timestamp?);
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      yield filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    if (_mySelectedCollege == null || _mySelectedCollege!.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _EmptyState(
          title: 'Add your college',
          subtitle: 'Pick your college/school to see classmates here.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _TopSearchBar(
              controller: _searchCtrl, hint: 'Search username in your campus'),
          Expanded(
            child: StreamBuilder<
                List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: _userStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorState(message: snap.error.toString());
                }
                if (!snap.hasData) {
                  return const Center(
                      child:
                      CircularProgressIndicator(color: Colors.white));
                }

                final docs = snap.data!;
                if (docs.isEmpty) {
                  return const _EmptyState(
                    title: 'No users yet',
                    subtitle: 'Invite your friends to show up here!',
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final uid = docs[i].id;
                    final uname = (data['username'] ?? '').toString();
                    final name = (data['name'] ?? '').toString();
                    final photo = _bestPhoto(data);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreenUI(),
                            settings:
                            RouteSettings(arguments: {'userId': uid}),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.grey.shade900,
                              backgroundImage: photo != null
                                  ? CachedNetworkImageProvider(photo)
                                  : null,
                              child: photo == null
                                  ? const Icon(Icons.person,
                                  size: 40, color: Colors.white54)
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name.isEmpty ? uname : name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '@$uname',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_myUid == null)
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              AddFriendButton(
                                key: ValueKey('af_${uid}_$_myUid'),
                                otherUserId: uid,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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
}

// -----------------------------
// 🌙 UI Helpers (Dark Mode)
// -----------------------------

class _TopSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _TopSearchBar(
      {Key? key, required this.controller, required this.hint})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.search, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white70,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    hintStyle: const TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  icon:
                  const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () {
                    controller.clear();
                    FocusScope.of(context).unfocus();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState(
      {Key? key, required this.title, required this.subtitle})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_outlined,
                size: 52, color: Colors.white38),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Text(
        'Error: $message',
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
