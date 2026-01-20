import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chatscreen.dart';
import 'profilescreenui.dart';
import 'bottombar.dart';

String getChatId(String uid1, String uid2) {
  final ids = [uid1, uid2]..sort();
  return ids.join('_');
}

Future<void> removeFriend(String myId, String friendId) async {
  final myRef = FirebaseFirestore.instance
      .collection('friends')
      .doc(myId)
      .collection('list')
      .doc(friendId);
  final friendRef = FirebaseFirestore.instance
      .collection('friends')
      .doc(friendId)
      .collection('list')
      .doc(myId);
  await myRef.delete();
  await friendRef.delete();
}

class FriendScreenUI extends StatefulWidget {
  const FriendScreenUI({Key? key}) : super(key: key);

  @override
  State<FriendScreenUI> createState() => _FriendScreenUIState();
}

class _FriendScreenUIState extends State<FriendScreenUI> {
  late Stream<List<Map<String, dynamic>>> _friendStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _friendStream = _buildSortedFriends(uid);
    }
  }

  Future<void> _refreshData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      setState(() {
        _friendStream = _buildSortedFriends(uid);
      });
    }
    await Future.delayed(const Duration(milliseconds: 800)); // smooth reload
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Please log in to view messages.",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const BottomBar()),
                (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Center(
                      child: Text(
                        'My Friends',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: Colors.grey.shade800),
              const SizedBox(height: 18),

              // ✅ Pull-to-refresh area
              Expanded(
                child: RefreshIndicator(
                  backgroundColor: Colors.black,
                  color: Colors.purpleAccent,
                  onRefresh: _refreshData,
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _friendStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      final chatList = snapshot.data!;
                      if (chatList.isEmpty) {
                        return const Center(
                          child: Text(
                            "No friends yet.",
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: chatList.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final chat = chatList[index];
                          return _FriendListTile(
                            friendId: chat['friendId'],
                            profilePic: chat['profilePic'],
                            displayName: chat['displayName'],
                            name: chat['lastMessage'],
                            unread: chat['unread'],
                            onOpenChat: () async {
                              final unreadDocs = await FirebaseFirestore
                                  .instance
                                  .collection('messages')
                                  .doc(getChatId(
                                FirebaseAuth
                                    .instance.currentUser!.uid,
                                chat['friendId'],
                              ))
                                  .collection('chats')
                                  .where('to',
                                  isEqualTo: FirebaseAuth
                                      .instance.currentUser!.uid)
                                  .where('isRead', isEqualTo: false)
                                  .get();

                              for (final doc in unreadDocs.docs) {
                                await doc.reference
                                    .update({'isRead': true});
                              }

                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    otherUserId: chat['friendId'],
                                    username: chat['displayName'],
                                    profilePic: chat['profilePic'],
                                  ),
                                ),
                              );

                              // 👇 Refresh automatically after returning
                              _refreshData();
                            },
                            onLongPress: () async {
                              final remove = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1C1C1C),
                                  title: const Text('Remove Friend?',
                                      style: TextStyle(color: Colors.white)),
                                  content: const Text(
                                    'Do you want to remove this friend?',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel',
                                          style: TextStyle(
                                              color: Colors.white70)),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Remove',
                                          style: TextStyle(
                                              color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );
                              if (remove == true) {
                                await removeFriend(
                                  FirebaseAuth.instance.currentUser!.uid,
                                  chat['friendId'],
                                );
                                _refreshData();
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ Stream same as before (kept intact)
Stream<List<Map<String, dynamic>>> _buildSortedFriends(String myId) {
  final friendsRef = FirebaseFirestore.instance
      .collection('friends')
      .doc(myId)
      .collection('list');

  return friendsRef.snapshots().asyncMap((friendsSnap) async {
    final futures = friendsSnap.docs.map((doc) async {
      final friendId = doc.id;
      final chatId = getChatId(myId, friendId);
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .get();

      final lastMsgSnap = await FirebaseFirestore.instance
          .collection('messages')
          .doc(chatId)
          .collection('chats')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      int unreadCount = await FirebaseFirestore.instance
          .collection('messages')
          .doc(chatId)
          .collection('chats')
          .where('to', isEqualTo: myId)
          .where('isRead', isEqualTo: false)
          .get()
          .then((snap) => snap.docs.length);

      String lastMessage = '';
      Timestamp? lastTime;
      bool sentByMe = false;

      if (lastMsgSnap.docs.isNotEmpty) {
        final msg = lastMsgSnap.docs.first.data();
        lastMessage = msg['text'] ?? '';
        lastTime = msg['timestamp'];
        sentByMe = msg['from'] == myId;
      }

      final userData = userSnap.data() ?? {};
      final profilePic = userData['profilePic'] ?? '';
      final username = userData['username'] ?? '';
      final name = userData['name'] ?? '';
      final displayName =
      username.isNotEmpty ? username : (name.isNotEmpty ? name : 'Unknown');

      if (sentByMe && lastMessage.isNotEmpty) {
        lastMessage = "You: $lastMessage";
      }

      return {
        'friendId': friendId,
        'profilePic': profilePic,
        'displayName': displayName,
        'lastMessage': lastMessage.isNotEmpty ? lastMessage : name,
        'lastTime': lastTime ?? Timestamp(0, 0),
        'unread': unreadCount,
      };
    });

    final results = await Future.wait(futures);

    results.sort((a, b) {
      final timeA = a['lastTime'] as Timestamp?;
      final timeB = b['lastTime'] as Timestamp?;
      return (timeB?.compareTo(timeA ?? Timestamp(0, 0)) ?? 0);
    });

    return results;
  });
}

class _FriendListTile extends StatelessWidget {
  final String friendId;
  final String profilePic;
  final String displayName;
  final String name;
  final int unread;
  final VoidCallback onOpenChat;
  final VoidCallback onLongPress;

  const _FriendListTile({
    required this.friendId,
    required this.profilePic,
    required this.displayName,
    required this.name,
    required this.unread,
    required this.onOpenChat,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenChat,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade800),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreenUI(),
                    settings: RouteSettings(arguments: {'userId': friendId}),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 26,
                backgroundImage:
                profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                backgroundColor: Colors.grey.shade800,
                child: profilePic.isEmpty
                    ? const Icon(Icons.person,
                    color: Colors.white70, size: 32)
                    : null,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.shade100
                                .withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
