import 'package:flutter/material.dart';

import '../models/week_status.dart';

class SemesterCard extends StatelessWidget {
  final String title;

  final List<WeekStatus> statuses;

  const SemesterCard({
    super.key,
    required this.title,
    required this.statuses,
  });

  Color getColor(WeekStatus status) {
    switch (status) {
      case WeekStatus.future:
        return Colors.grey;

      case WeekStatus.yellow:
        return Colors.yellow;

      case WeekStatus.green:
        return Colors.green;

      case WeekStatus.red:
        return Colors.red;

      case WeekStatus.offWeek:
        return Colors.black;

      case WeekStatus.star:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,

      margin: const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            Text(
              title,

              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,

              children: List.generate(
                statuses.length,
                (index) {
                  return Column(
                    children: [
                      Text(
                        "${index + 1}",

                        style: const TextStyle(
                          fontSize: 10,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Container(
                        width: 16,
                        height: 16,

                        decoration: BoxDecoration(
                          color:
                              getColor(
                                statuses[index],
                              ),

                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}