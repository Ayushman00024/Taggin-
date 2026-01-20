import 'package:flutter/material.dart';

class FriendsIcon extends StatelessWidget {
  final int count; // unread messages
  final VoidCallback onTap;

  const FriendsIcon({
    Key? key,
    this.count = 0, // 👈 default value, no longer required
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasDot = count > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      splashColor: Colors.white10,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.chat_bubble_outline, // ✅ outlined chat bubble
              size: 26,
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
                  color: Color(0xFF38BDF8), // 🔵 blue dot
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
