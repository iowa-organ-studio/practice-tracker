import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'pages/admin_page.dart';
import 'pages/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController controller = TextEditingController();
  String error = "";
  bool loading = false;

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    String? deviceId = prefs.getString('deviceId');

    if (deviceId != null) {
      return deviceId;
    }

    deviceId = const Uuid().v4();

    await prefs.setString('deviceId', deviceId);

    return deviceId;
  }

  Future<void> login() async {
    final uid = controller.text.trim();

    if (uid.isEmpty) return;

    setState(() {
      loading = true;
      error = "";
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!snapshot.exists) {
        setState(() {
          error = "UID not found";
          loading = false;
        });

        return;
      }

      final data = snapshot.data()!;

      final deviceId = await getOrCreateDeviceId();

      final activeDeviceId = data['activeDeviceId'];

      final heartbeat = data['lastDeviceHeartbeat'];

      bool otherDeviceActive = false;

      if (activeDeviceId != null &&
          activeDeviceId != deviceId &&
          heartbeat != null) {
        final heartbeatTime = (heartbeat as Timestamp).toDate();

        otherDeviceActive =
            DateTime.now().difference(heartbeatTime) <
            const Duration(minutes: 10);
      }

      if (otherDeviceActive) {
        setState(() {
          error = "Account already active on another device";

          loading = false;
        });

        return;
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('uid', uid);

      await prefs.setString('name', data['name']);

      await prefs.setString('role', data['role'] ?? 'student');

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'activeDeviceId': deviceId,

        'lastDeviceHeartbeat': DateTime.now(),
      });

      if (!mounted) return;

      if ((data['role'] ?? 'student') == 'admin') {
        Navigator.pushReplacement(
          context,

          MaterialPageRoute(builder: (_) => const AdminPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,

          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Enter University ID",
                    style: TextStyle(fontSize: 18),
                  ),

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

                  const SizedBox(height: 28),

                  // ── Privacy disclaimer ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.privacy_tip_outlined,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Privacy Notice",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "This app does NOT use or track your location. \n\n" 
                          "It relies solely on self-reported practice. \n\n"
                          "Your location and practice history is not visible to other students."
                          ,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── End privacy disclaimer ──────────────────────────
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}