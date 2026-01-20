import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class SaveLocationIcon extends StatefulWidget {
  const SaveLocationIcon({Key? key}) : super(key: key);

  @override
  State<SaveLocationIcon> createState() => _SaveLocationIconState();
}

class _SaveLocationIconState extends State<SaveLocationIcon> {
  bool _saving = false;

  Future<void> _saveCurrentLocation() async {
    setState(() => _saving = true);

    try {
      // ✅ Step 1: Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception("Location permission denied");
      }

      // ✅ Step 2: Get current location
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // ✅ Step 3: Update Firestore
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("Not logged in");

      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "lastLocation": GeoPoint(pos.latitude, pos.longitude),
        "lastLocationAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📍 Location saved successfully!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to save location: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Save my current location",
      icon: _saving
          ? const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : const Icon(Icons.my_location, color: Colors.blueAccent),
      onPressed: _saving ? null : _saveCurrentLocation,
    );
  }
}
