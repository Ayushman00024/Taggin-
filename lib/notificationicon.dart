import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationIcon extends StatelessWidget {
  final VoidCallback onTap;

  const NotificationIcon({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = NotificationService.currentUserId();
    if (currentUserId == null) {
      return _icon(hasDot: false);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.getPendingFriendRequestsStream(currentUserId),
      builder: (context, snapshot) {
        final hasDot = snapshot.hasData && snapshot.data!.isNotEmpty;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          splashColor: Colors.white10,
          child: _icon(hasDot: hasDot),
        );
      },
    );
  }

  Widget _icon({required bool hasDot}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.notifications_none_outlined, // ✅ minimal outlined bell
            size: 28,
            color: Colors.white,
          ),
        ),
        if (hasDot)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30), // 🔴 red dot
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
