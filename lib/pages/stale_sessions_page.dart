import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaleSessionsPage extends StatelessWidget {
  const StaleSessionsPage({super.key});

  String formatDateTime(DateTime d) {
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

    int h = d.hour % 12;

    if (h == 0) h = 12;

    final m = d.minute.toString().padLeft(2, '0');

    final suffix = d.hour >= 12 ? 'pm' : 'am';

    return "${d.day} "
        "${months[d.month - 1]} "
        "${d.year} "
        "$h:$m$suffix";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Stale Sessions")),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sessions').snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final now = DateTime.now();

          final staleDocs = snapshot.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;

            final endTime = data['endTime'];

            if (endTime != null) {
              return false;
            }

            final heartbeat = data['lastHeartbeat'];

            if (heartbeat == null) {
              return true;
            }

            final heartbeatTime = (heartbeat as Timestamp).toDate();

            return now.difference(heartbeatTime).inMinutes > 10;
          }).toList();

          if (staleDocs.isEmpty) {
            return const Center(child: Text("No stale sessions"));
          }

          return ListView(
            children: staleDocs.map((d) {
              final data = d.data() as Map<String, dynamic>;

              final start = (data['startTime'] as Timestamp).toDate();

              final heartbeat = data['lastHeartbeat'] == null
                  ? null
                  : (data['lastHeartbeat'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.all(12),

                child: Padding(
                  padding: const EdgeInsets.all(14),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        "${data['name']} — ${data['instrument']}",

                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text("Started: ${formatDateTime(start)}"),

                      const SizedBox(height: 4),

                      Text(
                        heartbeat == null
                            ? "Last heartbeat: none"
                            : "Last heartbeat: ${formatDateTime(heartbeat)}",
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "Firebase document ID: ${d.id}",

                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 14),

                      StaleSessionActions(
                        sessionId: d.id,

                        initialEndTime: heartbeat ?? DateTime.now(),
                      ),
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

class StaleSessionActions extends StatefulWidget {
  final String sessionId;

  final DateTime initialEndTime;

  const StaleSessionActions({
    super.key,
    required this.sessionId,
    required this.initialEndTime,
  });

  @override
  State<StaleSessionActions> createState() => _StaleSessionActionsState();
}

class _StaleSessionActionsState extends State<StaleSessionActions> {
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();

    controller.text = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(widget.initialEndTime);
  }

  Future<void> createEndTime() async {
    try {
      final parsed = DateFormat('yyyy-MM-dd HH:mm').parse(controller.text);

      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .update({'endTime': parsed});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End Time added to session")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid date format")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,

          decoration: const InputDecoration(
            labelText: 'Create end time',

            hintText: 'yyyy-MM-dd HH:mm',
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: createEndTime,

                child: const Text("Create End Time"),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),

                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,

                    builder: (_) {
                      return AlertDialog(
                        title: const Text("Delete Session?"),

                        content: const Text("This cannot be undone."),

                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context, false);
                            },

                            child: const Text("Cancel"),
                          ),

                          TextButton(
                            onPressed: () {
                              Navigator.pop(context, true);
                            },

                            child: const Text("Delete"),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm != true) {
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection('sessions')
                      .doc(widget.sessionId)
                      .delete();
                },

                child: const Text("Delete Session"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
