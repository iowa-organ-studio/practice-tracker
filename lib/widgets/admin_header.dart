import 'package:flutter/material.dart';

class AdminHeader extends StatelessWidget {
  final String title;

  const AdminHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 72,

      child: Row(
        children: [
          Container(
            width: 150,

            color: Colors.black,

            alignment: Alignment.centerLeft,

            padding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                ),

            child: Text(
              title,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: Row(
              children: List.generate(
                18,
                (index) {
                  return Expanded(
                    child: Container(
                      color:
                          index.isEven
                              ? const Color(
                                0xFFD4AF37,
                              )
                              : Colors.black,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}