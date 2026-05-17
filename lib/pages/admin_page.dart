import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

import '../widgets/admin_header.dart';

import 'occupancy_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AdminHeader(title: "ADMIN"),

            const SizedBox(height: 30),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                minimumSize: const Size(260, 50),
              ),

              onPressed: () {},

              child: const Text("Last Week Overview"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                minimumSize: const Size(260, 50),
              ),

              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(builder: (_) => OccupancyPage()),
                );
              },

              child: const Text("Current Organ Occupancy"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                minimumSize: const Size(260, 50),
              ),

              onPressed: () {},

              child: const Text("Conflict Resolution"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                minimumSize: const Size(260, 50),
              ),

              onPressed: () {},

              child: const Text("Other Tools"),
            ),
          ],
        ),
      ),
    );
  }
}
