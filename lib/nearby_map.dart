import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class NearbyMapScreen extends StatefulWidget {
  const NearbyMapScreen({Key? key}) : super(key: key);

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen>
    with SingleTickerProviderStateMixin {
  Position? _myPos;
  List<_NearbyUser> _users = [];
  StreamSubscription? _sub;

  late final AnimationController _pulseController;

  static const double _radiusKm = 1.0;
  static const int _maxFetch = 200;
  static const double _latKm = 110.574;
  static const double _lngKmAtEq = 111.320;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _fetchLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _myPos = pos);
      _subscribeNearby(pos);
    } catch (e) {
      debugPrint("❌ Location failed: $e");
    }
  }

  void _subscribeNearby(Position center) {
    _sub?.cancel();

    final latDelta = _radiusKm / _latKm;
    final minLat = center.latitude - latDelta;
    final maxLat = center.latitude + latDelta;

    final cosLat =
    math.cos(center.latitude * math.pi / 180.0).clamp(0.0001, 1.0);
    final lngDelta = _radiusKm / (_lngKmAtEq * cosLat);
    final minLng = center.longitude - lngDelta;
    final maxLng = center.longitude + lngDelta;

    final query = FirebaseFirestore.instance
        .collection('users')
        .where('lat', isGreaterThanOrEqualTo: minLat)
        .where('lat', isLessThanOrEqualTo: maxLat)
        .orderBy('lat')
        .limit(_maxFetch);

    _sub = query.snapshots().listen((snap) {
      final List<_NearbyUser> results = [];

      for (final doc in snap.docs) {
        if (doc.id == FirebaseAuth.instance.currentUser?.uid) continue;
        final data = doc.data();

        final userLat = (data['lat'] as num?)?.toDouble();
        final userLng = (data['lng'] as num?)?.toDouble();
        if (userLat == null || userLng == null) continue;
        if (userLng < minLng || userLng > maxLng) continue;

        final distM = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          userLat,
          userLng,
        );
        if (distM > _radiusKm * 1000) continue;

        results.add(_NearbyUser(
          id: doc.id,
          name: data['name'],
          username: data['username'],
          photoUrl: data['profilePic'],
          pos: LatLng(userLat, userLng),
        ));
      }

      setState(() => _users = results);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_myPos == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(_myPos!.latitude, _myPos!.longitude),
            initialZoom: 15,
          ),
          children: [
            // 🌍 OpenStreetMap free tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.taggin',
            ),

            // 📍 Markers
            MarkerLayer(
              markers: [
                // My Profile with pulse animation
                Marker(
                  point: LatLng(_myPos!.latitude, _myPos!.longitude),
                  width: 80,
                  height: 80,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1 + (_pulseController.value * 0.4);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.purpleAccent.withOpacity(0.3),
                          ),
                          child: const Icon(
                            Icons.person_pin_circle,
                            color: Colors.purpleAccent,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Other users
                for (final u in _users)
                  Marker(
                    point: u.pos,
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/profile',
                          arguments: {'userId': u.id},
                        );
                      },
                      child: CircleAvatar(
                        radius: 28,
                        backgroundImage: u.photoUrl != null
                            ? NetworkImage(u.photoUrl!)
                            : null,
                        child: u.photoUrl == null
                            ? Text(u.name?[0] ?? "U")
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // ❌ Empty state overlay
        if (_users.isEmpty)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                "No nearby users within 1 km",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}

class _NearbyUser {
  final String id;
  final String? name;
  final String? username;
  final String? photoUrl;
  final LatLng pos;

  _NearbyUser({
    required this.id,
    this.name,
    this.username,
    this.photoUrl,
    required this.pos,
  });
}
