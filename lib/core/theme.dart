import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClayColors {
  static const background = Color(0xFFE6EEFB); // soft blue
  static const surface = Color(0xFFEFF4FD);
  static const primary = Color(0xFF6C8EF5);
  static const mint = Color(0xFF6FD6B8);
  static const peach = Color(0xFFFFA98F);
  static const lilac = Color(0xFFB59CF5);
  static const sun = Color(0xFFFFCF70);
  static const text = Color(0xFF2E3A59);
  static const textSoft = Color(0xFF7683A3);
  static const shadowDark = Color(0xFFB4C3E2);
  static const shadowLight = Color(0xFFFFFFFF);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ClayColors.primary,
      surface: ClayColors.surface,
    ),
    scaffoldBackgroundColor: ClayColors.background,
  );

  // Nunito: sans-serif membulat, dipakai dengan bobot tebal.
  final text = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
    bodyColor: ClayColors.text,
    displayColor: ClayColors.text,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: ClayColors.text,
      ),
      iconTheme: const IconThemeData(color: ClayColors.text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ClayColors.background,
      indicatorColor: ClayColors.primary.withAlpha(60),
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ClayColors.text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
