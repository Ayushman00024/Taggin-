import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// ✅ Helper: Check current user's post count
Future<int> _getUserPostCount() async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final querySnapshot = await FirebaseFirestore.instance
      .collection('posts')
      .where('userId', isEqualTo: uid)
      .get();
  return querySnapshot.docs.length;
}

/// ✅ Mobile: Upload post (image only) with metadata
Future<bool> uploadPostToFirebase(
    BuildContext context,
    XFile pickedFile, {
      String? caption,
      String visibility = 'public',
      Map<String, dynamic>? location,
    }) async {
  try {
    int postCount = await _getUserPostCount();
    if (postCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text("Upload limit reached: You can only upload up to 3 posts."),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    final ref = FirebaseStorage.instance
        .ref()
        .child('posts')
        .child(uid)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putFile(File(pickedFile.path));
    final url = await ref.getDownloadURL();

    final postDoc = FirebaseFirestore.instance.collection('posts').doc();
    await postDoc.set({
      'postId': postDoc.id,
      'userId': uid,
      'username': userData['username'] ?? '',
      'profilePic': userData['profilePic'] ?? '',
      'mediaUrl': url,
      'type': 'image',
      'caption': caption ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'likesCount': 0,
      'visibility': visibility,
      if (location != null) 'location': location,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload successful!')),
    );
    return true;
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upload failed: $e')),
    );
    return false;
  }
}

/// ✅ Web: Upload post (image only) with metadata
Future<bool> uploadPostToFirebaseWeb(
    BuildContext context,
    Uint8List imageBytes, {
      String? caption,
      String visibility = 'public',
      Map<String, dynamic>? location,
    }) async {
  try {
    int postCount = await _getUserPostCount();
    if (postCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text("Upload limit reached: You can only upload up to 3 posts."),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    final ref = FirebaseStorage.instance
        .ref()
        .child('posts')
        .child(uid)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putData(imageBytes);
    final url = await ref.getDownloadURL();

    final postDoc = FirebaseFirestore.instance.collection('posts').doc();
    await postDoc.set({
      'postId': postDoc.id,
      'userId': uid,
      'username': userData['username'] ?? '',
      'profilePic': userData['profilePic'] ?? '',
      'mediaUrl': url,
      'type': 'image',
      'caption': caption ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'likesCount': 0,
      'visibility': visibility,
      if (location != null) 'location': location,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload successful!')),
    );
    return true;
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upload failed: $e')),
    );
    return false;
  }
}

/// ✅ Preview Screen (image + caption + visibility)
class ImagePreviewScreen extends StatefulWidget {
  final XFile? pickedFile; // For mobile
  final Uint8List? imageBytes; // For web
  final Future<void> Function(String caption, String visibility) onConfirm;

  const ImagePreviewScreen({
    Key? key,
    this.pickedFile,
    this.imageBytes,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  String _selectedVisibility = 'public';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Preview Image")),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: widget.pickedFile != null
                  ? (kIsWeb
                  ? FutureBuilder<Uint8List>(
                future: widget.pickedFile!.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (!snapshot.hasData) {
                    return const Text("Error loading image");
                  }
                  return Image.memory(snapshot.data!,
                      fit: BoxFit.contain);
                },
              )
                  : Image.file(File(widget.pickedFile!.path)))
                  : widget.imageBytes != null
                  ? Image.memory(widget.imageBytes!, fit: BoxFit.contain)
                  : const Text("No image selected"),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: "Add a caption...",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: DropdownButtonFormField<String>(
              value: _selectedVisibility,
              items: const [
                DropdownMenuItem(value: 'public', child: Text("Public")),
                DropdownMenuItem(value: 'friends', child: Text("Friends Only")),
                DropdownMenuItem(
                    value: 'location', child: Text("Location-Locked")),
              ],
              onChanged: (value) {
                setState(() => _selectedVisibility = value!);
              },
              decoration: const InputDecoration(
                labelText: "Who can see this?",
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ElevatedButton(
          onPressed: () async {
            await widget.onConfirm(
              _captionController.text.trim(),
              _selectedVisibility,
            );
          },
          child: const Text("Upload"),
        ),
      ),
    );
  }
}

/// ✅ Example usage (button to pick and preview image)
class UploadExampleButton extends StatelessWidget {
  const UploadExampleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final ImagePicker picker = ImagePicker();
        final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

        if (pickedFile != null) {
          if (kIsWeb) {
            final bytes = await pickedFile.readAsBytes();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImagePreviewScreen(
                  pickedFile: pickedFile,
                  onConfirm: (caption, visibility) async {
                    Navigator.pop(context);
                    await uploadPostToFirebaseWeb(
                      context,
                      bytes,
                      caption: caption,
                      visibility: visibility,
                    );
                  },
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImagePreviewScreen(
                  pickedFile: pickedFile,
                  onConfirm: (caption, visibility) async {
                    Navigator.pop(context);
                    await uploadPostToFirebase(
                      context,
                      pickedFile,
                      caption: caption,
                      visibility: visibility,
                    );
                  },
                ),
              ),
            );
          }
        }
      },
      child: const Text("Pick & Upload Image"),
    );
  }
}
