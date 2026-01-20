// =============================
// searchbyusername_city_only.dart
// Search users by username but ONLY within the same city.
// Fixes "can't find names starting with 'S'" by normalizing to lowercase
// and using username_lower field for prefix search.
// =============================

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'add_friend_button.dart';

class SearchByUsernameCityOnly extends StatefulWidget {
  const SearchByUsernameCityOnly({Key? key}) : super(key: key);
  @override
  State<SearchByUsernameCityOnly> createState() => _SearchByUsernameCityOnlyState();
}

class _SearchByUsernameCityOnlyState extends State<SearchByUsernameCityOnly> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _controller = TextEditingController();
  Timer? _debounce;

  String? _myUid;
  String? _myCityLower; // <-- required for restriction
  String _q = '';
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser?.uid;
    _controller.addListener(_onChanged);
    _loadMyCity();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- Load current user's city (lowercased) once ---
  Future<void> _loadMyCity() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final me = await _fire.collection('users').doc(uid).get();
    final data = me.data() ?? {};
    final city = (data['city'] ?? '').toString().trim();
    _myCityLower = city.isEmpty ? null : city.toLowerCase();
    if (mounted) setState(() {});
  }

  // --- Normalize the query so 'S' works the same as 's' ---
  String _normalize(String raw) {
    final s = raw.trim();
    if (s.startsWith('@')) return s.substring(1).toLowerCase();
    return s.toLowerCase();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _normalize(_controller.text);
      if (q == _q) return;
      setState(() => _q = q);
      if (q.isEmpty) {
        setState(() => _results = []);
      } else {
        _run(q);
      }
    });
  }

  Future<void> _run(String q) async {
    // Require city to be known for city-only search
    if (_myCityLower == null || _myCityLower!.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final Map<String, Map<String, dynamic>> merged = {};

      // Preferred: username_lower + city_lower
      try {
        final qs = await _fire
            .collection('users')
            .where('city_lower', isEqualTo: _myCityLower)
            .orderBy('username_lower')
            .startAt([q])
            .endAt([q + '\uf8ff'])
            .limit(50)
            .get();

        for (final d in qs.docs) {
          if (d.id == _myUid) continue;
          final data = d.data();
          if ((data['username'] ?? '').toString().isEmpty) continue;
          merged[d.id] = _mapUser(d.id, data);
        }
      } on FirebaseException catch (_) {
        // Fallback: usernameLower (camelCase) if some docs haven't been migrated
        try {
          final qs = await _fire
              .collection('users')
              .where('city_lower', isEqualTo: _myCityLower)
              .orderBy('usernameLower')
              .startAt([q])
              .endAt([q + '\uf8ff'])
              .limit(50)
              .get();

          for (final d in qs.docs) {
            if (d.id == _myUid) continue;
            final data = d.data();
            if ((data['username'] ?? '').toString().isEmpty) continue;
            merged[d.id] = _mapUser(d.id, data);
          }
        } catch (_) {
          // Last resort: small batch and client-side startsWith check (still city-scoped)
          final qs = await _fire
              .collection('users')
              .where('city_lower', isEqualTo: _myCityLower)
              .limit(200)
              .get();

          for (final d in qs.docs) {
            if (d.id == _myUid) continue;
            final data = d.data();
            final snake = (data['username_lower'] ?? '').toString();
            final camel = (data['usernameLower'] ?? '').toString();
            final plain = (data['username'] ?? '').toString();
            // normalize all to lowercase to fix 'S' vs 's'
            final candidate = (snake.isNotEmpty
                ? snake
                : (camel.isNotEmpty ? camel : plain))
                .toLowerCase();
            if (candidate.startsWith(q)) {
              merged[d.id] = _mapUser(d.id, data);
            }
          }
        }
      }

      if (mounted) {
        setState(() => _results = merged.values.toList());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _mapUser(String id, Map<String, dynamic> data) {
    return {
      'uid': id,
      'name': (data['name'] ?? '').toString(),
      'username': (data['username'] ?? '').toString(),
      'profilePic': (data['profilePic'] ?? data['profilePicUrl'] ?? '').toString(),
      'city': (data['city'] ?? '').toString(),
      'college': (data['college'] ?? '').toString(),
      'isActive': (data['isActive'] ?? false) == true,
    };
  }

  void _openProfile(String userId) {
    Navigator.of(context).pushNamed('/profile', arguments: {'userId': userId});
  }

  @override
  Widget build(BuildContext context) {
    final cityLocked = _myCityLower != null && _myCityLower!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.8,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: Colors.black),
        title: _SearchBar(controller: _controller),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !cityLocked
          ? const _CityMissing()
          : _results.isEmpty && _q.isEmpty
          ? const _Hint()
          : _results.isEmpty
          ? const _NoResults()
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        itemCount: _results.length,
        itemBuilder: (context, i) {
          final u = _results[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BigProfileCard(
              uid: (u['uid'] ?? '').toString(),
              name: (u['name'] ?? '').toString(),
              username: (u['username'] ?? '').toString(),
              profilePic: (u['profilePic'] ?? '').toString(),
              city: (u['city'] ?? '').toString(),
              college: (u['college'] ?? '').toString(),
              isActive: (u['isActive'] ?? false) == true,
              onTap: () => _openProfile((u['uid'] ?? '').toString()),
            ),
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search, color: Colors.black54, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              cursorColor: Colors.black54,
              decoration: const InputDecoration(
                hintText: 'Search usernames in your city',
                hintStyle: TextStyle(color: Colors.black38),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black54, size: 20),
              onPressed: () {
                controller.clear();
                FocusScope.of(context).unfocus();
              },
            ),
        ],
      ),
    );
  }
}

class _CityMissing extends StatelessWidget {
  const _CityMissing({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Set your city in profile to search. (City-only search is enabled)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text('Type a username (city-restricted)', style: TextStyle(color: Colors.black54)),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No users found in your city', style: TextStyle(color: Colors.black54)));
  }
}

class _BigProfileCard extends StatelessWidget {
  final String uid;
  final String name;
  final String username;
  final String profilePic;
  final String city;
  final String college;
  final bool isActive;
  final VoidCallback onTap;

  const _BigProfileCard({
    Key? key,
    required this.uid,
    required this.name,
    required this.username,
    required this.profilePic,
    required this.city,
    required this.college,
    required this.isActive,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final caption = username.isNotEmpty ? '@$username' : name;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.black.withOpacity(0.06),
                    backgroundImage: profilePic.isNotEmpty ? CachedNetworkImageProvider(profilePic) : null,
                    child: profilePic.isEmpty ? const Icon(Icons.person, color: Colors.black38, size: 42) : null,
                  ),
                  if (isActive)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                name.isNotEmpty ? name : username,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(caption, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 8),
              if (city.isNotEmpty || college.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (city.isNotEmpty) ...[
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.black45),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(city, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      ),
                    ],
                    if (city.isNotEmpty && college.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('•', style: TextStyle(color: Colors.black38)),
                      ),
                    if (college.isNotEmpty) ...[
                      const Icon(Icons.school_outlined, size: 16, color: Colors.black45),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(college, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                AddFriendButton(otherUserId: uid, mini: false),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
