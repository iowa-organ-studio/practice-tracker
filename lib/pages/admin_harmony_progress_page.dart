import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/harmony_competencies.dart';
import '../models/harmony_wedge.dart';

class AdminHarmonyProgressPage extends StatelessWidget {
  const AdminHarmonyProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Harmony Progress")),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,

            itemBuilder: (context, index) {
              final user = docs[index].data() as Map<String, dynamic>;

              return ListTile(
                title: Text(user['name'] ?? ''),

                onTap: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (_) => StudentHarmonyEditorPage(
                        uid: docs[index].id,

                        studentName: user['name'] ?? '',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class StudentHarmonyEditorPage extends StatelessWidget {
  final String uid;

  final String studentName;

  const StudentHarmonyEditorPage({
    super.key,
    required this.uid,
    required this.studentName,
  });

  Future<void> toggleState({
    required String competencyId,
    required String wedgeKey,
    required String field,
    required bool value,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'harmonyProgress': {
        competencyId: {
          wedgeKey: {field: value},
        },
      },
    }, SetOptions(merge: true));
  }

  bool competencyUnlocked(Map<String, dynamic> progress, int competencyIndex) {
    if (competencyIndex == 0) {
      return true;
    }

    final previousCompetency = harmonyCompetencies[competencyIndex - 1];

    final previousData = progress[previousCompetency.id] ?? {};

    for (final wedge in HarmonyWedge.values) {
      final wedgeKey = wedge.name;

      final complete = previousData[wedgeKey]?['complete'] == true;

      final embellished = previousData[wedgeKey]?['embellished'] == true;

      if (complete || embellished) {
        return true;
      }
    }

    return false;
  }

  bool getValue(
    Map<String, dynamic> progress,
    String competencyId,
    String wedgeKey,
    String field,
  ) {
    return progress[competencyId]?[wedgeKey]?[field] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(studentName)),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!.data() as Map<String, dynamic>;

          final progress = Map<String, dynamic>.from(
            user['harmonyProgress'] ?? {},
          );

          return ListView(
            children: harmonyCompetencies.asMap().entries.map((entry) {
              final competencyIndex = entry.key;

              final competency = entry.value;
              final unlocked = competencyUnlocked(progress, competencyIndex);
              return Card(
                margin: const EdgeInsets.all(10),

                child: Padding(
                  padding: const EdgeInsets.all(12),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        competency.title,

                        style: const TextStyle(
                          fontSize: 16,

                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      ...[
                        HarmonyWedge.hands,
                        HarmonyWedge.hymnTexture,
                        HarmonyWedge.soloSopranoTexture,
                        HarmonyWedge.soloTenorTexture,
                        HarmonyWedge.peglegTexture,
                        HarmonyWedge.keys3,
                        HarmonyWedge.keys5,
                        HarmonyWedge.keys7,
                      ].map((wedge) {
                        final wedgeKey = wedge.name;

                        final plainChecked = getValue(
                          progress,
                          competency.id,
                          wedgeKey,
                          'complete',
                        );

                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                wedgeKey == 'soloSopranoTexture'
                                    ? 'solo Sop'
                                    : wedgeKey == 'soloTenorTexture'
                                    ? 'solo Tenor'
                                    : wedgeKey == 'peglegTexture'
                                    ? 'pegleg'
                                    : wedgeKey,
                              ),
                            ),

                            const Text("Plain"),

                            Checkbox(
                              value: getValue(
                                progress,
                                competency.id,
                                wedgeKey,
                                'complete',
                              ),
                              onChanged: unlocked
                                  ? (v) {
                                      toggleState(
                                        competencyId: competency.id,

                                        wedgeKey: wedgeKey,

                                        field: 'complete',

                                        value: v ?? false,
                                      );
                                    }
                                  : null,
                            ),

                            const Text("Embellished"),

                            Checkbox(
                              value: getValue(
                                progress,
                                competency.id,
                                wedgeKey,
                                'embellished',
                              ),

                              onChanged: unlocked && plainChecked
                                  ? (v) {
                                      toggleState(
                                        competencyId: competency.id,

                                        wedgeKey: wedgeKey,

                                        field: 'embellished',

                                        value: v ?? false,
                                      );
                                    }
                                  : null,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
