import 'package:flutter/material.dart';

import 'create_semester_page.dart';
import 'edit_semester_page.dart';

import 'add_student_page.dart';
import 'edit_student_page.dart';
import 'force_logoff_page.dart';

class AdminToolsPage extends StatelessWidget {
  const AdminToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Tools")),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,

                foregroundColor: Colors.amber,

                minimumSize: const Size(260, 50),
              ),

              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(builder: (_) => const CreateSemesterPage()),
                );
              },

              child: const Text("Add Semester"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,

                foregroundColor: Colors.amber,

                minimumSize: const Size(260, 50),
              ),

              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(builder: (_) => const EditSemesterPage()),
                );
              },

              child: const Text("Edit Semester"),
            ),

            const SizedBox(height: 60),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,

                foregroundColor: Colors.black,

                minimumSize: const Size(260, 50),
              ),

              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(builder: (_) => const AddStudentPage()),
                );
              },

              child: const Text("Add Student"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,

                foregroundColor: Colors.black,

                minimumSize: const Size(260, 50),
              ),

              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(builder: (_) => const EditStudentPage()),
                );
              },

              child: const Text("Edit Student"),
            ),
            
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(260, 50),
              ),

              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(builder: (_) => const ForceLogoffPage()),
                );
              },

              child: const Text("Force Logoff User"),
            ),
          ],
        ),
      ),
    );
  }
}
