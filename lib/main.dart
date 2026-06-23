import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_page.dart';

import 'pages/home_page.dart';

import 'theme/app_colors.dart';

import 'pages/admin_page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

Future<Widget> getStartPage() async {
  final prefs = await SharedPreferences.getInstance();

  final uid = prefs.getString('uid');

  if (uid == null) {
    return const LoginPage();
  }

  final deviceId = prefs.getString('deviceId');

  if (deviceId == null) {
    await prefs.clear();

    return const LoginPage();
  }

final snapshot =
    await FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid)
        .get();

  if (!snapshot.exists) {
    await prefs.clear();

    return const LoginPage();
  }

  final user = snapshot.data()!;

  final activeDeviceId = user['activeDeviceId'];

  if (activeDeviceId != deviceId) {
    await prefs.clear();

    return const LoginPage();
  }

  final role = prefs.getString('role');

  if (role == 'admin') {
    return const AdminPage();
  }

  return const HomePage();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Firebase.initializeApp();

  // Ensure every device has a real Firebase Auth session before touching
  // Firestore. This is required for security rules to check request.auth.
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  final startPage = await getStartPage();

  runApp(MyApp(startPage));
}

class MyApp extends StatelessWidget {
  final Widget startPage;

  const MyApp(this.startPage, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: startPage,
      // (deleted 5-18 to solve admin login issue // routes: {'/home': (context) => const HomePage()},
    );
  }
}