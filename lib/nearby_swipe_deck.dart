// nearby_swipe_deck.dart
// 3D swipe deck of nearby profiles (≤ 1 km). Show ALL users in range.
// Active ones get a badge, others just profile.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'add_friend_button.dart';

const Duration kPresenceWindow = Duration(seconds: 30);

class NearbySwipeDeck extends StatefulWidget {
  final Position? currentPosition;
  final BaseCacheManager? cacheManager;
  final void Function(String userId)? onProfileTap;
  final int refreshToken;

  const NearbySwipeDeck({
    Key? key,
    required this.currentPosition,
    this.cacheManager,
    this.onProfileTap,
    this.refreshToken = 0,
  }) : super(key: key);

  @override
  NearbySwipeDeckState createState() => NearbySwipeDeckState();
}

class NearbySwipeDeckState extends State<NearbySwipeDeck> {
  static const double _radiusKm = 1.0;
  static const int _maxFetch = 200;
  static const double _latKm = 110.574;
  static const double _lngKmAtEq = 111.320;

  final PageController _pageCtrl = PageController(viewportFraction: 0.82);

  String? _myId;
  bool _loading = true;
  String? _error;
  Position? _lastCenter;

  List<_NearbyUser> _users = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _myId = FirebaseAuth.instance.currentUser?.uid;
    _maybeSubscribe(initial: true);
  }

  @override
  void didUpdateWidget(covariant NearbySwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.refreshToken != oldWidget.refreshToken) {
      refresh();
      return;
    }

    final now = widget.currentPosition;
    final prev = _lastCenter;
    if (now != null &&
        (prev == null ||
            Geolocator.distanceBetween(
              prev.latitude,
              prev.longitude,
              now.latitude,
              now.longitude,
            ) > 120)) {
      _maybeSubscribe();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final center = widget.currentPosition ?? _lastCenter;
    if (center != null) {
      _subscribeNearby(center);
    } else {
      _maybeSubscribe(initial: true);
    }
  }

  Future<void> _maybeSubscribe({bool initial = false}) async {
    final pos = widget.currentPosition;
    if (pos == null) {
      if (initial) {
        setState(() {
          _loading = true;
          _error = null;
          _users = [];
        });
      }
      return;
    }
    _subscribeNearby(pos);
  }

  void _subscribeNearby(Position center) {
    _sub?.cancel();

    setState(() {
      _loading = true;
      _error = null;
      _users = [];
      _lastCenter = center;
    });

    final latDelta = _radiusKm / _latKm;
    final minLat = center.latitude - latDelta;
    final maxLat = center.latitude + latDelta;

    final cosLat = math.cos(center.latitude * math.pi / 180.0).clamp(0.0001, 1.0);
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
      try {
        final now = DateTime.now();
        final List<_NearbyUser> results = [];

        for (final doc in snap.docs) {
          if (doc.id == _myId) continue;
          final data = doc.data();

          final userLat = (data['lat'] as num?)?.toDouble();
          final userLng = (data['lng'] as num?)?.toDouble();
          if (userLat == null || userLng == null) continue;
          if (userLng < minLng || userLng > maxLng) continue;

          final isActive = (data['isActive'] as bool?) ?? false;
          final activeUntilTs = data['activeUntil'];
          final lastActiveTs = data['lastActiveAt'];

          DateTime? activeUntil = _asDateTime(activeUntilTs);
          DateTime? lastActiveAt = _asDateTime(lastActiveTs);

          final distM = Geolocator.distanceBetween(
            center.latitude,
            center.longitude,
            userLat,
            userLng,
          );
          if (distM > _radiusKm * 1000) continue;

          results.add(
            _NearbyUser(
              id: doc.id,
              name: (data['name'] as String?)?.trim(),
              username: (data['username'] as String?)?.trim(),
              photoUrls: _extractPhotos(data),
              distanceMeters: distM,
              lastActiveAt: lastActiveAt,
              activeUntil: activeUntil,
              isActive: isActive,
              postsCount: (data['postsCount'] as num?)?.toInt(),
              likesCount: (data['likesCount'] as num?)?.toInt(),
            ),
          );
        }

        results.sort((a, b) {
          final d = a.distanceMeters.compareTo(b.distanceMeters);
          if (d != 0) return d;
          final at = (a.activeUntil ?? a.lastActiveAt)?.millisecondsSinceEpoch ?? 0;
          final bt = (b.activeUntil ?? b.lastActiveAt)?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });

        setState(() {
          _users = results;
          _loading = false;
        });
      } catch (_) {
        setState(() {
          _error = "Couldn’t load nearby profiles";
          _loading = false;
        });
      }
    }, onError: (_) {
      setState(() {
        _error = "Couldn’t load nearby profiles";
        _loading = false;
      });
    });
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static List<String> _extractPhotos(Map<String, dynamic> data) {
    final single = data['profilePic'];
    final multi = data['profilePics'];
    final List<String> out = [];
    if (single is String && single.trim().isNotEmpty) out.add(single.trim());
    if (multi is List) {
      for (final x in multi) {
        if (x is String && x.trim().isNotEmpty) out.add(x.trim());
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _LoadingDeck();

    if (_error != null) {
      return const _MessageCard(
        icon: Icons.wifi_off_rounded,
        title: "Can’t reach profiles",
        subtitle: "Please pull to refresh above.",
      );
    }

    if (widget.currentPosition == null) {
      return const _MessageCard(
        icon: Icons.location_searching_rounded,
        title: "Getting your location…",
        subtitle: "Profiles will load in a moment.",
      );
    }

    if (_users.isEmpty) {
      return const _MessageCard(
        icon: Icons.person_pin_circle_rounded,
        title: "No one within 1 km",
        subtitle: "Try moving around or check back soon.",
      );
    }

    return PageView.builder(
      controller: _pageCtrl,
      physics: const BouncingScrollPhysics(),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];
        return AnimatedBuilder(
          animation: _pageCtrl,
          builder: (context, child) {
            double delta = 0;
            if (_pageCtrl.position.haveDimensions) {
              delta = index - (_pageCtrl.page ?? _pageCtrl.initialPage.toDouble());
            } else {
              delta = index.toDouble();
            }
            delta = delta.clamp(-1.0, 1.0);

            final perspective = 0.0012;
            final rotateY = delta * 0.35;
            final scale = 1 - (0.08 * delta.abs());
            final translateX = -delta * 24.0;
            final translateY = (delta.abs()) * 12.0;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, perspective)
                ..translate(translateX, translateY)
                ..rotateY(rotateY)
                ..scale(scale),
              child: child,
            );
          },
          child: _ProfileCard(
            user: u,
            cacheManager: widget.cacheManager,
            onTap: () => widget.onProfileTap?.call(u.id),
          ),
        );
      },
    );
  }
}

class _LoadingDeck extends StatefulWidget {
  @override
  State<_LoadingDeck> createState() => _LoadingDeckState();
}

class _LoadingDeckState extends State<_LoadingDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: PageController(viewportFraction: 0.82),
      itemCount: 3,
      itemBuilder: (_, __) {
        return AnimatedBuilder(
          animation: _ac,
          builder: (_, __) {
            final t = _ac.value;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08 + 0.06 * t),
                    Colors.white.withOpacity(0.03 + 0.04 * (1 - t)),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
            );
          },
        );
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MessageCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFFD6D6E7), fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final _NearbyUser user;
  final BaseCacheManager? cacheManager;
  final VoidCallback? onTap;

  const _ProfileCard({
    Key? key,
    required this.user,
    this.cacheManager,
    this.onTap,
  }) : super(key: key);

  String _distanceLabel() {
    final m = user.distanceMeters;
    if (m < 75) return "Very close";
    if (m < 250) return "Close by";
    if (m < 600) return "Nearby";
    if (m < 1000) return "Within 1 km";
    return "Around you";
  }

  bool get _isRecentlyActive {
    final now = DateTime.now();
    if (user.activeUntil != null) {
      return user.activeUntil!.isAfter(now);
    }
    if (user.lastActiveAt != null) {
      return now.difference(user.lastActiveAt!) <= kPresenceWindow;
    }
    return user.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final photo = user.photoUrls.isNotEmpty ? user.photoUrls.first : null;
    final title = user.name?.isNotEmpty == true
        ? user.name!
        : (user.username?.isNotEmpty == true ? "@${user.username!}" : "Nearby user");

    final subtitle = user.name?.isNotEmpty == true && user.username?.isNotEmpty == true
        ? "@${user.username!}"
        : _distanceLabel();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 16),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photo != null)
                CachedNetworkImage(
                  imageUrl: photo,
                  fit: BoxFit.cover,
                  cacheManager: cacheManager,
                  placeholder: (_, __) => Container(color: Colors.white10),
                  errorWidget: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF283048), Color(0xFF859398)],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _initials(user.name ?? user.username ?? "U"),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

              // soft overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.10),
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.45),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: _Glass(
                  child: Row(
                    children: [
                      Expanded(
                        child: _TitleSubtitle(
                          title: title,
                          subtitle: subtitle,
                          distanceOverride: user.name?.isNotEmpty == true &&
                              user.username?.isNotEmpty == true
                              ? _distanceLabel()
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AddFriendButton(otherUserId: user.id, mini: true),
                      if (_isRecentlyActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.green.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                              SizedBox(width: 6),
                              Text(
                                "Active",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return "U";
    final a = parts[0].isNotEmpty ? parts[0][0] : "";
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : "";
    final both = (a + b).toUpperCase();
    return both.isNotEmpty ? both : "U";
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  const _Glass({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _TitleSubtitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? distanceOverride;

  const _TitleSubtitle({
    Key? key,
    required this.title,
    required this.subtitle,
    this.distanceOverride,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sub = distanceOverride ?? subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.2,
            )),
        const SizedBox(height: 2),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFD6D6E7),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
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
  final List<String> photoUrls;
  final double distanceMeters;
  final DateTime? lastActiveAt;
  final DateTime? activeUntil;
  final bool isActive;
  final int? postsCount;
  final int? likesCount;

  _NearbyUser({
    required this.id,
    this.name,
    this.username,
    required this.photoUrls,
    required this.distanceMeters,
    this.lastActiveAt,
    this.activeUntil,
    this.isActive = false,
    this.postsCount,
    this.likesCount,
  });
}
