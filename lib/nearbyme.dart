// lib/nearbyme.dart
// 🌙 Dark Mode - Nearby Me: list of users within 1 km
// White text, subtle gray UI, online indicator glows softly.

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'profilescreenui.dart';
import 'add_friend_button.dart';

class NearbyMeScreen extends StatefulWidget {
  const NearbyMeScreen({Key? key}) : super(key: key);

  @override
  State<NearbyMeScreen> createState() => _NearbyMeScreenState();
}

class _NearbyMeScreenState extends State<NearbyMeScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String? _myUid;
  Position? _myPos;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUid = _auth.currentUser?.uid;

    try {
      _myPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      _myPos = null;
    }

    if (mounted) setState(() => _loading = false);
  }

  double _calcKm(double lat, double lng) {
    if (_myPos == null) return double.infinity;
    return Geolocator.distanceBetween(
      _myPos!.latitude,
      _myPos!.longitude,
      lat,
      lng,
    ) /
        1000.0;
  }

  bool _isUserOnline(Map<String, dynamic> data) {
    final now = DateTime.now();
    final activeUntil = (data['activeUntil'] as Timestamp?)?.toDate();
    final lastActiveAt = (data['lastActiveAt'] as Timestamp?)?.toDate();
    final isActive = data['isActive'] == true;

    if (activeUntil != null && activeUntil.isAfter(now)) return true;
    if (lastActiveAt != null &&
        now.difference(lastActiveAt) <= const Duration(seconds: 30)) {
      return true;
    }
    return isActive;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _userStream() async* {
    await for (final snap in _fire.collection('users').snapshots()) {
      final filtered = snap.docs.where((d) {
        if (d.id == _myUid) return false;
        final data = d.data();
        if (data['lat'] == null || data['lng'] == null) return false;

        final dist = _calcKm(
          (data['lat'] as num).toDouble(),
          (data['lng'] as num).toDouble(),
        );
        return dist <= 1.0;
      }).toList();

      yield filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }

    if (_myPos == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: _EmptyState(
          title: 'Enable location',
          subtitle: 'Turn on GPS to find people nearby.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _userStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorState(message: snap.error.toString());
          }
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          }

          final docs = snap.data!;
          if (docs.isEmpty) {
            return const _EmptyState(
              title: 'No nearby users',
              subtitle: 'Be the first one nearby to appear here!',
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
              final isOnline = _isUserOnline(data);
              final dist = (data['lat'] != null && data['lng'] != null)
                  ? _calcKm(
                (data['lat'] as num).toDouble(),
                (data['lng'] as num).toDouble(),
              )
                  : double.infinity;

              return Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0x22FFFFFF), width: 0.3),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF2A2A2A),
                    backgroundImage:
                    photo != null ? CachedNetworkImageProvider(photo) : null,
                    child: photo == null
                        ? const Icon(Icons.person, size: 28, color: Colors.white54)
                        : null,
                  ),
                  title: Text(
                    name.isEmpty ? uname : name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    "${isOnline ? '🟢 Online' : '⚪ Offline'} • ${dist.toStringAsFixed(2)} km away",
                    style: TextStyle(
                      fontSize: 13,
                      color: isOnline
                          ? Colors.greenAccent.shade100
                          : Colors.white54,
                    ),
                  ),
                  trailing: AddFriendButton(
                    key: ValueKey('af_${uid}_$_myUid'),
                    otherUserId: uid,
                    mini: true,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreenUI(),
                        settings: RouteSettings(arguments: {'userId': uid}),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
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
// UI Helpers - Dark Mode
// -----------------------------
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({Key? key, required this.title, required this.subtitle})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined,
                size: 52, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
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
      color: const Color(0xFF121212),
      alignment: Alignment.center,
      child: Text(
        'Error: $message',
        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
      ),
    );
  }
}
