import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:ui';
import 'add_friend_button.dart';

class NearbyUserHorizontal extends StatefulWidget {
  final Position? currentPosition;
  final void Function(String userId)? onProfileTap;

  const NearbyUserHorizontal({
    Key? key,
    this.currentPosition,
    this.onProfileTap,
  }) : super(key: key);

  @override
  State<NearbyUserHorizontal> createState() => _NearbyUserHorizontalState();
}

class _NearbyUserHorizontalState extends State<NearbyUserHorizontal> {
  final PageController _pageController = PageController(viewportFraction: 0.54); // a bit more width for fit
  int _currentPage = 0;

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLng = (lng2 - lng1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPosition = widget.currentPosition;
    if (currentPosition == null) {
      return SizedBox(
        height: 145,
        child: Center(child: Text("No location", style: TextStyle(color: Colors.white))),
      );
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return SizedBox(
      height: 158, // best for perfect fit and no overlap
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs.where((doc) {
            if (doc.id == currentUid) return false;
            final data = doc.data()! as Map<String, dynamic>;
            double? lat;
            double? lng;
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
            if (lat == null || lng == null) return false;
            final dist = _distanceMeters(
              currentPosition.latitude,
              currentPosition.longitude,
              lat,
              lng,
            );
            return dist <= 1000;
          }).toList();

          if (users.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "No one nearby 😔",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            itemCount: users.length,
            physics: BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, idx) {
              final data = users[idx].data()! as Map<String, dynamic>;
              final profilePic = (data['profilePicUrl'] ?? data['profilePic']) as String? ?? '';
              final username = data['username'] ?? 'User';
              final userId = users[idx].id;

              double pageOffset = 0.0;
              if (_pageController.hasClients && _pageController.page != null) {
                pageOffset = _pageController.page! - idx;
              } else {
                pageOffset = _currentPage - idx.toDouble();
              }

              // Stronger glow on scrolling, fading away for non-center
              final double scale = lerpDouble(1.04, 0.80, pageOffset.abs().clamp(0.0, 1.0))!;
              final double angle = lerpDouble(0.0, 0.33, pageOffset.clamp(-1.0, 1.0))!;
              final double glowStrength = lerpDouble(1.0, 0.14, pageOffset.abs().clamp(0.0, 1.0))!;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle)
                  ..scale(scale),
                child: GestureDetector(
                  onTap: () {
                    if (widget.onProfileTap != null) {
                      widget.onProfileTap!(userId);
                    } else {
                      Navigator.pushNamed(
                        context,
                        '/profile',
                        arguments: {'userId': userId},
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    margin: EdgeInsets.symmetric(horizontal: 7, vertical: scale > 1.01 ? 0 : 5),
                    width: 92,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        // Main glow (active when at center)
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.75 * glowStrength),
                          blurRadius: 32 * glowStrength + 8,
                          spreadRadius: 6 * glowStrength,
                        ),
                        // Subtle shadow
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.12),
                          blurRadius: 4,
                          spreadRadius: 0.8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(
                        children: [
                          SizedBox.expand(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 78,   // was 56
                                  height: 78,  // was 56
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blueAccent.withOpacity(0.28 * glowStrength + 0.05),
                                        blurRadius: 16 * glowStrength + 6,
                                        spreadRadius: 1.5,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 34, // was 23
                                    backgroundColor: Colors.transparent,
                                    backgroundImage: (profilePic.isNotEmpty &&
                                        (profilePic.startsWith('http') || profilePic.startsWith('https')))
                                        ? NetworkImage(profilePic)
                                        : null,
                                    child: profilePic.isEmpty
                                        ? Icon(Icons.person, color: Colors.white, size: 38)
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  username,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.8,
                                    letterSpacing: 0.13,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.22),
                                        blurRadius: 3,
                                        offset: Offset(0, 1.5),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                  child: AddFriendButton(otherUserId: userId, mini: true),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
