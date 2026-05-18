import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'login_page.dart';

import 'pages/home_page.dart';

import 'theme/app_colors.dart';

import 'pages/admin_page.dart';

Future<Widget> getStartPage() async {
  final prefs = await SharedPreferences.getInstance();
  final uid = prefs.getString('uid');

  if (uid != null) {
    final role = prefs.getString('role');

    if (role == 'admin') {
      return const AdminPage();
    }

    return const HomePage();
  } else {
    return const LoginPage();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

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
