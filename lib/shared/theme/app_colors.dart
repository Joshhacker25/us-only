import 'package:flutter/material.dart';

/// Part B local colour constants for Only Us.
/// Defined here so Part B does not depend on Part A's theme file existing.
/// Exact brand hexes from the brief: Midnight Purple, Purple, Pink, Lavender.
class AppColors {
  AppColors._();

  static const Color midnight = Color(0xFF100B1F);
  static const Color surface = Color(0xFF1B1230);
  static const Color surfaceLight = Color(0xFF251A40);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFF9D6BFF);
  static const Color pink = Color(0xFFFF4D9D);
  static const Color lavender = Color(0xFFE9D5FF);
  static const Color white = Colors.white;
  static const Color muted = Color(0xFFB8A8D9);
  static const Color error = Color(0xFFFF6B81);
  static const Color success = Color(0xFF4ADE80);

  static const LinearGradient brandGradient = LinearGradient(
    colors: <Color>[purple, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: <Color>[midnight, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
