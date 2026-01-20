// my_post_clickable.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// ✅ Import Like + Comment here (no ownerId passed)
import 'likehome.dart';
import 'commenthome.dart';

class MyPostClickable extends StatefulWidget {
  /// expects: postId, userId, mediaUrl/fileUrl, type ('image'|'video'), caption?
  final Map<String, dynamic> post;

  const MyPostClickable({Key? key, required this.post}) : super(key: key);

  @override
  State<MyPostClickable> createState() => _MyPostClickableState();
}

class _MyPostClickableState extends State<MyPostClickable> {
  VideoPlayerController? _vc;
  bool _videoReady = false;
  Uint8List? _thumb;

  String get _postId {
    final p = widget.post;
    // ensure a postId for Like/Comment to work
    return (p['postId'] ?? p['id'] ?? p['docId'] ?? '').toString();
  }

  String get _mediaUrl =>
      (widget.post['mediaUrl'] ?? widget.post['fileUrl'] ?? '').toString();

  String get _type => (widget.post['type'] ?? 'image').toString();

  String get _caption => (widget.post['caption'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    if (_type == 'video' && _mediaUrl.isNotEmpty) {
      _vc = VideoPlayerController.network(_mediaUrl)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _videoReady = true);
          _vc?.setLooping(true);
          _vc?.play();
        });

      VideoThumbnail.thumbnailData(
        video: _mediaUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 800,
        quality: 80,
        timeMs: 800,
      ).then((t) {
        if (mounted) setState(() => _thumb = t);
      });
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  Widget _buildImage() {
    // No fixed AspectRatio; let it scale INSIDE available space with BoxFit.contain (no crop).
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: _mediaUrl,
                // 👇 keep full image, add letterboxing as needed
                fit: BoxFit.contain,
                placeholder: (c, _) =>
                const Center(child: CircularProgressIndicator()),
                errorWidget: (c, _, __) => const Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.white30,
                  size: 40,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        // If not ready, show thumbnail (also contained)
        if (!_videoReady) {
          if (_thumb != null) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_thumb!, fit: BoxFit.contain),
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }

        // When ready, compute a box that fits the video without cropping (letterbox).
        final ar = _vc!.value.aspectRatio; // width / height
        double childW, childH;
        if (maxW / maxH > ar) {
          // Container is wider than content: clamp by height
          childH = maxH;
          childW = childH * ar;
        } else {
          // Container is taller than content: clamp by width
          childW = maxW;
          childH = childW / ar;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: SizedBox(
                width: childW,
                height: childH,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: VideoPlayer(_vc!),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: IconButton(
                icon: Icon(
                  (_vc!.value.isPlaying)
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.white,
                  size: 38,
                ),
                onPressed: () {
                  setState(() {
                    if (_vc!.value.isPlaying) {
                      _vc!.pause();
                    } else {
                      _vc!.play();
                    }
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPostId = _postId.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Post', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Media area — fills remaining space, preserves aspect ratio, no crop/zoom.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black, // letterbox background
                  borderRadius: BorderRadius.circular(16),
                ),
                child: (_type == 'video') ? _buildVideo() : _buildImage(),
              ),
            ),
          ),

          if (_caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _caption,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),

          // ❤️ Like + 💬 Comment — only if we have a valid postId
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Row(
              children: [
                if (hasPostId) LikeHome(postId: _postId),
                const SizedBox(width: 10),
                if (hasPostId) CommentHome(postId: _postId),
                if (!hasPostId)
                  const Text(
                    'Invalid post id',
                    style: TextStyle(color: Colors.white54),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
