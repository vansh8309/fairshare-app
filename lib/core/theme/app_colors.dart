import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFF84914);
  static const Color secondary = Color(0xFF1AE558);

  static const Color lightBackground = Color(0xFFFEFEFE);
  static const Color darkBackground = Color(0xFF14142b);

  static Color getTextColor(Brightness brightness) =>
      brightness == Brightness.dark
        ? Colors.white.withOpacity(0.9) // Dark Theme Text
        : Colors.black.withOpacity(0.9); // Light Theme Text

  static Color getMutedTextColor(Brightness brightness) =>
      brightness == Brightness.dark
        ? Colors.white70 // Dark Theme Muted Text
        : Colors.black54; // Light Theme Muted Text

  static Color getDividerColor(Brightness brightness) =>
      brightness == Brightness.dark
        ? Colors.white38 // Dark Theme Divider
        : Colors.black26; // Light Theme Divider

  static Color getInputBorderColor(Brightness brightness) =>
      brightness == Brightness.dark
        ? Colors.white54 // Dark Theme Input Border
        : Colors.black38; // Light Theme Input Border

  static Color getInputFillColor(Brightness brightness) =>
      brightness == Brightness.dark
        ? Colors.white.withOpacity(0.08) // Dark Theme Input Fill
        : Colors.black.withOpacity(0.05); // Light Theme Input Fill

  static Color getDropdownIconColor(Brightness brightness) =>
      brightness == Brightness.dark
        ? Colors.white70 // Dark Theme Dropdown Icon
        : Colors.black54; // Light Theme Dropdown Icon

  static Color success = Colors.green.shade700;

  static Color getButtonForegroundColor(Color backgroundColor) {
     final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
     return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  AppColors._();
}