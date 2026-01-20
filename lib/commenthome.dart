import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';

import 'profilescreenui.dart'; // for profile navigation

class CommentHome extends StatefulWidget {
  final String postId;
  final double iconSize;
  final Color iconColor;
  final Color textColor;

  const CommentHome({
    Key? key,
    required this.postId,
    this.iconSize = 26,
    this.iconColor = Colors.white,
    this.textColor = Colors.white70,
  }) : super(key: key);

  @override
  State<CommentHome> createState() => _CommentHomeState();
}

class _CommentHomeState extends State<CommentHome> {
  void _openCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CommentsSheet(postId: widget.postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);

    return InkWell(
      onTap: _openCommentsSheet,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: postRef.snapshots(),
        builder: (context, snap) {
          final doc = snap.data; // <-- property
          final map = (doc != null && doc.exists) ? doc.data() : null;
          final count = (map?['commentsCount'] ?? 0) as int;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mode_comment_outlined, size: widget.iconSize, color: widget.iconColor),
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w600),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  const _CommentsSheet({Key? key, required this.postId}) : super(key: key);

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  bool _sending = false;
  String? _postOwnerId;
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  // reply state
  String? _replyToCommentId;
  String? _replyToUsername;

  @override
  void initState() {
    super.initState();
    _loadPostOwner();
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPostOwner() async {
    final postDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .get();
    setState(() {
      _postOwnerId = (postDoc.data()?['userId'] ?? '').toString();
    });
  }

  bool _canDelete(String commentUserId) {
    if (_currentUid == null) return false;
    if (commentUserId == _currentUid) return true; // own comment/reply
    if (_postOwnerId != null && _currentUid == _postOwnerId) return true; // post owner
    return false;
  }

  Future<void> _confirmAndDeleteComment({
    required String commentId,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Delete comment?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will also delete its replies. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final commentDoc = postRef.collection('comments').doc(commentId);
    final repliesSnap = await commentDoc.collection('replies').get();

    final batch = FirebaseFirestore.instance.batch();
    // delete parent
    batch.delete(commentDoc);
    // delete replies
    for (final r in repliesSnap.docs) {
      batch.delete(r.reference);
    }
    // update count: parent + replies
    batch.update(postRef, {
      'commentsCount': FieldValue.increment(-(1 + repliesSnap.size)),
    });
    await batch.commit();
  }

  Future<void> _confirmAndDeleteReply({
    required String commentId,
    required String replyId,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Delete reply?', style: TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (ok != true) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final replyRef = postRef.collection('comments').doc(commentId).collection('replies').doc(replyId);

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(replyRef);
    batch.update(postRef, {'commentsCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    try {
      final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final username = (uDoc.data()?['username'] ?? 'User').toString();
      final profilePic = (uDoc.data()?['profilePic'] ?? '').toString();

      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      if (_replyToCommentId != null) {
        // Write a reply in subcollection
        final replyCol = postRef.collection('comments').doc(_replyToCommentId!).collection('replies');
        await FirebaseFirestore.instance.runTransaction((tx) async {
          tx.set(replyCol.doc(), {
            'userId': user.uid,
            'username': username,
            'profilePic': profilePic,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'commentsCount': FieldValue.increment(1)});
        });
      } else {
        // Top-level comment
        final commentsRef = postRef.collection('comments');
        await FirebaseFirestore.instance.runTransaction((tx) async {
          tx.set(commentsRef.doc(), {
            'userId': user.uid,
            'username': username,
            'profilePic': profilePic,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'commentsCount': FieldValue.increment(1)});
        });
      }

      _controller.clear();
      setState(() {
        _replyToCommentId = null;
        _replyToUsername = null;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startReply({required String commentId, required String username}) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToUsername = username;
    });
    // Optional: prefill @username (remove if you don't want)
    if (_controller.text.isEmpty) {
      _controller.text = '@$username ';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
    FocusScope.of(context).requestFocus(_inputFocus);
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = null;
    });
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileScreenUI(),
        settings: RouteSettings(arguments: {'userId': userId}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentsQuery = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy('timestamp', descending: true);

    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(100))),
            const SizedBox(height: 8),
            const Text('Comments', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: commentsQuery.snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No comments yet', style: TextStyle(color: Colors.white70)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 16, color: Colors.white10),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final c = d.data();
                      final commentId = d.id;
                      final username = (c['username'] ?? 'User').toString();
                      final text = (c['text'] ?? '').toString();
                      final profile = (c['profilePic'] ?? '').toString();
                      final commenterId = (c['userId'] ?? '').toString();

                      final canDelete = _canDelete(commenterId);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar → tap to profile
                              GestureDetector(
                                onTap: () => _openProfile(commenterId),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: profile.isNotEmpty ? NetworkImage(profile) : null,
                                  child: profile.isEmpty ? const Icon(Icons.person, color: Colors.white70, size: 16) : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Username + text; username tappable
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                                    children: [
                                      TextSpan(
                                        text: '$username  ',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _openProfile(commenterId),
                                      ),
                                      TextSpan(text: text),
                                    ],
                                  ),
                                ),
                              ),
                              // actions
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => _startReply(commentId: commentId, username: username),
                                    child: const Text('Reply', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ),
                                  if (canDelete)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
                                      onPressed: () => _confirmAndDeleteComment(commentId: commentId),
                                      tooltip: 'Delete',
                                    ),
                                ],
                              )
                            ],
                          ),

                          // Replies list (indented)
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('posts')
                                .doc(widget.postId)
                                .collection('comments')
                                .doc(commentId)
                                .collection('replies')
                                .orderBy('timestamp', descending: false)
                                .snapshots(),
                            builder: (context, repSnap) {
                              final reps = repSnap.data?.docs ?? [];
                              if (reps.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(left: 42, top: 8),
                                child: Column(
                                  children: reps.map((r) {
                                    final rd = r.data();
                                    final rid = r.id;
                                    final rUser = (rd['username'] ?? 'User').toString();
                                    final rTxt = (rd['text'] ?? '').toString();
                                    final rPic = (rd['profilePic'] ?? '').toString();
                                    final rUid = (rd['userId'] ?? '').toString();
                                    final rCanDelete = _canDelete(rUid);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _openProfile(rUid),
                                            child: CircleAvatar(
                                              radius: 14,
                                              backgroundColor: Colors.white10,
                                              backgroundImage: rPic.isNotEmpty ? NetworkImage(rPic) : null,
                                              child: rPic.isEmpty ? const Icon(Icons.person, color: Colors.white70, size: 14) : null,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                                                children: [
                                                  TextSpan(
                                                    text: '$rUser  ',
                                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                                    recognizer: TapGestureRecognizer()
                                                      ..onTap = () => _openProfile(rUid),
                                                  ),
                                                  TextSpan(text: rTxt),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (rCanDelete)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 18),
                                              onPressed: () => _confirmAndDeleteReply(commentId: commentId, replyId: rid),
                                              tooltip: 'Delete reply',
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1, color: Colors.white12),

            // Reply chip
            if (_replyToCommentId != null)
              Container(
                width: double.infinity,
                color: const Color(0x19191919),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Replying to @${_replyToUsername ?? ''}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelReply,
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocus,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _replyToCommentId == null ? 'Add a comment...' : 'Write a reply...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
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
