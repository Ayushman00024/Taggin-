import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:js' as js; // ✅ For web JS interop

import 'gogglesignin.dart';
import 'securityusermanual.dart';
import 'deleteaccount.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => GoogleSignInScreen()),
          (route) => false,
    );
  }

  /// ✅ Handles the PWA install prompt logic
  void _installPWA(BuildContext context) {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🌐 Install option is available only in the web version."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    try {
      final userAgent = js.context['navigator']['userAgent'].toString().toLowerCase();
      final isiOS = userAgent.contains('iphone') || userAgent.contains('ipad');

      if (isiOS) {
        // iOS Safari: Manual guide since iOS doesn't support the install prompt
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.black,
            title: const Text("Install on iPhone", style: TextStyle(color: Colors.white)),
            content: const Text(
              "📲 To install Taggin:\n\n"
                  "1️⃣ Tap the Share icon (📤) in Safari.\n\n"
                  "2️⃣ Choose 'Add to Home Screen'.\n\n"
                  "3️⃣ Taggin will now appear on your home screen!",
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Got it", style: TextStyle(color: Colors.lightBlueAccent)),
              ),
            ],
          ),
        );
      } else {
        // ✅ Web/Android: Call JS method to trigger install prompt
        js.context.callMethod('triggerPWAInstall');

        // ✅ Listen for when the app gets installed (detected by window event)
        js.context.callMethod('addEventListener', [
          'appinstalled',
              (event) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("✅ Taggin installed successfully!"),
                backgroundColor: Colors.green,
              ),
            );
          }
        ]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ Could not show install prompt. Please use Chrome/Edge.\nError: $e",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // ✅ Install Taggin App
          ListTile(
            leading: const Icon(Icons.download, color: Colors.greenAccent),
            title: const Text(
              'Install Taggin App',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Install Taggin on your device for a faster, smoother experience.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            onTap: () => _installPWA(context),
          ),
          const Divider(color: Colors.white12),

          // ✅ Logout Option
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('Logout', style: TextStyle(color: Colors.white)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.black87,
                  title: const Text("Logout", style: TextStyle(color: Colors.white)),
                  content: const Text(
                    "Are you sure you want to logout?",
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      child: const Text("Cancel"),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                    TextButton(
                      child: const Text("Logout"),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              );
              if (confirm == true) _logout(context);
            },
          ),
          const Divider(color: Colors.white12),

          // ✅ Delete Account Option
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            onTap: () async => DeleteAccountHelper.confirmAndDelete(context),
          ),
          const Divider(color: Colors.white12),

          // ✅ Security Manual
          ListTile(
            leading: const Icon(Icons.security, color: Colors.lightBlueAccent),
            title: const Text('Security & User Manual', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SecurityUserManualScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
