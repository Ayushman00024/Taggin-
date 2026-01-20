import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ✅ Tracks profile views for Taggin.
/// Each user can increment a profile's view count only once every 24 hours.
/// After 24 hours, viewing again increases it by +1.
class ProfileVisitTracker {
  static Future<void> recordVisit(String viewedUserId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid == viewedUserId) return;

    final firestore = FirebaseFirestore.instance;
    final users = firestore.collection('users');

    final viewedRef = users.doc(viewedUserId);
    final visitRef = viewedRef.collection('visits').doc(currentUid);
    final viewerRef = users.doc(currentUid);

    try {
      final now = DateTime.now();

      // 🔎 Check if user has visited before
      final visitSnap = await visitRef.get();
      DateTime? lastVisit;

      if (visitSnap.exists) {
        final ts = (visitSnap.data()?['timestamp'] as Timestamp?)?.toDate();
        if (ts != null) lastVisit = ts;
      }

      // 🕐 Allow increment only if 24 hours passed
      bool canIncrement = false;
      if (lastVisit == null) {
        canIncrement = true;
      } else {
        final diff = now.difference(lastVisit).inHours;
        if (diff >= 24) canIncrement = true;
      }

      if (!canIncrement) {
        debugPrint('👁️ Skipped: $currentUid viewed $viewedUserId <24h ago');
        return;
      }

      // ✅ Atomic update
      final batch = firestore.batch();

      // 1️⃣ Increment profile view count
      batch.set(
        viewedRef,
        {'profileViews': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      // 2️⃣ Record visit timestamp
      batch.set(
        visitRef,
        {'timestamp': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      // 3️⃣ Optional: track analytics for viewer
      batch.set(
        viewerRef,
        {'profilesVisited': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      await batch.commit();

      debugPrint('✅ +1 Profile view recorded: $currentUid ➜ $viewedUserId');
    } catch (e, st) {
      debugPrint('⚠️ Error recording profile visit: $e');
      debugPrint(st.toString());
    }
  }
}
