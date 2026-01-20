// horizontal_explore_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_friend_button.dart';

class HorizontalExploreScreen extends StatefulWidget {
  final String selectedCity;
  final void Function(String userId) onProfileTap;

  const HorizontalExploreScreen({
    Key? key,
    required this.selectedCity,
    required this.onProfileTap,
  }) : super(key: key);

  @override
  State<HorizontalExploreScreen> createState() => _HorizontalExploreScreenState();
}

class _HorizontalExploreScreenState extends State<HorizontalExploreScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    fetchUsersByCity();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchUsersByCity() async {
    setState(() => loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('city', isEqualTo: widget.selectedCity)
          .get();

      final docs = snapshot.docs.where((d) => d.id != currentUserId).toList();

      setState(() {
        users = docs.map((doc) {
          final data = doc.data();
          return {
            'userId': doc.id,
            'username': (data['username'] ?? 'No Name').toString(),
            'profilePic': (data['profilePic'] ?? '').toString(),
            'city': (data['city'] ?? widget.selectedCity).toString(),
            'tagline': (data['bio'] ?? '').toString(),
            'isActive': (data['isActive'] ?? false) == true,
          };
        }).toList();
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (_, __) => _ShimmerCard(anim: _shimmerCtrl),
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemCount: 6,
        ),
      );
    }

    if (users.isEmpty) {
      return SizedBox(
        height: 170,
        child: Center(
          child: _EmptyCityState(city: widget.selectedCity, onRetry: fetchUsersByCity),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final u = users[index];
          return _ProfileGlassCard(
            username: u['username'] as String,
            userId: u['userId'] as String,
            city: (u['city'] as String?) ?? widget.selectedCity,
            profilePic: (u['profilePic'] as String?) ?? '',
            tagline: (u['tagline'] as String?)?.trim(),
            isActive: (u['isActive'] as bool?) ?? false,
            onOpen: () => widget.onProfileTap(u['userId'] as String),
          );
        },
      ),
    );
  }
}

/// --------------------
/// Beautiful UI Widgets
/// --------------------

class _ProfileGlassCard extends StatefulWidget {
  final String userId;
  final String username;
  final String profilePic;
  final String city;
  final String? tagline;
  final bool isActive;
  final VoidCallback onOpen;

  const _ProfileGlassCard({
    required this.userId,
    required this.username,
    required this.profilePic,
    required this.city,
    required this.onOpen,
    this.tagline,
    this.isActive = false,
  });

  @override
  State<_ProfileGlassCard> createState() => _ProfileGlassCardState();
}

class _ProfileGlassCardState extends State<_ProfileGlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const cardWidth = 150.0;
    const cardRadius = 22.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onOpen();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x1A60A5FA),
                Color(0x1A22D3EE),
                Color(0x1A0EA5E9),
              ],
            ),
            border: Border.all(color: const Color(0x22FFFFFF), width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cardRadius),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF0D0D0D), const Color(0xFF0D0D0D).withOpacity(0.92)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Rounded-square avatar (not a circle)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: _RoundedSquareAvatar(
                    imageUrl: widget.profilePic,
                    size: 120,
                    borderRadius: 18,
                    isActive: widget.isActive,
                  ),
                ),

                // City chip
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                      boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 13, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          widget.city,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom info + Add Friend button
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if ((widget.tagline ?? '').isNotEmpty)
                        Text(
                          widget.tagline!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: AddFriendButton(otherUserId: widget.userId, mini: true),
                      ),
                    ],
                  ),
                ),

                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(width: 1.2, color: Colors.white.withOpacity(0.07)),
                        borderRadius: BorderRadius.circular(cardRadius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundedSquareAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;
  final double borderRadius;
  final bool isActive;

  const _RoundedSquareAvatar({
    required this.imageUrl,
    required this.size,
    this.borderRadius = 16,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;

    return Stack(
      children: [
        Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: hasImage
                ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 220),
              placeholder: (_, __) => Container(color: const Color(0xFF222222)),
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF222222)),
            )
                : Container(
              color: const Color(0xFF222222),
              child: const Icon(Icons.person, size: 48, color: Colors.white54),
            ),
          ),
        ),

        // Active status dot (glowing)
        if (isActive)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              height: 16,
              width: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.shade400,
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: Colors.black, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Simple shimmer placeholder (no extra packages)
class _ShimmerCard extends StatelessWidget {
  final Animation<double> anim;
  const _ShimmerCard({required this.anim});

  @override
  Widget build(BuildContext context) {
    const cardRadius = 22.0;

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value;
        final dx = lerpDouble(-1.0, 2.0, t)!; // move left->right

        return Container(
          width: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            color: const Color(0xFF171717),
            border: Border.all(color: const Color(0x11FFFFFF)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cardRadius),
            child: Stack(
              children: [
                // top block (avatar area)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                // text lines
                Positioned(
                  left: 10,
                  right: 50,
                  bottom: 56,
                  child: Container(height: 12, color: const Color(0xFF222222)),
                ),
                Positioned(
                  left: 10,
                  right: 20,
                  bottom: 40,
                  child: Container(height: 10, color: const Color(0xFF1E1E1E)),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Container(height: 36, color: const Color(0xFF232323)),
                ),
                // moving shimmer highlight
                Positioned.fill(
                  child: Transform(
                    transform: Matrix4.identity()..setEntry(0, 3, dx * 0.4),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1, -1),
                          end: Alignment(1, 1),
                          colors: const [
                            Color(0x00000000),
                            Color(0x22FFFFFF),
                            Color(0x00000000),
                          ],
                          stops: const [0.35, 0.5, 0.65],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double? lerpDouble(num a, num b, double t) => a + (b - a) * t;
}

class _EmptyCityState extends StatelessWidget {
  final String city;
  final VoidCallback onRetry;
  const _EmptyCityState({required this.city, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off_rounded, size: 28, color: Colors.white38),
        const SizedBox(height: 8),
        Text(
          'No users found in $city',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.06),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
