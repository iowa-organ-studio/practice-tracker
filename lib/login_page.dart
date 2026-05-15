import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController controller = TextEditingController();
  String error = "";
  bool loading = false;

  Future<void> login() async {
    final uid = controller.text.trim();

    if (uid.isEmpty) return;

    setState(() {
      loading = true;
      error = "";
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        setState(() {
          error = "UID not found";
          loading = false;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('uid', uid);
      await prefs.setString('name', doc['name']);
      debugPrint("Saved name: ${doc['name']}");
      await prefs.setString('role', doc['role']);

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        error = "Error connecting to server";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Enter University ID",
                style: TextStyle(fontSize: 18)),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 200,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                ),
              ),
            ),

            ElevatedButton(
              onPressed: loading ? null : login,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Login"),
            ),

            const SizedBox(height: 10),

            Text(error, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}