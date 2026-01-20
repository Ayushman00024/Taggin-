// presence_scope.dart
//
// Wrap your signed-in app with PresenceScope to keep presence + location alive
// across every screen. Requires: locationfetching.dart (with heartbeat + writes).

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'locationfetching.dart';

class PresenceScope extends StatefulWidget {
  final Widget child;

  const PresenceScope({super.key, required this.child});

  @override
  State<PresenceScope> createState() => _PresenceScopeState();
}

class _PresenceScopeState extends State<PresenceScope>
    with WidgetsBindingObserver {
  Timer? _kick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start presence immediately for the whole app subtree
    _startPresence();

    // Kick again shortly after first frame (helps on some browsers/devices)
    _kick = Timer(const Duration(seconds: 1), _startPresence);
  }

  // Starts GPS (with throttled writes) + a periodic heartbeat
  void _startPresence() {
    // One fix now + continuous stream; writes lat/lng + isActive + activeUntil
    LocationFetching.ensureAndFetch(saveToFirestore: true, continuous: true);
    // Heartbeat keeps presence fresh even when the user isn’t moving
    LocationFetching.startHeartbeat();
    // Optional immediate bump so the user appears instantly
    LocationFetching.bumpPresence();
  }

  // Stops heartbeat and marks user inactive
  void _stopPresence() {
    LocationFetching.stopHeartbeat();
    LocationFetching.markInactive();
    LocationFetching.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Mobile + most web cases
    if (state == AppLifecycleState.resumed) {
      _startPresence();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopPresence();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kick?.cancel();
    _stopPresence();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/* ──────────────────────────────────────────────────────────────────────────
   OPTIONAL (Web): If you want stricter tab visibility handling, add the
   `visibility_detector` package to pubspec and wrap `widget.child` with it.

   dependencies:
     visibility_detector: ^0.4.0+2

   Then, in build():
   return VisibilityDetector(
     key: const Key('presence_scope_visibility'),
     onVisibilityChanged: (info) {
       final visible = info.visibleFraction > 0.0;
       if (visible) {
         _startPresence();
       } else {
         _stopPresence();
       }
     },
     child: widget.child,
   );

   This makes users auto-inactive when the tab is hidden, and active again
   when it becomes visible.
   ────────────────────────────────────────────────────────────────────────── */
