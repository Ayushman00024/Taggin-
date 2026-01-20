import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileView extends StatelessWidget {
  final String userId;
  const ProfileView({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final user = snapshot.data!;
          return Column(
            children: [
              SizedBox(height: 30),
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(user['profilePicUrl'] ?? ''),
              ),
              SizedBox(height: 8),
              Text(user['name'] ?? '', style: TextStyle(color: Colors.white, fontSize: 20)),
              Text('@${user['username'] ?? ''}', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              // Add Friend Button
              ElevatedButton(
                onPressed: () {
                  // Implement your friend request logic here
                },
                child: Text("Add Friend"),
              ),
              SizedBox(height: 20),
              // User's posts grid
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: userId)
                      .snapshots(),
                  builder: (context, postSnap) {
                    if (!postSnap.hasData) return Center(child: CircularProgressIndicator());
                    final posts = postSnap.data!.docs;
                    if (posts.isEmpty) return Center(child: Text("No Posts", style: TextStyle(color: Colors.white)));
                    return GridView.builder(
                      itemCount: posts.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                      itemBuilder: (context, idx) {
                        final post = posts[idx];
                        return Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Image.network(post['mediaUrl'], fit: BoxFit.cover),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
