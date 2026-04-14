import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color.fromARGB(255, 136, 212, 152);
  static const Color primaryDark = Color(0xFF7B68B8);
  static const Color primaryLight = Color(0xFFE8D7F1);

  // Secondary Colors
  static const Color secondary = Color.fromARGB(255, 255, 210, 117);
  static const Color secondaryDark = Color(0xFFFFA500);
  static const Color secondaryLight = Color(0xFFFFE8CC);

  // Background Colors
  static const Color background = Color.fromARGB(255, 247, 255, 247);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // Text Colors
  static const Color primaryText = Color.fromARGB(255, 47, 62, 70);
  static const Color secondaryText = Color(0xFF757575);
  static const Color hintText = Color(0xFFBDBDBD);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Accent Colors
  static const Color accent = Color.fromARGB(255, 202, 210, 197);
  static const Color accentLight = Color(0xFFE8F5E9);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF29B6F6);

  // Gradient Colors
  static const Color gradientStart = Color(0xFF7B68B8);
  static const Color gradientEnd = Color(0xFF88D498);

  // Utility Colors
  static const Color divider = Color(0xFFE0E0E0);
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color overlay = Color.fromARGB(128, 0, 0, 0);

  // Get shade of color
  static Color getGreyShade(int shade) {
    const shades = {
      50: Color(0xFFFAFAFA),
      100: Color(0xFFF5F5F5),
      200: Color(0xFFEEEEEE),
      300: Color(0xFFE0E0E0),
      400: Color(0xFFBDBDBD),
      500: Color(0xFF9E9E9E),
      600: Color(0xFF757575),
      700: Color(0xFF616161),
      800: Color(0xFF424242),
      900: Color(0xFF212121),
    };
    return shades[shade] ?? Color(0xFF9E9E9E);
  }
}