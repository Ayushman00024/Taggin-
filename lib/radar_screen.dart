// radar_screen.dart — centered "me", beautiful radar, clickable profiles,
// and empty-state banner OUTSIDE the radar UI.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'locationfetching.dart'; // read shared position (PresenceScope keeps it fresh)
import 'radar_widgets.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({Key? key, this.currentPosition}) : super(key: key);
  final Position? currentPosition;

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  // Visibility & layout knobs
  static const double _radiusMeters = 100.0;                   // who counts as nearby
  static const Duration _presenceTTL = Duration(seconds: 30);  // drop after this age
  static const double _dotSize = 42;                           // others' avatars (was 52)
  static const double _meSize = 56;                            // center avatar (was 72)
  static const int _maxUsers = 20;                             // cap shown users

  late final AnimationController _orbitCtrl =
  AnimationController(vsync: this, duration: const Duration(seconds: 16))
    ..repeat();

  Position? _pos; // resolved position (prop + live updates)
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pos = widget.currentPosition;

    // Listen to the global position stream maintained by PresenceScope.
    LocationFetching.position.addListener(_onPosTick);

    // Fallback once if no position yet.
    if (_pos == null) _resolvePositionOnce();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // PresenceScope already handles presence; we only refresh a one-shot fix if needed.
    if (state == AppLifecycleState.resumed && _pos == null) {
      _resolvePositionOnce();
    }
    super.didChangeAppLifecycleState(state);
  }

  void _onPosTick() {
    final p = LocationFetching.position.value;
    if (!mounted || p == null) return;
    if (_pos == null ||
        _pos!.latitude != p.latitude ||
        _pos!.longitude != p.longitude) {
      setState(() => _pos = p);
    }
  }

  Future<void> _resolvePositionOnce() async {
    setState(() => _fetching = true);
    final p = await LocationFetching.getOnce(
      accuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 8),
    );
    if (!mounted) return;
    setState(() {
      _pos = p;
      _fetching = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocationFetching.position.removeListener(_onPosTick);
    _orbitCtrl.dispose();
    super.dispose();
  }

  // ---------- Distance helpers ----------
  static double _distanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double d) => d * (pi / 180);

  static double _stableAngle(String uid) {
    final h = uid.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return (h % 360) * pi / 180.0; // stable per uid
  }

  @override
  Widget build(BuildContext context) {
    final me = _auth.currentUser;
    final myPos = _pos;

    // Server-side window: fetch a superset; client trims by 30s TTL.
    final serverWindow = DateTime.now().subtract(const Duration(minutes: 3));
    final serverCutoffTs = Timestamp.fromDate(serverWindow);

    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Bigger on-screen radar (fills more of the viewport)
    final radarRadius = min(size.width, size.height) * 0.52; // was 0.38

    return Scaffold(
      backgroundColor: const Color(0xFF06070B),
      body: Stack(
        children: [
          // Stars in the back
          UniverseBackground(orbitsController: _orbitCtrl),

          // Radar & dots (or loader) in the middle
          if (myPos == null)
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _fire
                  .collection('users')
                  .where('lastActiveAt', isGreaterThan: serverCutoffTs)
                  .orderBy('lastActiveAt', descending: true)
                  .limit(300)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      "Radar error: ${snap.error}",
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  );
                }

                // --- Build candidate list, then sort by distance & cap to 20 ---
                final nowCutoff = DateTime.now().subtract(_presenceTTL);
                final candidates = <Map<String, dynamic>>[];

                for (final doc in snap.data!.docs) {
                  final data = doc.data();
                  final uid = doc.id;
                  if (uid.isEmpty) continue;
                  if (me != null && uid == me.uid) continue;

                  final ts = data['lastActiveAt'];
                  final geo = data['lastLocation'];
                  if (ts is! Timestamp || geo is! GeoPoint) continue;

                  // TTL filter (strict 30s)
                  if (ts.toDate().isBefore(nowCutoff)) continue;

                  // OPTIONAL: If you keep isActive, only skip explicit false.
                  if (data['isActive'] == false) continue;

                  final dist = _distanceMeters(
                    myPos.latitude,
                    myPos.longitude,
                    geo.latitude,
                    geo.longitude,
                  );
                  if (dist > _radiusMeters) continue;

                  candidates.add({
                    'uid': uid,
                    'name': (data['username'] ?? data['displayName'] ?? 'Someone').toString(),
                    'photo': (data['profilePic'] ?? data['photoUrl'] ?? '').toString(),
                    'dist': dist,
                  });
                }

                // Sort nearest → farthest and cap
                candidates.sort((a, b) => (a['dist'] as double).compareTo(b['dist'] as double));
                final visible = candidates.take(_maxUsers).toList();

                return AnimatedBuilder(
                  animation: _orbitCtrl,
                  builder: (_, __) {
                    final children = <Widget>[
                      // Radar rings & crosshair — ignore pointer so it never steals taps
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: RadarPainterWidget(
                            radarRadius: radarRadius,
                            center: Offset(cx, cy),
                          ),
                        ),
                      ),
                      // Me at exact center
                      Positioned(
                        left: cx - _meSize / 2,
                        top: cy - _meSize / 2,
                        child: MeDot(photoUrl: me?.photoURL, size: _meSize),
                      ),
                    ];

                    for (final it in visible) {
                      final uid = it['uid'] as String;
                      final name = it['name'] as String;
                      final photo = it['photo'] as String;
                      final dist = it['dist'] as double;

                      // Place on snapped orbits with gentle rotation
                      final angle = _stableAngle(uid);
                      final r = (dist / _radiusMeters).clamp(0.0, 1.0);
                      final snapped = (r <= 0.25)
                          ? 0.25
                          : (r <= 0.50)
                          ? 0.50
                          : (r <= 0.75)
                          ? 0.75
                          : 1.0;

                      final orbitAngle =
                          angle + _orbitCtrl.value * 2 * pi * (1.2 - snapped);
                      final actualR = snapped * radarRadius;

                      final dx = cx + actualR * cos(orbitAngle);
                      final dy = cy + actualR * sin(orbitAngle);

                      children.add(Positioned(
                        left: dx - _dotSize / 2,
                        top: dy - _dotSize / 2,
                        child: RadarDot(
                          uid: uid,
                          name: name,
                          photoUrl: photo,
                          avatarSize: _dotSize, // already smaller by default too
                        ),
                      ));
                    }

                    // Empty-state banner OUTSIDE the radar UI (no extra query).
                    if (visible.isEmpty) {
                      children.add(const Align(
                        alignment: Alignment.bottomCenter,
                        child: NoNearbyBanner(text: 'No one nearby right now…'),
                      ));
                    }

                    return Stack(children: children);
                  },
                );
              },
            ),

          // Top caption
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  "Taggin · Live Universe Radar (100 m)",
                  style: TextStyle(
                      color: Colors.white70, fontSize: 14, letterSpacing: 0.3),
                ),
              ),
            ),
          ),

          // Waiting text (only if location known is false)
          if (myPos == null && !_fetching)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 120),
                child: Text(
                  "Waiting for location…",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
