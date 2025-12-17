import 'package:flutter/material.dart';

/// Light theme
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: Colors.blue,
  brightness: Brightness.light,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 18),
    headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
  ),
);

/// Dark theme
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: Colors.blue,
  brightness: Brightness.dark,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 18),
    headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
  ),
);
