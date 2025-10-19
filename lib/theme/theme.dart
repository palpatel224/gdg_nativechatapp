import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      primarySwatch: Colors.indigo,
      primaryColor: Colors.indigo,
      scaffoldBackgroundColor: Colors.white,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 14),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
