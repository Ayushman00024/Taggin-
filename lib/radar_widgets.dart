// radar_widgets.dart — deluxe UI kit for the radar
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Make profile dots open profiles:
import 'profilescreenui.dart'; // Pass uid via RouteSettings to avoid ctor mismatch.

/// ------------------------------------------------------------
/// Models
/// ------------------------------------------------------------
class Presence {
  final String uid;
  final String name;
  final String photoUrl;
  final double distance; // meters from me (computed upstream)
  const Presence({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.distance,
  });
}

/// ------------------------------------------------------------
/// Helpers
/// ------------------------------------------------------------
void _pushProfile(BuildContext context, String uid) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const ProfileScreenUI(),
      settings: RouteSettings(arguments: {'userId': uid}),
    ),
  );
}

BoxDecoration _glass({double radius = 18}) => BoxDecoration(
  color: Colors.white.withOpacity(0.06),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Colors.white.withOpacity(0.10)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ],
);

/// ------------------------------------------------------------
/// Radar user dot (other people) — tappable
/// ------------------------------------------------------------
class RadarDot extends StatelessWidget {
  final String uid;
  final String name;
  final String photoUrl;

  /// If not provided, tapping will open ProfileScreenUI.
  final VoidCallback? onTap;

  /// Optional shared cache manager (e.g., TagginCacheManager.instance)
  final BaseCacheManager? cacheManager;

  /// Sizes (⬇️ made smaller by default)
  final double avatarSize;
  final double labelWidth;

  const RadarDot({
    super.key,
    required this.uid,
    required this.name,
    required this.photoUrl,
    this.onTap,
    this.cacheManager,
    this.avatarSize = 42, // was 50
    this.labelWidth = 88, // was 100
  });

  @override
  Widget build(BuildContext context) {
    // Neon sweep ring around avatar
    final ring = Container(
      width: avatarSize + 10,
      height: avatarSize + 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFF33E1FF),
            Color(0xFF7C5CFF),
            Color(0xFFE13EFF),
            Color(0xFF33E1FF),
          ],
          stops: [0.0, 0.4, 0.8, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.30),
            blurRadius: 18,
            spreadRadius: 1.2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipOval(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.35), width: 0.6),
              shape: BoxShape.circle,
            ),
            child: _Avatar(photoUrl: photoUrl, targetSize: avatarSize, cacheManager: cacheManager),
          ),
        ),
      ),
    );

    // Glass label below avatar
    final label = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: labelWidth,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: _glass(radius: 12).copyWith(
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: const [],
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              letterSpacing: 0.15,
              height: 1.0,
            ),
          ),
        ),
      ),
    );

    // Ensure InkWell has a Material ancestor for taps/ripple
    return RepaintBoundary(
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          label: 'Nearby user $name',
          button: true,
          child: InkWell(
            onTap: onTap ?? () => _pushProfile(context, uid),
            borderRadius: BorderRadius.circular(avatarSize + 12),
            splashColor: Colors.white24,
            child: Padding(
              padding: const EdgeInsets.all(6.0), // bigger hit target
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ring,
                  const SizedBox(height: 6),
                  label,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String photoUrl;
  final double targetSize;
  final BaseCacheManager? cacheManager;
  const _Avatar({
    required this.photoUrl,
    required this.targetSize,
    this.cacheManager,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isEmpty) {
      return const Center(child: Icon(Icons.person, color: Colors.white70));
    }
    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      cacheManager: cacheManager,
      memCacheWidth: (targetSize * 2).toInt(),
      memCacheHeight: (targetSize * 2).toInt(),
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => const _MiniShimmer(),
      errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white70),
    );
  }
}

/// ------------------------------------------------------------
/// Me (center) with pulsing halo
/// ------------------------------------------------------------
class MeDot extends StatefulWidget {
  final String? photoUrl;

  /// ⬇️ slightly smaller default
  final double size;
  const MeDot({super.key, this.photoUrl, this.size = 56}); // was 64

  @override
  State<MeDot> createState() => _MeDotState();
}

class _MeDotState extends State<MeDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final base = ClipOval(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: _Avatar(photoUrl: widget.photoUrl ?? '', targetSize: size),
      ),
    );

    // Inner neon ring (static)
    final innerRing = Container(
      width: size + 10,
      height: size + 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [Color(0xFF33E1FF), Color(0xFF7C5CFF), Color(0xFF33E1FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.28),
            blurRadius: 24,
            spreadRadius: 3,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: Container(
          color: Colors.white.withOpacity(0.08),
          child: base,
        ),
      ),
    );

    // Pulsing halo
    final halo = AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_pulse.value);
        final scale = 1.0 + 0.20 * t;
        final opacity = 0.28 * (1 - t);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size + 22,
            height: size + 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.cyanAccent.withOpacity(opacity),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(opacity),
                  blurRadius: 34,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
        );
      },
    );

    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          halo,
          innerRing,
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Radar background painter (rings + crosshair + soft radial glow)
/// ------------------------------------------------------------
class RadarPainterWidget extends StatelessWidget {
  final double radarRadius;
  final Offset center;
  const RadarPainterWidget({
    super.key,
    required this.radarRadius,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RadarPainter(radarRadius: radarRadius, center: center),
        size: Size.infinite,
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double radarRadius;
  final Offset center;
  _RadarPainter({required this.radarRadius, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    // Soft radial glow disc
    final glowShader = RadialGradient(
      colors: [
        const Color(0xFF2AF0FF).withOpacity(0.06),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radarRadius * 1.05));
    final glowPaint = Paint()..shader = glowShader;
    canvas.drawCircle(center, radarRadius * 1.05, glowPaint);

    // Rings
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radarRadius * (i / 4), ring);
    }

    // Crosshair
    canvas.drawLine(
      Offset(center.dx - radarRadius, center.dy),
      Offset(center.dx + radarRadius, center.dy),
      ring,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radarRadius),
      Offset(center.dx, center.dy + radarRadius),
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.radarRadius != radarRadius || old.center != center;
}

/// ------------------------------------------------------------
/// Starry universe background with subtle rotation + twinkle
/// ------------------------------------------------------------
class UniverseBackground extends StatefulWidget {
  final AnimationController? orbitsController;
  const UniverseBackground({super.key, this.orbitsController});

  @override
  State<UniverseBackground> createState() => _UniverseBackgroundState();
}

class _UniverseBackgroundState extends State<UniverseBackground> {
  final _rng = Random(7); // deterministic seed
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _stars = List.generate(220, (i) {
      return _Star(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        r: _rng.nextDouble() * 1.3 + 0.2,
        a: 0.15 + _rng.nextDouble() * 0.35,
        tw: 0.5 + _rng.nextDouble() * 1.5, // twinkle speed
        ph: _rng.nextDouble() * 6.28318,   // phase
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final anim = widget.orbitsController;
    if (anim == null) {
      return CustomPaint(painter: _StarsPainter(_stars), size: Size.infinite);
    }
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => CustomPaint(
        painter: _StarsPainter(_stars, t: anim.value),
        size: Size.infinite,
      ),
    );
  }
}

class _Star {
  final double x, y, r, a;
  final double tw; // twinkle speed multiplier
  final double ph; // twinkle phase
  const _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.a,
    this.tw = 1.0,
    this.ph = 0.0,
  });
}

class _StarsPainter extends CustomPainter {
  final List<_Star> stars;
  final double t; // 0..1 subtle rotation
  _StarsPainter(this.stars, {this.t = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * 0.08); // slow rotation
    canvas.translate(-center.dx, -center.dy);

    // twinkle using a tiny sin()—cheap and pretty
    for (final s in stars) {
      final twinkle = 0.6 + 0.4 * sin((t * 6.28318 * s.tw) + s.ph); // 0.2..1.0
      paint.color = Colors.white.withOpacity(s.a * twinkle);
      final dx = s.x * size.width;
      final dy = s.y * size.height;
      canvas.drawCircle(Offset(dx, dy), s.r, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) =>
      old.t != t || old.stars != stars;
}

/// ------------------------------------------------------------
/// Tiny shimmer for image placeholders
/// ------------------------------------------------------------
class _MiniShimmer extends StatefulWidget {
  const _MiniShimmer();
  @override
  State<_MiniShimmer> createState() => _MiniShimmerState();
}

class _MiniShimmerState extends State<_MiniShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = (0.5 + 0.5 * sin(_c.value * 6.28318));
        return Container(
          color: Colors.white.withOpacity(0.08 + 0.08 * v),
        );
      },
    );
  }
}

/// ------------------------------------------------------------
/// OUTSIDE-RADAR banner for empty state (use as a sibling to the radar)
/// ------------------------------------------------------------
class NoNearbyBanner extends StatelessWidget {
  final String text;
  const NoNearbyBanner({super.key, this.text = 'No one nearby right now…'});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: _glass(radius: 28).copyWith(
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
                boxShadow: const [],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
