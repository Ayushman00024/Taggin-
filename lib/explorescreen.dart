import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';

import 'nearby_swipe_deck.dart';

class _TagginColors {
  static const bg = Colors.white;
  static const primary = Colors.black; // ⚫ main brand color
  static const accent = Color(0xFFEC4899);
  static const text = Colors.black;   // ⚫ all text in black
  static const subtext = Colors.black87;
  static const cardOverlay = Colors.black12;
}

class TagginCacheManager {
  TagginCacheManager._();
  static final CacheManager instance = CacheManager(
    Config(
      'tagginCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 500,
    ),
  );
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final GlobalKey<NearbySwipeDeckState> _deckKey =
  GlobalKey<NearbySwipeDeckState>();
  int _refreshToken = 0;
  Position? _myPos;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
    _updateMyLocation();
  }

  Future<void> _updateMyLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ✅ Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationDenied = true);
        return;
      }

      // ✅ Get position
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _myPos = pos;
        _locationDenied = false;
      });

      // ✅ Update Firestore only if user moved significantly ( > 10m )
      final docRef =
      FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['lastLocation'] != null) {
          final lastGeo = data['lastLocation'] as GeoPoint;
          final distance = Geolocator.distanceBetween(
            lastGeo.latitude,
            lastGeo.longitude,
            pos.latitude,
            pos.longitude,
          );
          if (distance < 10) {
            return; // Skip update if movement is tiny
          }
        }
      }

      await docRef.update({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'lastLocation': GeoPoint(pos.latitude, pos.longitude),
        'lastActiveAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint("❌ Location update failed: $e");
    }
  }

  Future<void> _onPullToRefresh() async {
    HapticFeedback.lightImpact();
    await _updateMyLocation();
    await _deckKey.currentState?.refresh();
    setState(() => _refreshToken++);
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Widget _topWordmark() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 16, bottom: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'NEARBY ME',
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: _TagginColors.text,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _safetyTip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: _FrostedCard(
        child: Row(
          children: const [
            Icon(Icons.lock_outline, color: Colors.black, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Your exact location isn’t shown to others. We only use your last update to surface nearby profiles.",
                style: TextStyle(
                  color: _TagginColors.subtext,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationDeniedCard() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: _FrostedCard(
        child: Text(
          "Location permission denied.\nEnable location in settings to see nearby profiles.",
          style: TextStyle(color: _TagginColors.subtext, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _TagginColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.black,
          onRefresh: _onPullToRefresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _topWordmark()),
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: user == null
                      ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: _FrostedCard(
                      child: Text(
                        "Not signed in.",
                        style: TextStyle(
                            color: _TagginColors.subtext, fontSize: 14),
                      ),
                    ),
                  )
                      : _locationDenied
                      ? _locationDeniedCard()
                      : SizedBox(
                    height: screenHeight * 0.6, // ✅ responsive height
                    child: Stack(
                      children: [
                        NearbySwipeDeck(
                          key: _deckKey,
                          refreshToken: _refreshToken,
                          currentPosition: _myPos,
                          cacheManager:
                          TagginCacheManager.instance,
                          onProfileTap: (userId) {
                            Navigator.pushNamed(
                              context,
                              '/profile',
                              arguments: {'userId': userId},
                            );
                          },
                        ),
                        if (_myPos == null)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _safetyTip()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrostedCard extends StatelessWidget {
  final Widget child;
  const _FrostedCard({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
