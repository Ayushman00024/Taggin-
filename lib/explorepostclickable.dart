import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'likehome.dart';

class ExplorePostClickable extends StatefulWidget {
  final Map<String, dynamic> post;

  const ExplorePostClickable({Key? key, required this.post}) : super(key: key);

  @override
  State<ExplorePostClickable> createState() => _ExplorePostClickableState();
}

class _ExplorePostClickableState extends State<ExplorePostClickable> {
  String get _postId =>
      (widget.post['postId'] ?? widget.post['id'] ?? widget.post['docId'] ?? '')
          .toString();

  String _pickMediaUrl(Map<String, dynamic> p) {
    final thumb = (p['thumbnailUrl'] ?? '').toString();
    if (thumb.isNotEmpty) return thumb;

    final candidates = <String>[
      'mediaUrl',
      'mediaURL',
      'imageUrl',
      'imageURL',
      'photoUrl',
      'photoURL',
      'url',
      'fileUrl',
      'fileURL',
      'picture',
      'image',
      'videoUrl',
      'thumbUrl'
    ];
    for (final k in candidates) {
      final v = p[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }

    final media = p['media'];
    if (media is List && media.isNotEmpty) {
      final first = media.first;
      if (first is Map) {
        for (final k in candidates) {
          final v = first[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      } else if (first is String && first.trim().isNotEmpty) {
        return first.trim();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrl = _pickMediaUrl(widget.post);
    final caption = (widget.post['caption'] ?? '').toString();
    final username = (widget.post['username'] ?? 'No Name').toString();
    final profilePic = (widget.post['profilePic'] ?? '').toString();
    final userId = (widget.post['userId'] ?? '').toString();
    final city = (widget.post['city'] ?? '').toString();
    final college = (widget.post['college'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Profile Row
        Row(
          children: [
            GestureDetector(
              onTap: userId.isEmpty
                  ? null
                  : () => Navigator.pushNamed(
                context,
                '/profile',
                arguments: {'userId': userId},
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundImage: profilePic.isNotEmpty
                    ? CachedNetworkImageProvider(profilePic)
                    : null,
                backgroundColor: Colors.grey.shade200,
                child: profilePic.isEmpty
                    ? const Icon(Icons.person, size: 22, color: Colors.black54)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                  if (city.isNotEmpty || college.isNotEmpty)
                    Text(
                      [
                        if (city.isNotEmpty) city,
                        if (college.isNotEmpty) "• $college",
                      ].join(' '),
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12.5),
                    ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ✅ Media Preview
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: mediaUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: mediaUrl,
            width: double.infinity,
            fit: BoxFit.contain,
            placeholder: (ctx, url) => const AspectRatio(
              aspectRatio: 1,
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.4)),
            ),
            errorWidget: (ctx, url, err) => const AspectRatio(
              aspectRatio: 1,
              child: Center(
                child: Icon(Icons.broken_image,
                    size: 48, color: Colors.black26),
              ),
            ),
          )
              : Container(
            color: Colors.grey.shade200,
            child: const AspectRatio(
              aspectRatio: 1,
              child: Center(
                child: Text('No media URL found',
                    style: TextStyle(color: Colors.black45)),
              ),
            ),
          ),
        ),

        // ✅ Caption
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              caption,
              style: const TextStyle(
                  color: Colors.black, fontSize: 14.5, height: 1.35),
            ),
          ),

        const SizedBox(height: 12),
        const Divider(color: Colors.black12, height: 1),
        const SizedBox(height: 8),

        // ✅ Likes (black)
        LikeHome(
          postId: _postId,
          iconColor: Colors.black,
          textColor: Colors.black87,
        ),
      ],
    );
  }
}
