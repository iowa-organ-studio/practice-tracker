import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

import '../widgets/admin_header.dart';

import 'occupancy_page.dart';

import 'last_week_overview_page.dart';

import 'conflict_resolution_page.dart';

import 'admin_harmony_progress_page.dart';

import 'add_edit_semester_page.dart';

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

              onPressed: () {
                debugPrint("LAST WEEK BUTTON PRESSED");

                Navigator.push(
                  context,

                  MaterialPageRoute(
                    builder: (_) => const LastWeekOverviewPage(),
                  ),
                );
              },

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

              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(
                    builder: (_) => const ConflictResolutionPage(),
                  ),
                );
              },

              child: const Text("Conflict Resolution"),
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

                  MaterialPageRoute(
                    builder: (_) => const AddEditSemesterPage(),
                  ),
                );
              },

              child: const Text("Other Tools"),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: gold,
                minimumSize: const Size(260, 50),
              ),

              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(
                    builder: (_) => const AdminHarmonyProgressPage(),
                  ),
                );
              },

              child: const Text("Update Student Harmony Progress"),
            ),
          ],
        ),
      ),
    );
  }
}
