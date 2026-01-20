import 'dart:io' show Platform, File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img_pkg;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'uploadpost.dart';

class UploadScreenUI extends StatefulWidget {
  const UploadScreenUI({Key? key}) : super(key: key);

  @override
  State<UploadScreenUI> createState() => _UploadScreenUIState();
}

class _UploadScreenUIState extends State<UploadScreenUI> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;
  bool _uploading = false;
  final TextEditingController _captionController = TextEditingController();

  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<int> getUserPostCount() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: currentUserId)
        .get();
    return querySnapshot.docs.length;
  }

  Future<void> _handleBrowseImage() async {
    if (kIsWeb) {
      _pickFile(ImageSource.gallery);
    } else {
      PermissionStatus status = await _requestMediaPermission();
      if (status.isGranted) {
        _pickFile(ImageSource.gallery);
      } else if (status.isPermanentlyDenied) {
        _showOpenSettingsDialog();
      }
    }
  }

  Future<PermissionStatus> _requestMediaPermission() async {
    if (kIsWeb) return PermissionStatus.granted;
    return await Permission.photos.request();
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text("Permission Required", style: TextStyle(color: Colors.white)),
        content: const Text("Enable photo access from app settings.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text("Open Settings", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source, imageQuality: 100);
    if (file != null) {
      setState(() => _pickedFile = file);
    }
  }

  Future<dynamic> _compressImage(XFile file) async {
    if (kIsWeb) {
      Uint8List bytes = await file.readAsBytes();
      img_pkg.Image? image = img_pkg.decodeImage(bytes);
      if (image == null) return bytes;
      img_pkg.Image resized = img_pkg.copyResize(image, width: 1080);
      List<int> jpeg = img_pkg.encodeJpg(resized, quality: 60);
      return Uint8List.fromList(jpeg);
    } else {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 60,
        format: CompressFormat.jpeg,
      );
      return File(result!.path);
    }
  }

  Future<void> _onUploadPressed() async {
    if (_pickedFile == null) return;

    int postCount = await getUserPostCount();
    if (postCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can only upload up to 3 posts."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _uploading = true);
    final caption = _captionController.text.trim();

    bool result;
    if (kIsWeb) {
      Uint8List compressed = await _compressImage(_pickedFile!) as Uint8List;
      result = await uploadPostToFirebaseWeb(context, compressed, caption: caption);
    } else {
      File compressed = await _compressImage(_pickedFile!) as File;
      result = await uploadPostToFirebase(
        context,
        XFile(compressed.path),
        caption: caption,
      );
    }

    if (result) {
      setState(() {
        _pickedFile = null;
        _captionController.clear();
      });
    }
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Create Post",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (_pickedFile == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF1C1C1C),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.image, size: 50, color: Colors.white70),
                      const SizedBox(height: 12),
                      const Text(
                        "Add Photo",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Choose from your gallery",
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _handleBrowseImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text("Gallery"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? FutureBuilder<Uint8List>(
                        future: _pickedFile!.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 200,
                              child: Center(
                                  child: CircularProgressIndicator()),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Text("Error loading image",
                                style: TextStyle(color: Colors.white));
                          }
                          return Image.memory(snapshot.data!,
                              height: 200, fit: BoxFit.cover);
                        },
                      )
                          : Image.file(File(_pickedFile!.path),
                          height: 200, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _pickedFile = null),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  "Caption",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blueAccent),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: _uploading
                    ? const Center(
                    child:
                    CircularProgressIndicator(color: Colors.blueAccent))
                    : ElevatedButton(
                  onPressed: _onUploadPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Upload Post",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
