import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// 🔥 Import the clickable viewer
import 'my_post_clickable.dart';

class MyPosts extends StatefulWidget {
  final String userId;
  const MyPosts({Key? key, required this.userId}) : super(key: key);

  @override
  State<MyPosts> createState() => _MyPostsState();
}

class _MyPostsState extends State<MyPosts> {
  late Stream<QuerySnapshot> _postsStream;
  final PageController _pageController = PageController(viewportFraction: 0.7);

  @override
  void initState() {
    super.initState();
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: widget.userId)
        .snapshots();
  }

  Future<void> _deletePost(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final mediaUrl = data['mediaUrl'] ?? data['fileUrl'] ?? '';
    try {
      if (mediaUrl.isNotEmpty) {
        try {
          final ref = mediaUrl.startsWith('http')
              ? FirebaseStorage.instance.refFromURL(mediaUrl)
              : FirebaseStorage.instance.ref(mediaUrl);
          await ref.delete();
        } catch (_) {}
      }
      await doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    }
  }

  void _showDeleteDialog(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Delete Post', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this post?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePost(doc);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openPostViewer(DocumentSnapshot doc, Map<String, dynamic> data) {
    final postData = Map<String, dynamic>.from(data);
    postData['postId'] ??= doc.id; // ensure postId exists
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyPostClickable(post: postData)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 310,
      child: StreamBuilder<QuerySnapshot>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No posts yet',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          final posts = snapshot.data!.docs;
          posts.sort((a, b) {
            final tsA = (a.data() as Map<String, dynamic>)['timestamp'];
            final tsB = (b.data() as Map<String, dynamic>)['timestamp'];
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return (tsB as Timestamp).compareTo(tsA as Timestamp);
          });

          return PageView.builder(
            controller: _pageController,
            itemCount: posts.length,
            itemBuilder: (context, idx) {
              final doc = posts[idx];
              final data = doc.data() as Map<String, dynamic>;
              final mediaUrl = data['mediaUrl'] ?? data['fileUrl'] ?? '';
              final type = (data['type'] ?? 'image').toString();

              return GestureDetector(
                onTap: () => mediaUrl.isNotEmpty ? _openPostViewer(doc, data) : null,
                onLongPress: () => _showDeleteDialog(doc),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 36),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.grey[900],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: mediaUrl.isNotEmpty
                        ? _MediaContent(
                      mediaUrl: mediaUrl,
                      type: type,
                    )
                        : const Center(
                      child: Icon(Icons.image, color: Colors.white24, size: 36),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Renders media WITHOUT CROPPING (BoxFit.contain) and preserves rounded corners.
class _MediaContent extends StatelessWidget {
  final String mediaUrl;
  final String type;

  const _MediaContent({
    Key? key,
    required this.mediaUrl,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Neutral backdrop for letterboxing
    const bg = Colors.black;

    if (type == 'video') {
      return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: mediaUrl,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 800,
          quality: 80,
          timeMs: 1000,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              color: bg,
              alignment: Alignment.center,
              child: const Icon(Icons.videocam, color: Colors.white70, size: 38),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: bg),
              // Show full thumbnail without cropping
              Center(
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                ),
              ),
              const Positioned(
                bottom: 10,
                right: 10,
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
              ),
            ],
          );
        },
      );
    }

    // Image
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: bg),
        Center(
          child: CachedNetworkImage(
            imageUrl: mediaUrl,
            fit: BoxFit.contain, // ✅ prevents cropping
            placeholder: (ctx, _) => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (ctx, _, __) => const Icon(Icons.broken_image, color: Colors.white54),
          ),
        ),
      ],
    );
  }
}
