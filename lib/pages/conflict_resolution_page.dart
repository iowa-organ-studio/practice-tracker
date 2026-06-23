import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'conflict_detail_page.dart';

class ConflictResolutionPage extends StatelessWidget {
  const ConflictResolutionPage({super.key});

  String formatTime(DateTime t) {
    int h = t.hour % 12;

    if (h == 0) h = 12;

    final m = t.minute.toString().padLeft(2, '0');

    final suffix = t.hour >= 12 ? 'pm' : 'am';

    return "$h:$m$suffix";
  }

  String formatDate(DateTime d) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conflict Resolution")),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conflicts')
            .where('resolved', isEqualTo: false)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading conflicts"));
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                "Currently no conflicts needing resolution",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          final groupedConflicts = <String, QueryDocumentSnapshot>{};

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;

            final sessionRefs = List<Map<String, dynamic>>.from(
              data['sessionRefs'] ?? [],
            );

            final normalized =
                sessionRefs.map((e) => "${e['uid']}_${e['sessionId']}").toList()
                  ..sort();

            final key = "${data['organ']}_${normalized.join('_')}";

            groupedConflicts[key] = doc;
          }

          final uniqueDocs = groupedConflicts.values.toList();

          if (uniqueDocs.isEmpty) {
            return const Center(
              child: Text(
                "Currently no conflicts needing resolution",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.builder(
            itemCount: uniqueDocs.length,

            itemBuilder: (context, index) {
              final conflict = uniqueDocs[index].data() as Map<String, dynamic>;

              final uids = List<String>.from(conflict['uids'] ?? []);

              final createdAt = (conflict['createdAt'] as Timestamp).toDate();

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (_) =>
                          ConflictDetailPage(conflictId: uniqueDocs[index].id),
                    ),
                  );
                },

                child: Card(
                  margin: const EdgeInsets.all(12),

                  child: Padding(
                    padding: const EdgeInsets.all(14),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          conflict['organ'] ?? '',

                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "${formatDate(createdAt)} — ${formatTime(createdAt)}",
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          "Students:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 4),

                        ...uids.map(
                          (u) => Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(u)
                                  .get(),
                              builder: (context, userSnapshot) {
                                String name = u;
                                if (userSnapshot.hasData &&
                                    userSnapshot.data!.exists) {
                                  final userData =
                                      userSnapshot.data!.data()
                                          as Map<String, dynamic>;
                                  name = userData['name'] ?? u;
                                }
                                return Text("• $name ($u)");
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
