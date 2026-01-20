import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'report_button.dart'; // External widget handles reporting

class PostDetailFeed extends StatelessWidget {
  final Map<String, dynamic> postData;
  final Map<String, dynamic>? userData;

  const PostDetailFeed({Key? key, required this.postData, this.userData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String username = userData?['username'] ?? 'User';
    final String profilePicUrl = userData?['profilePicUrl'] ?? userData?['profilePic'] ?? '';
    final String postUrl = postData['mediaUrl'] ?? '';
    final bool isVideo = (postData['type'] ?? 'image') == 'video';
    final String caption = postData['caption'] ?? '';
    final timestamp = postData['timestamp'];
    final String userId = postData['userId'] ?? '';
    final String postId = postData['postId'] ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundImage: profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
                      backgroundColor: Colors.grey[700],
                      child: profilePicUrl.isEmpty
                          ? Icon(Icons.person, size: 38, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      username,
                      style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: isVideo
                    ? _FullScreenVideoPlayer(url: postUrl)
                    : postUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: postUrl,
                  height: 350,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 350,
                    color: Colors.grey[800],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 350,
                    color: Colors.grey[800],
                    child: const Icon(Icons.error, color: Colors.red, size: 50),
                  ),
                )
                    : Container(
                  height: 350,
                  color: Colors.grey[800],
                  child: const Icon(Icons.image, size: 70, color: Colors.white38),
                ),
              ),
              const SizedBox(height: 24),
              if (caption.isNotEmpty)
                Text(
                  caption,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 32),
              ReportButton(reportedUserId: userId, postId: postId),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenVideoPlayer extends StatefulWidget {
  final String url;
  const _FullScreenVideoPlayer({Key? key, required this.url}) : super(key: key);

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..setVolume(0)
      ..setLooping(true)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      }).catchError((e) {
        setState(() {
          _hasError = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: double.infinity,
        height: 350,
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.error, color: Colors.red, size: 50),
        ),
      );
    }
    return _initialized
        ? GestureDetector(
      onTap: _toggleMute,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.6),
              radius: 24,
              child: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    )
        : Container(
      width: double.infinity,
      height: 350,
      color: Colors.black26,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
