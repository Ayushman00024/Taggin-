// lib/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  // Get current logged-in user id
  static String? currentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // ------------------ FRIEND REQUESTS ------------------ //

  static Stream<List<Map<String, dynamic>>> getFriendRequestsStream(
      String userId) {
    return FirebaseFirestore.instance
        .collection('friend_requests')
        .where('to', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final username = (data['username'] ?? 'User').toString();
        return {
          'id': doc.id,
          'type': 'friend_request',
          'userId': data['from'] ?? '',
          'username': username,
          'profilePic': data['profilePic'] ?? '',
          'timestamp': data['timestamp'] ?? Timestamp.now(),
          'status': data['status'] ?? 'pending',
          'message': "$username sent you a friend request",
        };
      }).toList();
    });
  }

  static Stream<List<Map<String, dynamic>>> getPendingFriendRequestsStream(
      String userId) {
    return getFriendRequestsStream(userId);
  }

  static Future<void> acceptFriendRequest(
      String requestId, String fromUserId) async {
    final myId = currentUserId();
    if (myId == null) return;

    final friendsRef = FirebaseFirestore.instance.collection('friends');
    final batch = FirebaseFirestore.instance.batch();

    final reqDoc =
    FirebaseFirestore.instance.collection('friend_requests').doc(requestId);
    batch.update(reqDoc, {'status': 'accepted'});

    final myFriendDoc = friendsRef.doc(myId).collection('list').doc(fromUserId);
    final theirFriendDoc =
    friendsRef.doc(fromUserId).collection('list').doc(myId);

    batch.set(myFriendDoc, {'since': FieldValue.serverTimestamp()});
    batch.set(theirFriendDoc, {'since': FieldValue.serverTimestamp()});

    await batch.commit();
  }

  static Future<void> ignoreFriendRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId)
        .update({'status': 'ignored'});
  }

  // ------------------ ANONYMOUS COMPLIMENTS ------------------ //

  static Future<void> addAnonymousCompliment({
    required String toUserId,
    required String compliment,
    required String postId,
  }) async {
    final notifRef =
    FirebaseFirestore.instance.collection('notifications').doc();

    final fromUserId = currentUserId();

    await notifRef.set({
      'id': notifRef.id,
      'to': toUserId,
      'from': 'anonymous',
      'fromUserId': fromUserId ?? '', // hidden but useful for moderation
      'type': 'compliment',
      'compliment': compliment,
      'postId': postId, // ✅ link to post
      'message': 'Someone complimented you "$compliment" on your latest post',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Increment compliment count safely
    await FirebaseFirestore.instance
        .collection('users')
        .doc(toUserId)
        .set({'complimentsCount': FieldValue.increment(1)},
        SetOptions(merge: true))
        .catchError((_) {
      // ignore if field not present yet
    });
  }

  static Stream<List<Map<String, dynamic>>> getComplimentsStream(
      String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('to', isEqualTo: userId)
        .where('type', isEqualTo: 'compliment')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final compliment = (data['compliment'] ?? '').toString().trim();

        return {
          'id': data['id'] ?? doc.id,
          'type': 'compliment',
          'compliment': compliment,
          'postId': data['postId'] ?? '', // ✅ keep postId in memory
          'timestamp': data['timestamp'] ?? Timestamp.now(),
          'message':
          'Someone complimented you "$compliment" on your latest post',
        };
      }).toList();
    });
  }

  // ------------------ MERGED NOTIFICATIONS ------------------ //

  static Stream<List<Map<String, dynamic>>> getAllNotificationsStream(
      String userId) {
    final friendRequestsStream = getFriendRequestsStream(userId);
    final complimentsStream = getComplimentsStream(userId);

    return Stream.multi((controller) {
      List<Map<String, dynamic>> latestFriendReqs = [];
      List<Map<String, dynamic>> latestCompliments = [];

      void emit() {
        final all = [...latestFriendReqs, ...latestCompliments];
        all.sort((a, b) {
          final tsA = a['timestamp'] is Timestamp
              ? (a['timestamp'] as Timestamp).toDate()
              : DateTime(0);
          final tsB = b['timestamp'] is Timestamp
              ? (b['timestamp'] as Timestamp).toDate()
              : DateTime(0);
          return tsB.compareTo(tsA);
        });
        controller.add(all);
      }

      final sub1 = friendRequestsStream.listen((data) {
        latestFriendReqs = data;
        emit();
      });

      final sub2 = complimentsStream.listen((data) {
        latestCompliments = data;
        emit();
      });

      controller.onCancel = () {
        sub1.cancel();
        sub2.cancel();
      };
    });
  }
}
