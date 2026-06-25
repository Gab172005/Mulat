import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Gemini-inspired palette
const kBg = Color(0xFF131314);
const kSurface = Color(0xFF1E1F22);
const kPrimary = Color(0xFFA8C7FA);
const kPrimaryDark = Color(0xFF0842A0);
const kAccent = Color(0xFFD96570);
const kBorder = Color(0xFF444746);
const kTextPrimary = Color(0xFFE3E3E3);
const kTextSecondary = Color(0xFFC4C7C5);

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      bodyLarge: GoogleFonts.outfit(color: kTextPrimary),
      bodyMedium: GoogleFonts.outfit(color: kTextPrimary),
      bodySmall: GoogleFonts.outfit(color: kTextSecondary),
      titleLarge: GoogleFonts.outfit(color: kTextPrimary, fontWeight: FontWeight.bold),
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kPrimary,
      secondary: kAccent,
      surface: kSurface,
      onPrimary: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: kTextPrimary),
      titleTextStyle: TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder),
      ),
      margin: const EdgeInsets.only(bottom: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimary,
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      hintStyle: const TextStyle(color: kTextSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kBg,
      indicatorColor: kSurface,
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: kTextPrimary),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kPrimary);
        }
        return const IconThemeData(color: kTextSecondary);
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurface,
      selectedColor: kPrimary.withOpacity(0.2),
      labelStyle: const TextStyle(color: kTextPrimary),
      secondaryLabelStyle: const TextStyle(color: kPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder),
      ),
    ),
  );
}
