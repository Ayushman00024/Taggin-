// ✅ Full HomeScreenUI with swipe left + scroll-to-top from BottomBar + GlobalPosts + unread messages (Dark Mode)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'globalposts.dart';
import 'home_appbar.dart';
import 'notification_service.dart';
import 'friendscreenui.dart';

class _TagginColors {
  static const bg = Color(0xFF0D0D0D); // 🌙 Deep dark background
  static const card = Color(0xFF1A1A1A);
  static const primary = Color(0xFF38BDF8); // 💎 Accent blue
  static const accent = Color(0xFFFF4081); // 💖 Pink
  static const text = Color(0xFFEAEAEA); // ✨ White text
  static const subtext = Color(0xFF9CA3AF); // Soft gray text
}

class HomeScreenUI extends StatefulWidget {
  const HomeScreenUI({Key? key}) : super(key: key);

  @override
  State<HomeScreenUI> createState() => HomeScreenUIState();
}

/// 👇 Public so it’s accessible by BottomBar
class HomeScreenUIState extends State<HomeScreenUI> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
  GlobalKey<RefreshIndicatorState>();
  final ScrollController _scrollController = ScrollController();

  int _refreshTick = 0;
  static HomeScreenUIState? _instance;

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    _instance = null;
    _scrollController.dispose();
    super.dispose();
  }

  /// Called when user pulls to refresh manually
  Future<void> _refreshAll() async {
    setState(() {
      _refreshTick++;
    });
    await Future.delayed(const Duration(milliseconds: 250));
  }

  /// 🔹 Public method for BottomBar — scrolls only (no reload)
  void scrollToTopOnly() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 🔹 Old method (still usable if you ever want scroll + refresh)
  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
    _refreshKey.currentState?.show();
  }

  /// 🔹 Allow BottomBar to access this state directly
  static void scrollHomeToTop() {
    _instance?.scrollToTopOnly();
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FriendScreenUI()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: _TagginColors.bg,
        body: Center(
          child: Text(
            "Please log in.",
            style: TextStyle(color: _TagginColors.text),
          ),
        ),
      );
    }

    final unreadMessagesStream = FirebaseFirestore.instance
        .collectionGroup('chats')
        .where('to', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots();

    final friendRequestsStream =
    NotificationService.getPendingFriendRequestsStream(userId);

    return Scaffold(
      backgroundColor: _TagginColors.bg,
      body: GestureDetector(
        onHorizontalDragEnd: _handleHorizontalSwipe,
        child: SafeArea(
          child: RefreshIndicator.adaptive(
            key: _refreshKey,
            color: _TagginColors.accent,
            backgroundColor: _TagginColors.card,
            displacement: 62,
            onRefresh: _refreshAll,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  backgroundColor: _TagginColors.bg,
                  elevation: 0,
                  pinned: false,
                  floating: true,
                  snap: true,
                  expandedHeight: 56,
                  flexibleSpace: FlexibleSpaceBar(
                    background: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: friendRequestsStream,
                      builder: (context, notifSnapshot) {
                        final notifCount = notifSnapshot.data?.length ?? 0;

                        return StreamBuilder<QuerySnapshot>(
                          stream: unreadMessagesStream,
                          builder: (context, msgSnapshot) {
                            final messageCount =
                                msgSnapshot.data?.docs.length ?? 0;

                            return Container(
                              color: _TagginColors.bg,
                              alignment: Alignment.center,
                              child: TagginAppBar(
                                notificationCount: notifCount,
                                messageCount: messageCount,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                // ✅ Global feed (dark)
                GlobalPosts.sliver(
                  key: ValueKey('global-$_refreshTick'),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
