import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForceLogoffPage
    extends StatelessWidget {
  const ForceLogoffPage({
    super.key,
  });

  String formatHeartbeat(
    DateTime? d,
  ) {
    if (d == null) {
      return "none";
    }

    int h = d.hour % 12;

    if (h == 0) h = 12;

    final m = d.minute
        .toString()
        .padLeft(2, '0');

    final suffix =
        d.hour >= 12
        ? 'pm'
        : 'am';

    return "${d.month}/${d.day}/${d.year} "
        "$h:$m$suffix";
  }

  bool currentlyActive(
    DateTime? heartbeat,
  ) {
    if (heartbeat == null) {
      return false;
    }

    return DateTime.now()
            .difference(
              heartbeat,
            )
            .inMinutes <
        10;
  }

  Future<void> forceLogoff({
    required String docId,
  }) async {
    await FirebaseFirestore
        .instance
        .collection('users')
        .doc(docId)
        .update({
          'activeDeviceId': null,
          'lastDeviceHeartbeat':
              null,
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Force Logoff User",
        ),
      ),

      body: StreamBuilder<
        QuerySnapshot
      >(
        stream:
            FirebaseFirestore
                .instance
                .collection(
                  'users',
                )
                .snapshots(),

        builder: (
          context,
          snapshot,
        ) {
          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot.data!.docs.where((
                d,
              ) {
                final data =
                    d.data()
                        as Map<
                          String,
                          dynamic
                        >;

                return (data['role'] ??
                        'student') !=
                    'admin';
              }).toList();

          return ListView(
            children: [
              Padding(
                padding:
                    const EdgeInsets.all(
                      12,
                    ),

                child: Row(
                  children: const [
                    Expanded(
                      flex: 3,

                      child: Text(
                        "Name",

                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 3,

                      child: Text(
                        "Last heartbeat",

                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 2,

                      child: SizedBox(),
                    ),
                  ],
                ),
              ),

              ...docs.map((d) {
                final data =
                    d.data()
                        as Map<
                          String,
                          dynamic
                        >;

                final heartbeat =
                    data['lastDeviceHeartbeat'] ==
                        null
                    ? null
                    : (data['lastDeviceHeartbeat']
                              as Timestamp)
                          .toDate();

                final active =
                    currentlyActive(
                      heartbeat,
                    );

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),

                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,

                        child: Container(
                          color:
                              active
                              ? Colors.yellow
                              : null,

                          padding:
                              const EdgeInsets.all(
                                6,
                              ),

                          child: Text(
                            active
                                ? "${data['name']} IN USE"
                                : (data['name'] ??
                                      ''),

                            style: TextStyle(
                              fontWeight:
                                  active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        flex: 3,

                        child: Text(
                          formatHeartbeat(
                            heartbeat,
                          ),
                        ),
                      ),

                      Expanded(
                        flex: 2,

                        child: ElevatedButton(
                          style:
                              ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.red,
                              ),

                          onPressed:
                              () async {
                                final confirm = await showDialog<
                                  bool
                                >(
                                  context:
                                      context,

                                  builder:
                                      (_) {
                                        return AlertDialog(
                                          title: const Text(
                                            "Force Logoff?",
                                          ),

                                          content: const Text(
                                            "Are you sure?",
                                          ),

                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () {
                                                    Navigator.pop(
                                                      context,
                                                      false,
                                                    );
                                                  },

                                              child: const Text(
                                                "No",
                                              ),
                                            ),

                                            TextButton(
                                              onPressed:
                                                  () {
                                                    Navigator.pop(
                                                      context,
                                                      true,
                                                    );
                                                  },

                                              child: const Text(
                                                "Yes",
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                );

                                if (confirm !=
                                    true) {
                                  return;
                                }

                                await forceLogoff(
                                  docId:
                                      d.id,
                                );

                                if (!context
                                    .mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "User logged off",
                                    ),
                                  ),
                                );
                              },

                          child: const Text(
                            "Force Logoff",
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}