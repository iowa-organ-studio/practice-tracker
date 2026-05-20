import 'package:flutter/material.dart';

import 'create_semester_page.dart';
import 'edit_semester_page.dart';

class AddEditSemesterPage
    extends StatelessWidget {
  const AddEditSemesterPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Add/Edit Semester",
        ),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(
                    builder:
                        (_) =>
                            const CreateSemesterPage(),
                  ),
                );
              },

              child: const Text(
                "Add Semester",
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(
                    builder:
                        (_) =>
                            const EditSemesterPage(),
                  ),
                );
              },

              child: const Text(
                "Edit Semester",
              ),
            ),
          ],
        ),
      ),
    );
  }
}