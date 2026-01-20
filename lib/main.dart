import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🔔 Notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 🪄 Local Notifications
import 'package:geolocator/geolocator.dart'; // 📍 Location

import 'firebase_options.dart';
import 'gogglesignin.dart';
import 'editprofilescreen.dart';
import 'profilescreenui.dart';
import 'bottombar.dart';
import 'presence_scope.dart';

// 🔔 Background handler (mobile only)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("🔔 Background message: ${message.notification?.title}");
}

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background handler for mobile only
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // 🪄 Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Taggin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: const EntryFlow(),
      routes: {
        '/profile': (context) => const ProfileScreenUI(),
      },
    );
  }
}

// ---------------- AUTH + PROFILE COMPLETION GATE ----------------

class EntryFlow extends StatefulWidget {
  const EntryFlow({super.key});

  @override
  State<EntryFlow> createState() => _EntryFlowState();
}

class _EntryFlowState extends State<EntryFlow> {
  bool _loading = true;
  bool _profileComplete = false;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _checkAuthAndProfile();
  }

  // 📍 Location permission
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("⚠️ Location services disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      print("❌ Location permanently denied.");
      return;
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      final pos = await Geolocator.getCurrentPosition();
      print("📍 Location: ${pos.latitude}, ${pos.longitude}");
    }
  }

  // 🔍 Auth & profile check
  Future<void> _checkAuthAndProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final isGoogleUser =
          user != null && user.providerData.any((p) => p.providerId == 'google.com');

      if (user == null || !isGoogleUser) {
        setState(() {
          _loading = false;
          _profileComplete = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'profileComplete': false,
          'username': '',
          'city': '',
          'college': '',
          'profilePicUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        setState(() {
          _profileComplete = false;
          _loading = false;
        });
        return;
      }

      final data = userDoc.data() ?? {};
      final username = (data['username'] ?? '').toString().trim();
      final city = (data['city'] ?? '').toString().trim();
      final college = (data['college'] ?? '').toString().trim();

      final done = (data['profileComplete'] == true) &&
          username.isNotEmpty &&
          city.isNotEmpty &&
          college.isNotEmpty;

      setState(() {
        _profileComplete = done;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _profileComplete = false;
      });
      print("⚠️ Auth check error: $e");
    }
  }

  // 🔔 Save FCM Token for both Web & Mobile
  Future<void> _saveFcmToken(String uid) async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    if (kIsWeb) {
      try {
        final token = await messaging.getToken(
          vapidKey:
          "BBKe8Yf9op2PjsFDkfP6hJYYLcLb708EHPBrobhRsLhlELF5WagHt2n-XoakG9q9xZUmpKZIGjyCuNj9-kPC2M8",
        );

        if (token != null) {
          print("🌐 Web FCM Token: $token");
          await FirebaseFirestore.instance.collection("users").doc(uid).update({
            "fcmTokenWeb": token,
            "platform": "web",
            "lastUpdated": FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print("❌ Web FCM error: $e");
      }
      return;
    }

    // 📱 Mobile handling
    NotificationSettings settings = await messaging.requestPermission();
    print("🔔 Mobile permission: ${settings.authorizationStatus}");

    String? token = await messaging.getToken();
    print("📱 Mobile FCM Token: $token");

    if (token != null) {
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "fcmToken": token,
        "platform": "mobile",
        "lastUpdated": FieldValue.serverTimestamp(),
      });
    }

    // 🔔 Foreground message listener with local notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title ?? "You’ve got a new message",
          notification.body ?? "on Taggin",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'taggin_chat', // channel ID
              'Taggin Chat Notifications', // channel name
              channelDescription: 'Chat message alerts from Taggin',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final isGoogleUser =
        user != null && user.providerData.any((p) => p.providerId == 'google.com');

    if (user == null || !isGoogleUser) {
      return GoogleSignInScreen();
    }

    if (!_profileComplete) {
      return WillPopScope(
        onWillPop: () async => false,
        child: const EditProfileScreen(),
      );
    }

    if (user != null) {
      _saveFcmToken(user.uid); // 🔔 Works for both web & mobile
    }

    return PresenceScope(
      child: const BottomBar(),
    );
  }
}
