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
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          error = "UID not found";
          loading = false;
        });

        return;
      }

      final doc = query.docs.first;

      final data = doc.data();

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
      debugPrint("Saved name: ${data['name']}");
      await prefs.setString('role', data['role'] ?? 'student');
      await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Enter University ID", style: TextStyle(fontSize: 18)),

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
