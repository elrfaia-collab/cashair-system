import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF1A73E8);
  static const secondaryColor = Color(0xFF34A853);
  static const dangerColor = Color(0xFFEA4335);
  static const warningColor = Color(0xFFFBBC04);
  static const bgColor = Color(0xFFF5F7FA);
  static const cardColor = Colors.white;
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: bgColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardTheme: CardTheme(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Cairo'),
      displayMedium: TextStyle(fontFamily: 'Cairo'),
      bodyLarge: TextStyle(fontFamily: 'Cairo'),
      bodyMedium: TextStyle(fontFamily: 'Cairo'),
      titleLarge: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
    ),
  );
}

class AppConstants {
  static const String appName = 'نظام الكاشير';
  static const String version = '1.0.0';
  static const List<String> paymentMethods = ['كاش', 'بطاقة', 'تحويل'];
  static const List<String> units = ['قطعة', 'كيلو', 'جرام', 'لتر', 'مل', 'علبة', 'كرتون', 'دستة'];
}
