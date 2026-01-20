import 'gogglesignin.dart'; // ✅ import Google Sign-In screen

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img_pkg;
import 'package:cached_network_image/cached_network_image.dart';

import 'bottombar.dart';
import 'indian_cities.dart';
import 'addbio.dart';
import 'editprofileavatar.dart';
import 'studentcollegeselection.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _usernameController = TextEditingController();

  Uint8List? _previewBytes;
  Uint8List? _uploadBytes;

  String? _profilePicUrl;
  String? _selectedCity;
  String? _bioPreview;
  String? _selectedCollege;

  bool _isSaving = false;
  bool _loading = true;
  bool _privacyDialogShown = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPrivacyDialog());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _showPrivacyDialog() async {
    if (_privacyDialogShown || !mounted) return;
    setState(() => _privacyDialogShown = true);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.privacy_tip, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Privacy Notice', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Your profile (including photo) will be visible to other users nearby. "
              "Please do not use any private or sensitive photos.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            child: const Text(
              "I Agree",
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() => _loading = false);
        return;
      }
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = doc.data();
      if (data != null) {
        _usernameController.text = (data['username'] ?? '').toString();
        _profilePicUrl =
            (data['profilePicUrl'] ?? data['profilePic'] ?? '').toString();
        final cityStr = (data['city'] ?? '').toString();
        _selectedCity = cityStr.isEmpty ? null : cityStr;
        _selectedCollege = (data['selectedCollege'] ?? '').toString();
        _bioPreview = (data['bio'] ?? '').toString();
      }
    } catch (e) {
      _showSnack("Failed to load profile: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List> _compressBytesWeb(Uint8List original) async {
    final decoded = img_pkg.decodeImage(original);
    if (decoded == null) return original;
    final resized = img_pkg.copyResize(decoded, width: 720);
    return Uint8List.fromList(img_pkg.encodeJpg(resized, quality: 70));
  }

  Future<Uint8List> _compressBytesMobile(Uint8List original) async {
    final out = await FlutterImageCompress.compressWithList(
      original,
      quality: 70,
      minWidth: 720,
      minHeight: 720,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    return Uint8List.fromList(out);
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked == null) return;
      final original = await picked.readAsBytes();
      final compressed =
      kIsWeb ? await _compressBytesWeb(original) : await _compressBytesMobile(original);
      final provider = MemoryImage(compressed);
      await precacheImage(provider, context);
      setState(() {
        _previewBytes = compressed;
        _uploadBytes = compressed;
      });
    } catch (e) {
      _showSnack("Image pick failed: $e");
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<bool> _isUsernameAvailable(String username, String myUid) async {
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('username_lower', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    if (q.docs.isEmpty) return true;
    return q.docs.first.id == myUid;
  }

  Future<String?> _uploadImageIfNeeded(String userId) async {
    if (_uploadBytes == null) return null;
    final storageRef =
    FirebaseStorage.instance.ref().child('profile_pics/$userId/avatar.jpg');
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=604800',
    );
    await storageRef.putData(_uploadBytes!, metadata);
    final url = await storageRef.getDownloadURL();
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  String? _validateUsername(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return "Username is required.";
    if (s.length < 3) return "Username must be at least 3 characters.";
    if (s.length > 20) return "Username must be at most 20 characters.";
    final reg = RegExp(r'^[a-zA-Z0-9_\.]+$');
    if (!reg.hasMatch(s)) {
      return "Only letters, numbers, dot and underscore are allowed.";
    }
    return null;
  }

  Future<void> _saveProfile({bool goBack = false}) async {
    if (_isSaving) return;
    final usernameRaw = _usernameController.text;
    final city = _selectedCity?.trim();
    final usernameError = _validateUsername(usernameRaw);
    if (usernameError != null) {
      _showSnack(usernameError);
      return;
    }
    if (city == null || city.isEmpty) {
      _showSnack("Please select your city.");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack("Not signed in.");
        return;
      }

      final uid = user.uid;
      final username = usernameRaw.trim();
      final available = await _isUsernameAvailable(username, uid);
      if (!available) {
        _showSnack("Username already taken. Try another.");
        return;
      }

      final newPicUrl = await _uploadImageIfNeeded(uid);
      final users = FirebaseFirestore.instance.collection('users');
      final ref = users.doc(uid);

      // 🧩 Ensure document exists first
      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'uid': uid,
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 🧠 Prepare update data
      final update = <String, dynamic>{
        'username': username,
        'username_lower': username.toLowerCase(),
        'city': city,
        'city_lower': city.toLowerCase(),
        'selectedCollege': _selectedCollege ?? '',
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (user.email != null && user.email!.isNotEmpty) {
        update['email'] = user.email!;
        update['email_lower'] = user.email!.toLowerCase();
      }

      if (newPicUrl != null && newPicUrl.isNotEmpty) {
        update['profilePicUrl'] = newPicUrl;
        update['profilePic'] = newPicUrl;
        update['pfpUpdatedAt'] = FieldValue.serverTimestamp();
      }

      await ref.set(update, SetOptions(merge: true));

      if (newPicUrl != null && newPicUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(newPicUrl);
        await user.updatePhotoURL(newPicUrl).catchError((_) {});
        _profilePicUrl = newPicUrl;
        if (mounted) setState(() {});
      }

      if (!mounted) return;
      _showSnack("Profile saved!");

      if (goBack) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BottomBar()),
              (route) => false,
        );
      }
    } on FirebaseException catch (e) {
      _showSnack("Failed to save profile: ${e.message ?? e.code}");
    } catch (e) {
      _showSnack("Failed to save profile: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ImageProvider<Object>? _getImageProvider() {
    if (_previewBytes != null) return MemoryImage(_previewBytes!);
    if (_profilePicUrl != null && _profilePicUrl!.isNotEmpty) {
      final bustedUrl =
          '$_profilePicUrl&cb=${DateTime.now().millisecondsSinceEpoch}';
      return CachedNetworkImageProvider(bustedUrl);
    }
    return null;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openCollegePicker() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const StudentCollegeSelectionScreen()),
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _selectedCollege = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final collegeLabel = (_selectedCollege != null &&
        _selectedCollege!.trim().isNotEmpty)
        ? _selectedCollege!
        : 'None';
    final user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: () async {
        if (_isSaving) return false;
        final usernameError = _validateUsername(_usernameController.text);
        final cityEmpty = _selectedCity == null || _selectedCity!.isEmpty;
        if (usernameError != null || cityEmpty) {
          _showSnack("Please complete username and city before leaving.");
          return false;
        }
        await _saveProfile(goBack: true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Edit Profile',
            style:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            tooltip: 'Save & Back',
            onPressed: _isSaving ? null : () async => await _saveProfile(goBack: true),
          ),
        ),
        backgroundColor: Colors.black,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              if (user != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null
                        ? const Icon(Icons.account_circle,
                        color: Colors.white70, size: 28)
                        : null,
                  ),
                  title: Text(
                    user.email ?? "Google Account",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "Tap to login again",
                    style:
                    TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white70, size: 16),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => GoogleSignInScreen()),
                          (route) => false,
                    );
                  },
                ),
              const SizedBox(height: 32),
              Center(
                child: Image.asset('assets/edit_profile.png',
                    height: 160, fit: BoxFit.contain),
              ),
              const SizedBox(height: 40),
              EditProfileAvatar(
                imageProvider: _getImageProvider(),
                size: 144,
                isPicking: _isPickingImage,
                onTapPick: _pickImage,
              ),
              const SizedBox(height: 44),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: "Username",
                  labelStyle: const TextStyle(color: Colors.white70),
                  helperText:
                  "3–20 chars, letters/numbers/._ only",
                  helperStyle:
                  const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                    const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                    const BorderSide(color: Colors.blueAccent),
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                ),
              ),
              const SizedBox(height: 28),
              CityDropdown(
                value: _selectedCity,
                onChanged: (city) =>
                    setState(() => _selectedCity = city?.trim()),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withOpacity(0.08))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_outlined,
                        color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text('College / School',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            collegeLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                        onPressed: _openCollegePicker,
                        child: const Text('Pick / Change')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Bio",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  (_bioPreview != null &&
                      _bioPreview!.trim().isNotEmpty)
                      ? _bioPreview!
                      : "Add a short bio about yourself",
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing:
                const Icon(Icons.edit, color: Colors.blueAccent),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AddBioScreen()),
                  );
                  await _loadCurrentProfile();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                  _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                      : const Text(
                    "Save Profile",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
