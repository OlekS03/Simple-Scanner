import 'package:flutter/material.dart';

/// Global theme
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: Colors.blue,
  brightness: Brightness.light,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 18),
    headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
  ),
);
