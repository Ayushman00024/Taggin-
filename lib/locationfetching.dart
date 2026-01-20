// locationfetching.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:geolocator/geolocator.dart';

// Optional Firebase presence
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart' as fs;

typedef PositionCb = void Function(Position pos);

class LocationFetching {
  LocationFetching._();

  /// Live position your UI can listen to.
  static final ValueNotifier<Position?> position = ValueNotifier<Position?>(null);

  static StreamSubscription<Position>? _sub;
  static bool _isListening = false;

  // ===== Presence & throttling config =====
  static const Duration _presenceTtl = Duration(seconds: 30);      // visible for 30s after last bump
  static const Duration _heartbeatInterval = Duration(seconds: 10); // keep-alive while idle
  static Timer? _heartbeat;

  static Duration minSaveInterval = const Duration(seconds: 20); // throttle writes by time
  static double   minSaveMoveMeters = 30;                         // and by distance
  static DateTime? _lastSaveAt;
  static Position? _lastSavedPos;

  /// Ask for permission if needed.
  static Future<LocationPermission> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && !kIsWeb) {
      // Optionally: await Geolocator.openLocationSettings();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    // If deniedForever, caller can choose to show UI / openAppSettings.
    return permission;
  }

  /// Get a single position fix (best-effort).
  static Future<Position?> getOnce({
    LocationAccuracy accuracy = LocationAccuracy.best,
    Duration? timeLimit,
  }) async {
    final perm = await _ensurePermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }

    // Try last known first for instant UI, then a fresh fix.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        position.value = last;
      }
    } catch (_) {}

    try {
      final now = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeLimit ?? const Duration(seconds: 8),
      );
      position.value = now;
      return now;
    } catch (_) {
      // If fresh fails, return whatever we seeded (possibly null).
      return position.value;
    }
  }

  /// Start continuous updates. Call [stop] when you no longer need them.
  static Future<void> startListening({
    PositionCb? onUpdate,
    bool saveToFirestore = false,
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 10,
    Duration? timeLimit, // optional hard stop
  }) async {
    if (_isListening) return;

    final perm = await _ensurePermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return;
    }

    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );

    _isListening = true;
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
          (pos) async {
        position.value = pos;
        onUpdate?.call(pos);
        if (saveToFirestore) {
          await _saveToFirestore(pos);
        }
      },
      onError: (_) {
        stop(); // ensure we clear state if stream errors
      },
      cancelOnError: false,
    );

    if (timeLimit != null) {
      Future.delayed(timeLimit, stop);
    }
  }

  /// Stop listening to updates.
  static Future<void> stop() async {
    _isListening = false;
    await _sub?.cancel();
    _sub = null;
  }

  /// Convenience: one fix + optional stream.
  static Future<Position?> ensureAndFetch({
    PositionCb? onFirstFix,
    PositionCb? onUpdate,
    bool saveToFirestore = false,
    bool continuous = false,
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 10,
  }) async {
    final pos = await getOnce(accuracy: accuracy);
    if (pos != null) {
      onFirstFix?.call(pos);
      if (saveToFirestore) {
        await _saveToFirestore(pos);
      }
    }
    if (continuous) {
      await startListening(
        onUpdate: onUpdate,
        saveToFirestore: saveToFirestore,
        accuracy: accuracy,
        distanceFilterMeters: distanceFilterMeters,
      );
    }
    return pos;
  }

  /// Heartbeat: keeps presence "fresh" even when the user isn't moving.
  static void startHeartbeat() {
    _heartbeat?.cancel();
    // bump immediately, then every 10s
    bumpPresence();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) async {
      await bumpPresence();
    });
  }

  static Future<void> stopHeartbeat() async {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  /// Bump presence using the latest known position (or last known from OS).
  static Future<void> bumpPresence() async {
    try {
      Position? pos = position.value;
      pos ??= await Geolocator.getLastKnownPosition();
      if (pos == null) return;
      await _saveToFirestore(pos, force: true);
    } catch (_) {}
  }

  /// Optional: mark inactive in Firestore (e.g., on app pause/quit).
  static Future<void> markInactive() async {
    try {
      final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await fs.FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isActive': false,
        'lastActiveAt': fs.FieldValue.serverTimestamp(),
        // Optionally clear TTL:
        // 'activeUntil': null,
      }, fs.SetOptions(merge: true));
    } catch (_) {}
  }

  /// Writes presence + location to users/{uid} with throttling.
  static Future<void> _saveToFirestore(Position pos, {bool force = false}) async {
    try {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Throttle frequent writes unless forced (heartbeat)
      if (!force) {
        final now = DateTime.now();
        final recently = _lastSaveAt != null && now.difference(_lastSaveAt!) < minSaveInterval;

        double moved = double.infinity;
        if (_lastSavedPos != null) {
          moved = Geolocator.distanceBetween(
              _lastSavedPos!.latitude, _lastSavedPos!.longitude, pos.latitude, pos.longitude);
        }
        if (recently && moved < minSaveMoveMeters) return;
      }

      await fs.FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        // 🔐 Presence + TTL fields (used by Explore 1 km filter)
        'lastActiveAt': fs.FieldValue.serverTimestamp(),
        'isActive': true,
        'activeUntil': fs.Timestamp.fromDate(DateTime.now().add(_presenceTtl)),

        // 📍 Location fields (both granular + legacy GeoPoint for compatibility)
        'lat': pos.latitude,
        'lng': pos.longitude,
        'lastLocation': fs.GeoPoint(pos.latitude, pos.longitude),
      }, fs.SetOptions(merge: true));

      _lastSaveAt = DateTime.now();
      _lastSavedPos = pos;
    } catch (_) {
      // non-blocking
    }
  }
}
