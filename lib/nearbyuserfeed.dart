import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';
import 'postdetailfeed.dart';

// Utility function: gets a usable image URL for web/mobile from either a direct URL or a storage path
Future<String> getImageUrl(String value) async {
  if (value.isEmpty) return '';
  if (value.startsWith('http')) return value;
  // Only needed on web; on mobile, paths sometimes work but on web you NEED a download url
  try {
    return await FirebaseStorage.instance.ref(value).getDownloadURL();
  } catch (e) {
    return '';
  }
}

class NearbyUserFeedSliver extends StatefulWidget {
  final Position currentPosition;
  final void Function(String userId)? onProfileTap;
  final void Function(Map<String, dynamic> postData)? onPostTap;

  const NearbyUserFeedSliver({
    Key? key,
    required this.currentPosition,
    this.onProfileTap,
    this.onPostTap,
  }) : super(key: key);

  @override
  State<NearbyUserFeedSliver> createState() => _NearbyUserFeedSliverState();
}

class _NearbyUserFeedSliverState extends State<NearbyUserFeedSliver> {
  int? _activeVideoIdx;

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLng = (lng2 - lng1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  List<List<T>> chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  void _openPostDetail(Map<String, dynamic> data, Map<String, dynamic> userData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailFeed(
          postData: data,
          userData: userData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            )),
          );
        }

        final userMap = <String, Map<String, dynamic>>{};
        final nearbyUserIds = <String>[];

        for (var doc in userSnapshot.data!.docs) {
          if (doc.id == currentUid) continue;
          final data = doc.data()! as Map<String, dynamic>;
          double? lat, lng;
          if (data['lat'] != null && data['lng'] != null) {
            lat = data['lat'] is num
                ? (data['lat'] as num).toDouble()
                : double.tryParse(data['lat'].toString());
            lng = data['lng'] is num
                ? (data['lng'] as num).toDouble()
                : double.tryParse(data['lng'].toString());
          } else if (data['location'] is GeoPoint) {
            final gp = data['location'] as GeoPoint;
            lat = gp.latitude;
            lng = gp.longitude;
          }
          if (lat == null || lng == null) continue;
          final dist = _distanceMeters(
            widget.currentPosition.latitude,
            widget.currentPosition.longitude,
            lat,
            lng,
          );
          if (dist <= 1000) {
            nearbyUserIds.add(doc.id);
            userMap[doc.id] = data;
          }
        }

        if (nearbyUserIds.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text('No nearby posts yet!', style: TextStyle(color: Colors.white70)),
              ),
            ),
          );
        }

        return FutureBuilder<List<QueryDocumentSnapshot>>(
          future: () async {
            List<QueryDocumentSnapshot> allPosts = [];
            final chunks = chunkList(nearbyUserIds, 10);

            // Fetch all posts for nearby users in chunks
            for (var chunk in chunks) {
              if (chunk.isEmpty) continue;
              final snap = await FirebaseFirestore.instance
                  .collection('posts')
                  .where('userId', whereIn: chunk)
                  .get();
              allPosts.addAll(snap.docs);
            }

            // Map to store latest post per userId
            Map<String, QueryDocumentSnapshot> latestPostPerUser = {};

            for (final postDoc in allPosts) {
              final data = postDoc.data() as Map<String, dynamic>;
              final userId = data['userId'] ?? '';
              final Timestamp? timestamp = data['timestamp'] as Timestamp?;

              if (userId.isEmpty || timestamp == null) continue;

              if (!latestPostPerUser.containsKey(userId) ||
                  timestamp.compareTo((latestPostPerUser[userId]!.data() as Map<String, dynamic>)['timestamp']) > 0) {
                latestPostPerUser[userId] = postDoc;
              }
            }

            // Convert to list and sort by timestamp descending
            final latestPostsList = latestPostPerUser.values.toList()
              ..sort((a, b) {
                final tsA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
                final tsB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
                return tsB.compareTo(tsA);
              });

            // Limit to max 20 posts
            final limitedPosts = latestPostsList.length > 20 ? latestPostsList.sublist(0, 20) : latestPostsList;

            return limitedPosts;
          }(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                )),
              );
            }
            final posts = snapshot.data!;
            if (posts.isEmpty) {
              return const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Text('No nearby posts yet!', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, idx) {
                  final post = posts[idx];
                  final data = post.data() as Map<String, dynamic>;
                  final String postUserId = data['userId'] ?? '';
                  final userData = userMap[postUserId] ?? {};
                  final String username = userData['username'] ?? 'User';
                  final String rawProfilePicUrl = userData['profilePicUrl'] ?? userData['profilePic'] ?? '';
                  final String rawPostUrl = data['mediaUrl'] ?? '';
                  final bool isVideo = (data['type'] ?? 'image') == 'video';

                  Widget profileSection = GestureDetector(
                    onTap: () {
                      if (widget.onProfileTap != null) widget.onProfileTap!(postUserId);
                    },
                    child: Column(
                      children: [
                        // Profile Picture (web compatibility)
                        FutureBuilder<String>(
                          future: getImageUrl(rawProfilePicUrl),
                          builder: (context, snap) {
                            final url = snap.data ?? '';
                            return CircleAvatar(
                              radius: 36,
                              backgroundImage: url.isNotEmpty
                                  ? NetworkImage(url)
                                  : null,
                              backgroundColor: Colors.grey[700],
                              child: url.isEmpty
                                  ? const Icon(Icons.person, size: 36, color: Colors.white)
                                  : null,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );

                  // Post Image or Video (web compatibility)
                  Widget postMediaWidget = isVideo
                      ? _AutoPlayVideoPlayer(
                    url: rawPostUrl,
                    onDoubleTap: () => _openPostDetail(data, userData),
                  )
                      : FutureBuilder<String>(
                    future: getImageUrl(rawPostUrl),
                    builder: (context, snap) {
                      final url = snap.data ?? '';
                      if (url.isEmpty) {
                        return Container(
                          height: 250,
                          color: Colors.grey[800],
                          child: const Icon(Icons.image, size: 50, color: Colors.white38),
                        );
                      }
                      return CachedNetworkImage(
                        imageUrl: url,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 250,
                          color: Colors.grey[800],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 250,
                          color: Colors.grey[800],
                          child: const Icon(Icons.error, color: Colors.red),
                        ),
                      );
                    },
                  );

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: !isVideo
                        ? () => _openPostDetail(data, userData)
                        : null,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          profileSection,
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: postMediaWidget,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: posts.length,
              ),
            );
          },
        );
      },
    );
  }
}

class _AutoPlayVideoPlayer extends StatefulWidget {
  final String url;
  final VoidCallback? onDoubleTap;
  const _AutoPlayVideoPlayer({Key? key, required this.url, this.onDoubleTap}) : super(key: key);

  @override
  State<_AutoPlayVideoPlayer> createState() => _AutoPlayVideoPlayerState();
}

class _AutoPlayVideoPlayerState extends State<_AutoPlayVideoPlayer> {
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
        height: 250,
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.error, color: Colors.red, size: 40),
        ),
      );
    }
    return _initialized
        ? GestureDetector(
      onTap: _toggleMute,
      onDoubleTap: widget.onDoubleTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.6),
              radius: 18,
              child: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    )
        : Container(
      width: double.infinity,
      height: 250,
      color: Colors.black26,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
