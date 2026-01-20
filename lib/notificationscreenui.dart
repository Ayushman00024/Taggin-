// lib/notification_screen_ui.dart 🌙 Dark Mode Edition
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'friend_service.dart';
import 'profilescreenui.dart';

class NotificationScreenUI extends StatelessWidget {
  const NotificationScreenUI({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = NotificationService.currentUserId();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          tooltip: 'Back',
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.quicksand(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: currentUserId == null
          ? const Center(
          child: Text("Please log in", style: TextStyle(color: Colors.white)))
          : StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationService.getAllNotificationsStream(currentUserId),
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? [];
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
                  notifications.isEmpty;

          if (isLoading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child:
                CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36.0),
                child: Text(
                  'No new notifications',
                  style:
                  TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: notifications.length,
            itemBuilder: (context, i) {
              final notif = notifications[i];
              final type = notif['type'];
              final message = (notif['message'] ?? '').toString();

              if (type == 'friend_request') {
                return FriendRequestTile(
                  key: ValueKey(notif['id']),
                  requestId: notif['id'] ?? '',
                  username: (notif['username'] ?? 'User').toString().trim(),
                  profilePic: notif['profilePic'] ?? '',
                  userId: notif['userId'] ?? '',
                  status: notif['status'] ?? 'pending',
                );
              } else if (type == 'compliment') {
                final compliment = (notif['compliment'] ?? '').toString();
                final ts = notif['timestamp'];
                final DateTime? safeTime =
                ts is Timestamp ? ts.toDate() : null;

                return GenericNotificationTile(
                  key: ValueKey(notif['id'] ?? compliment),
                  message:
                  'Someone complimented you "$compliment" on your latest post',
                  icon: Icons.card_giftcard,
                  color: Colors.pinkAccent,
                  subtitle: safeTime != null
                      ? _formatTimeAgo(safeTime)
                      : null,
                );
              } else {
                return GenericNotificationTile(
                  key: ValueKey(notif['id'] ?? message),
                  message: message,
                  icon: Icons.notifications,
                  color: Colors.blueAccent,
                  subtitle: null,
                );
              }
            },
          );
        },
      ),
    );
  }

  static String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
}

// ------------------ GENERIC NOTIFICATION TILE ------------------ //

class GenericNotificationTile extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const GenericNotificationTile({
    Key? key,
    required this.message,
    this.subtitle,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.9),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
          subtitle!,
          style: const TextStyle(
            color: Colors.white54,
            fontStyle: FontStyle.italic,
          ),
        )
            : null,
      ),
    );
  }
}

// ------------------ FRIEND REQUEST TILE ------------------ //

class FriendRequestTile extends StatelessWidget {
  final String requestId;
  final String username;
  final String profilePic;
  final String userId;
  final String status;

  const FriendRequestTile({
    Key? key,
    required this.requestId,
    required this.username,
    required this.profilePic,
    required this.userId,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayUsername = username.isEmpty ? "User" : username;

    if (status == 'accepted') {
      return Card(
        color: const Color(0xFF1E2D1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        elevation: 1,
        child: ListTile(
          leading: _avatar(borderColor: Colors.green),
          title: Text(
            'You are now friends with $displayUsername',
            style: const TextStyle(
                color: Colors.lightGreenAccent, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    if (status == 'ignored') {
      return Card(
        color: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        elevation: 1,
        child: ListTile(
          leading: _avatar(borderColor: Colors.grey),
          title: Text(
            'Ignored request from $displayUsername',
            style: const TextStyle(
                color: Colors.white54, fontStyle: FontStyle.italic),
          ),
          trailing: const Icon(Icons.block, color: Colors.white24, size: 18),
        ),
      );
    }

    return Card(
      color: const Color(0xFF121212),
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white12, width: 1),
      ),
      child: ListTile(
        leading: _avatar(borderColor: Colors.blueAccent),
        title: Text(
          displayUsername,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        subtitle: const Text(
          'sent you a friend request',
          style: TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1_rounded,
                  size: 16, color: Colors.white),
              label: const Text('Accept',
                  style: TextStyle(fontSize: 13, color: Colors.white)),
              onPressed: () async {
                await FriendService.acceptFriendRequest(requestId, userId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Friend request accepted!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(72, 36),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                await FriendService.ignoreFriendRequest(requestId);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24, width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(64, 36),
                backgroundColor: Colors.transparent,
              ),
              child: const Text('Ignore',
                  style: TextStyle(fontSize: 13, color: Colors.white70)),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProfileScreenUI(),
              settings: RouteSettings(arguments: {'userId': userId}),
            ),
          );
        },
      ),
    );
  }

  Widget _avatar({Color borderColor = Colors.grey}) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundImage:
        profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
        backgroundColor: Colors.white10,
        child: profilePic.isEmpty
            ? const Icon(Icons.person, color: Colors.white70, size: 26)
            : null,
      ),
    );
  }
}
