import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  static String? get myUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Load the current status with [otherUserId]:
  /// - "friends"          : already friends (or self)
  /// - "pending"          : you sent a pending request
  /// - "received_pending" : you received a pending request
  /// - "add"              : no relation yet, can send request
  static Future<String> loadFriendStatus(String otherUserId) async {
    final myId = myUserId;
    if (myId == null) return "add";
    if (myId == otherUserId) return "friends";

    // Already friends?
    final friendDoc = await FirebaseFirestore.instance
        .collection('friends')
        .doc(myId)
        .collection('list')
        .doc(otherUserId)
        .get();
    if (friendDoc.exists) return "friends";

    // Did I send a pending request?
    final sentReq = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('from', isEqualTo: myId)
        .where('to', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (sentReq.docs.isNotEmpty) return "pending";

    // Did I receive a pending request?
    final recvReq = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('from', isEqualTo: otherUserId)
        .where('to', isEqualTo: myId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (recvReq.docs.isNotEmpty) return "received_pending";

    return "add";
  }

  /// Send a friend request to [otherUserId].
  static Future<void> sendFriendRequest(String otherUserId) async {
    final myId = myUserId;
    if (myId == null) return;

    // Only send if no existing pending
    final existing = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('from', isEqualTo: myId)
        .where('to', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existing.docs.isNotEmpty) return;

    // Fetch my profile info for the request payload
    String username = "";
    String profilePic = "";
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(myId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        username = data['username'] ??
            data['name'] ??
            data['displayName'] ??
            "";
        profilePic = data['profilePic'] ??
            data['photoURL'] ??
            "";
      }
    } catch (_) {}

    await FirebaseFirestore.instance.collection('friend_requests').add({
      'from': myId,
      'to'  : otherUserId,
      'username': username,
      'profilePic': profilePic,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel a sent pending friend request to [otherUserId].
  static Future<void> cancelFriendRequest(String otherUserId) async {
    final myId = myUserId;
    if (myId == null) return;

    final reqs = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('from', isEqualTo: myId)
        .where('to', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in reqs.docs) {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(doc.id)
          .delete();
    }
  }

  /// Accept an incoming friend request.
  static Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    final myId = myUserId;
    if (myId == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final reqDoc = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId);
    batch.update(reqDoc, {'status': 'accepted'});

    final friendsRef = FirebaseFirestore.instance.collection('friends');
    batch.set(
      friendsRef.doc(myId).collection('list').doc(fromUserId),
      {'since': FieldValue.serverTimestamp()},
    );
    batch.set(
      friendsRef.doc(fromUserId).collection('list').doc(myId),
      {'since': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  /// Ignore or delete an incoming request entirely.
  static Future<void> ignoreFriendRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId)
        .delete();
  }
}
