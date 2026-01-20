import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notificationscreenui.dart';
import 'friendscreenui.dart';
import 'anonymouscomplimentnotification.dart';

// Helper → generate consistent chatId
String getChatId(String uid1, String uid2) {
  final ids = [uid1, uid2]..sort();
  return ids.join('_');
}

class TagginAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int? notificationCount;
  final int? messageCount;

  const TagginAppBar({
    Key? key,
    this.notificationCount,
    this.messageCount,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(90);

  // ✅ Simplified: Compliments count (based on presence only)
  Stream<int> _complimentsCountStream(String uid) {
    return FirebaseFirestore.instance
        .collection('compliments')
        .where('toUserId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return AppBar(
        title: const Text("TAGGIN"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      );
    }

    final friendRequestsStream = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('to', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    final friendsStream = FirebaseFirestore.instance
        .collection('friends')
        .doc(currentUser.uid)
        .collection('list')
        .snapshots();

    return StreamBuilder<int>(
      stream: _complimentsCountStream(currentUser.uid),
      builder: (context, compSnapshot) {
        final compCount = compSnapshot.data ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: friendRequestsStream,
          builder: (context, reqSnapshot) {
            final reqCount = reqSnapshot.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: friendsStream,
              builder: (context, friendsSnapshot) {
                if (!friendsSnapshot.hasData) {
                  return _buildAppBar(context, white, compCount, 0, reqCount);
                }

                final friends = friendsSnapshot.data!.docs;
                if (friends.isEmpty) {
                  return _buildAppBar(context, white, compCount, 0, reqCount);
                }

                return FutureBuilder<List<int>>(
                  future: Future.wait(friends.map((doc) async {
                    final friendId = doc.id;
                    final chatId = getChatId(currentUser.uid, friendId);

                    final unreadSnap = await FirebaseFirestore.instance
                        .collection('messages')
                        .doc(chatId)
                        .collection('chats')
                        .where('to', isEqualTo: currentUser.uid)
                        .where('isRead', isEqualTo: false)
                        .get();

                    return unreadSnap.docs.length;
                  })),
                  builder: (context, countsSnapshot) {
                    int msgCount = 0;
                    if (countsSnapshot.hasData) {
                      msgCount = countsSnapshot.data!.fold(0, (a, b) => a + b);
                    }

                    return _buildAppBar(
                      context,
                      white,
                      compCount,
                      msgCount,
                      reqCount,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  AppBar _buildAppBar(
      BuildContext context,
      Color iconColor,
      int compCount,
      int messageCount,
      int reqCount,
      ) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      centerTitle: false,
      toolbarHeight: 72,
      titleSpacing: 12,
      title: Text(
        "TAGGIN",
        style: GoogleFonts.montserrat(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.2,
          letterSpacing: 0.5,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.8),
        child: Container(height: 0.8, color: Colors.grey.shade800),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 6.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎁 Compliments → show red dot if any compliments exist
              _IconWithBadge(
                icon: Icons.card_giftcard,
                tooltip: "Anonymous Compliments",
                iconColor: iconColor,
                showRedDot: compCount > 0,
                dotColor: Colors.redAccent,
                glowing: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                      const AnonymousComplimentNotification(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // 🔔 Notifications → red glowing dot for pending friend requests
              _IconWithBadge(
                icon: FeatherIcons.bell,
                tooltip: "Notifications",
                iconColor: iconColor,
                showRedDot: reqCount > 0,
                dotColor: Colors.redAccent,
                glowing: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreenUI(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // 💬 Messages → red glowing dot for unread messages
              _IconWithBadge(
                icon: FeatherIcons.messageCircle,
                tooltip: "Friends / Messages",
                iconColor: iconColor,
                showRedDot: messageCount > 0,
                dotColor: Colors.redAccent,
                glowing: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FriendScreenUI(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 🔹 Icon with glowing red dot
class _IconWithBadge extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color iconColor;
  final bool showRedDot;
  final double dotSize;
  final bool glowing;
  final Color dotColor;

  const _IconWithBadge({
    Key? key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor = Colors.white,
    this.showRedDot = false,
    this.dotSize = 10,
    this.glowing = false,
    this.dotColor = Colors.redAccent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: iconColor),
    );

    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          iconWidget,
          if (showRedDot)
            Positioned(
              right: 2,
              top: 6,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: glowing
                      ? [
                    BoxShadow(
                      color: dotColor.withOpacity(0.9),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                      : [],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
