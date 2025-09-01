import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF7C4DFF),
      onPrimary: Colors.white,
      secondary: Color(0xFF64FFDA),
      onSecondary: Colors.black,
      error: Color(0xFFFF5252),
      onError: Colors.white,
      background: Color(0xFF121318),
      onBackground: Colors.white,
      surface: Color(0xFF1B1E24),
      onSurface: Colors.white,
    ),
    textTheme: GoogleFonts.montserratTextTheme(
      ThemeData.dark().textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(140, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF64FFDA), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: const Color(0xFF64FFDA),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1F2230).withOpacity(0.7),
      selectedColor: const Color(0xFF7C4DFF).withOpacity(0.2),
      labelStyle: const TextStyle(color: Colors.white),
      secondaryLabelStyle: const TextStyle(color: Colors.black),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      brightness: Brightness.dark,
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      margin: const EdgeInsets.all(12),
      color: const Color(0x991E2130), // glassy
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black54,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF7C4DFF),
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 16),
      behavior: SnackBarBehavior.floating,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xBF14161D),
      selectedItemColor: Color(0xFF64FFDA),
      unselectedItemColor: Color(0x80FFFFFF),
      elevation: 0,
    ),
    iconTheme: const IconThemeData(size: 28),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF7C4DFF),
      foregroundColor: Colors.white,
      elevation: 4,
      extendedTextStyle: TextStyle(fontWeight: FontWeight.w700),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
    }),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
