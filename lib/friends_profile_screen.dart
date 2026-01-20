import 'package:flutter/material.dart';

class FriendsProfileScreen extends StatefulWidget {
  final String userId;
  const FriendsProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<FriendsProfileScreen> createState() => _FriendsProfileScreenState();
}

class _FriendsProfileScreenState extends State<FriendsProfileScreen> {
  final PageController _controller = PageController(viewportFraction: 0.7);

  // Model/dummy images of men (replace with Firestore posts if needed)
  final List<String> postImages = [
    // 10+ dummy male model images (unsplash, pexels, pixabay links)
    'https://images.pexels.com/photos/614810/pexels-photo-614810.jpeg',
    'https://images.pexels.com/photos/91227/pexels-photo-91227.jpeg',
    'https://images.pexels.com/photos/220453/pexels-photo-220453.jpeg',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
    'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df',
    'https://images.unsplash.com/photo-1519125323398-675f0ddb6308',
    'https://randomuser.me/api/portraits/men/32.jpg',
    'https://randomuser.me/api/portraits/men/75.jpg',
    'https://randomuser.me/api/portraits/men/43.jpg',
    'https://randomuser.me/api/portraits/men/22.jpg',
    'https://randomuser.me/api/portraits/men/86.jpg',
    'https://randomuser.me/api/portraits/men/18.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Centered image
            Center(
              child: Image.asset(
                'assets/myfriendsprofile.png', // <-- Your asset here
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 18),
            // Carousel (fills rest of space)
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: postImages.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_controller.position.haveDimensions) {
                        value = _controller.page! - index;
                        value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
                      }
                      return Center(
                        child: Transform.scale(
                          scale: value,
                          child: Opacity(
                            opacity: value,
                            child: _PostCard(imageUrl: postImages[index]),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String imageUrl;
  const _PostCard({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.19),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
        color: Colors.grey[900],
      ),
      width: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          height: 340,
          width: 260,
          loadingBuilder: (context, child, loadingProgress) =>
          loadingProgress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
