import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> getFirstName() async {
  final prefs = await SharedPreferences.getInstance();

  final name = prefs.getString('name') ?? "";

  debugPrint("Loaded name: $name");

  if (name.isEmpty) return "";

  return name.split(" ")[0];
}

Future<String> getUid() async {
  final prefs = await SharedPreferences.getInstance();

  return prefs.getString('uid') ?? "";
}

Future<Map<String, String>> getUserInfo() async {
  final prefs = await SharedPreferences.getInstance();

  return {
    'name': prefs.getString('name') ?? '',
    'degree': prefs.getString('degree') ?? '',
    'year': prefs.getString('year') ?? '',
    'semester': prefs.getString('semester') ?? '',
  };
}

Future<int> getMinimumWeeklyMinutes() async {
  final uid = await getUid();

  final snapshot =
      await FirebaseFirestore
          .instance
          .collection('users')
          .doc(uid)
          .get();

  if (!snapshot.exists) {
    return 0;
  }

  final data = snapshot.data()!;

  return ((data['minimumWeeklyMinutes'] ?? 0)
          as num)
      .toInt();
}
