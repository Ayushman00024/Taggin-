import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profilescreenui.dart';

class FriendsList extends StatefulWidget {
  const FriendsList({Key? key}) : super(key: key);

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  late Future<Map<String, List<Map<String, dynamic>>>> _friendsFuture;

  // ✅ Simple static memory cache
  static Map<String, List<Map<String, dynamic>>>? _cachedFriends;
  static DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _getFriendsWithCache();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getFriendsWithCache() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    // ✅ If cache exists and is fresh (<5 minutes old), use it
    if (_cachedFriends != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inMinutes < 5) {
      return _cachedFriends!;
    }

    // Otherwise, fetch new data
    final result = await _loadFriends(uid);

    // ✅ Store in cache
    _cachedFriends = result;
    _lastFetchTime = DateTime.now();

    return result;
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadFriends(String uid) async {
    final friendsSnap = await FirebaseFirestore.instance
        .collection('friends')
        .doc(uid)
        .collection('list')
        .get();

    final Map<String, List<Map<String, dynamic>>> groupedFriends = {};

    for (var doc in friendsSnap.docs) {
      final friendId = doc.id;
      final userSnap =
      await FirebaseFirestore.instance.collection('users').doc(friendId).get();

      final data = userSnap.data();
      if (data == null) continue;

      final username = data['username'] ?? '';
      final name = data['name'] ?? '';
      final profilePic = data['profilePic'] ?? '';
      final displayName =
      username.isNotEmpty ? username : (name.isNotEmpty ? name : 'Unknown');

      final firstLetter = displayName[0].toUpperCase();

      groupedFriends.putIfAbsent(firstLetter, () => []);
      groupedFriends[firstLetter]!.add({
        'id': friendId,
        'name': displayName,
        'profilePic': profilePic,
      });
    }

    // ✅ Sort alphabetically
    for (var key in groupedFriends.keys) {
      groupedFriends[key]!.sort((a, b) => (a['name'] as String)
          .toLowerCase()
          .compareTo((b['name'] as String).toLowerCase()));
    }

    final sortedKeys = groupedFriends.keys.toList()..sort();
    return {for (var k in sortedKeys) k: groupedFriends[k]!};
  }

  Future<void> _refreshFriends() async {
    // ✅ Force refresh and override cache
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final newData = await _loadFriends(uid);
    _cachedFriends = newData;
    _lastFetchTime = DateTime.now();

    setState(() {
      _friendsFuture = Future.value(newData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Friends',
          style: GoogleFonts.quicksand(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _refreshFriends,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _friendsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.purpleAccent));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No friends yet.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final friendsMap = snapshot.data!;
          final alphabetKeys = friendsMap.keys.toList();

          return RefreshIndicator(
            backgroundColor: Colors.black,
            color: Colors.purpleAccent,
            onRefresh: _refreshFriends,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: alphabetKeys.length,
              itemBuilder: (context, index) {
                final letter = alphabetKeys[index];
                final friends = friendsMap[letter]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        letter,
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...friends.map((f) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundImage: f['profilePic'].isNotEmpty
                              ? NetworkImage(f['profilePic'])
                              : null,
                          backgroundColor: Colors.grey.shade800,
                          child: f['profilePic'].isEmpty
                              ? const Icon(Icons.person,
                              color: Colors.white70, size: 30)
                              : null,
                        ),
                        title: Text(
                          f['name'],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.white38, size: 26),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreenUI(),
                              settings: RouteSettings(arguments: {
                                'userId': f['id'],
                              }),
                            ),
                          );
                        },
                      );
                    }),
                    Divider(color: Colors.grey.shade900, thickness: 0.8),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
