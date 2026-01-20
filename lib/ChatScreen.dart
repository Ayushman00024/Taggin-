import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'profilescreenui.dart';

String getChatId(String uid1, String uid2) {
  final ids = [uid1, uid2]..sort();
  return ids.join('_');
}

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String? username;
  final String? profilePic;

  const ChatScreen({
    Key? key,
    required this.otherUserId,
    this.username,
    this.profilePic,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late String myUserId;
  late String chatId;
  String? myUsername;
  String? myProfilePic;

  @override
  void initState() {
    super.initState();
    myUserId = FirebaseAuth.instance.currentUser!.uid;
    chatId = getChatId(myUserId, widget.otherUserId);
    _fetchMyInfo();
    _markAllAsRead();
  }

  Future<void> _fetchMyInfo() async {
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(myUserId).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      setState(() {
        myUsername = data['username'] ?? 'Someone';
        myProfilePic = data['profilePicUrl'] ?? '';
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final unread = await FirebaseFirestore.instance
        .collection('messages')
        .doc(chatId)
        .collection('chats')
        .where('to', isEqualTo: myUserId)
        .where('isRead', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      doc.reference.update({'isRead': true});
    }
  }

  Future<void> _deleteForMe(String messageId) async {
    await FirebaseFirestore.instance
        .collection('messages')
        .doc(chatId)
        .collection('chats')
        .doc(messageId)
        .update({
      'deletedFor': FieldValue.arrayUnion([myUserId])
    });
  }

  Future<void> _deleteForEveryone(String messageId) async {
    await FirebaseFirestore.instance
        .collection('messages')
        .doc(chatId)
        .collection('chats')
        .doc(messageId)
        .delete();
  }

  void _showDeleteOptions(BuildContext context, String messageId, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.white70),
              title: const Text("Delete for me",
                  style: TextStyle(color: Colors.white70)),
              onTap: () async {
                Navigator.pop(context);
                await _deleteForMe(messageId);
              },
            ),
            if (isMe)
              ListTile(
                leading:
                const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text("Delete for everyone",
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteForEveryone(messageId);
                },
              ),
          ],
        ),
      ),
    );
  }

  // 📨 SEND MESSAGE — triggers Firestore and Cloud Function notification
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final messageData = {
      'text': text,
      'senderId': myUserId,
      'senderName': myUsername ?? 'Someone',
      'to': widget.otherUserId,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'deletedFor': [],
    };

    await FirebaseFirestore.instance
        .collection('messages')
        .doc(chatId)
        .collection('chats')
        .add(messageData);

    // optional: update the last message for quick chat preview
    await FirebaseFirestore.instance.collection('messages').doc(chatId).set({
      'lastMessage': text,
      'lastSender': myUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _controller.clear();
  }

  void _openOtherUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreenUI(),
        settings: RouteSettings(arguments: {'userId': widget.otherUserId}),
      ),
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final am = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $am';
  }

  bool _showDateChip(int index, List<QueryDocumentSnapshot> docs) {
    if (index == docs.length - 1) return true;
    final curr =
    (docs[index].data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
    final prev =
    (docs[index + 1].data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
    if (curr == null || prev == null) return false;
    final a = curr.toDate();
    final b = prev.toDate();
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  String _dateLabel(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msg = DateTime(d.year, d.month, d.day);
    if (msg == today) return 'Today';
    if (msg == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasPic =
    (widget.profilePic != null && widget.profilePic!.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.6,
        shadowColor: Colors.white10,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              splashRadius: 24,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            GestureDetector(
              onTap: _openOtherUserProfile,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1E1E1E),
                    backgroundImage:
                    hasPic ? NetworkImage(widget.profilePic!) : null,
                    child: !hasPic
                        ? const Icon(Icons.person,
                        color: Colors.white70, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.username ?? 'Chat',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .doc(chatId)
                  .collection('chats')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet',
                        style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == myUserId;
                    final isDeletedForMe =
                    (data['deletedFor'] ?? []).contains(myUserId);

                    final showChip = _showDateChip(index, docs);

                    if (isDeletedForMe) {
                      return Column(
                        children: [
                          if (showChip)
                            _DateChip(
                                label: _dateLabel(
                                    data['timestamp'] as Timestamp?)),
                          Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 4),
                              child: Text('Message deleted',
                                  style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.white38)),
                            ),
                          ),
                        ],
                      );
                    }

                    final text = (data['text'] ?? '').toString();
                    final time =
                    _formatTime(data['timestamp'] as Timestamp?);

                    final bool showSeen =
                        isMe && (data['isRead'] == true) && index == 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showChip)
                          _DateChip(
                              label: _dateLabel(
                                  data['timestamp'] as Timestamp?)),
                        GestureDetector(
                          onLongPress: () =>
                              _showDeleteOptions(context, doc.id, isMe),
                          child: Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) const SizedBox(width: 4),
                              Flexible(
                                child: Container(
                                  margin:
                                  const EdgeInsets.symmetric(vertical: 3),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color(0xFF262626)
                                        : const Color(0xFF111111),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft:
                                      Radius.circular(isMe ? 16 : 4),
                                      bottomRight:
                                      Radius.circular(isMe ? 4 : 16),
                                    ),
                                    border: Border.all(
                                      color: Colors.white10,
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Text(
                                    text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                time,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                              if (isMe) const SizedBox(width: 2),
                            ],
                          ),
                        ),
                        if (showSeen)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 2, left: 8, right: 8, bottom: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: const [
                                Text('Seen',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10, width: 1),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        cursorColor: Colors.white70,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Message…',
                          hintStyle: TextStyle(color: Colors.white38),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.black, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding:
          const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12, width: 0.8),
          ),
          child: Text(
            label,
            style:
            const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
