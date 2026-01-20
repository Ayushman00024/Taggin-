import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gogglesignin.dart'; // Your login screen widget

class DeleteAccountHelper {
  static Future<void> confirmAndDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text("Delete Account?",
            style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          "Are you sure you want to permanently delete your account? This cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Delete",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteAccount(context);
    }
  }

  static Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final uid = user.uid;

      // Step 1: Delete Firestore documents that belong to the user
      final batch = FirebaseFirestore.instance.batch();

      // Delete user profile
      final userDocRef =
      FirebaseFirestore.instance.collection('users').doc(uid);
      batch.delete(userDocRef);

      // Delete all posts by this user
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in postsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit Firestore deletions
      await batch.commit();

      // Step 2: Delete Firebase Auth account
      await user.delete();

      // Step 3: Navigate back to login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => GoogleSignInScreen()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting account: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
