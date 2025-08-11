import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // Suppression de toute la logique de thème dynamique
  // L'application utilisera toujours le thème clair

  Future<void> initialize() async {
    // Plus besoin d'initialisation
    notifyListeners();
  }

  // Thème unique - mode clair uniquement
  static ThemeData get lightTheme {
    // Palette inspirée logo (violet profond + accent doré)
    const primary = Color(0xFF6A35B5); // violet principal
    const primaryContainer = Color(0xFF8A55D6);
    const secondary = Color(0xFFF2B705); // doré
    const secondaryContainer = Color(0xFFFFD25A);
    const tertiary = Color(0xFF4C1E87); // violet foncé
    const error = Color(0xFFE53935);

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: Colors.white,
      secondary: secondary,
      onSecondary: Colors.black87,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: Colors.black87,
      tertiary: tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF6633AA),
      onTertiaryContainer: Colors.white,
      error: error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFE5E5),
      onErrorContainer: error,
      background: const Color(0xFFF7F5FB),
      onBackground: const Color(0xFF201A2A),
      surface: Colors.white,
      onSurface: const Color(0xFF2C2540),
      surfaceVariant: const Color(0xFFEADFF7),
      onSurfaceVariant: const Color(0xFF5E4E77),
      outline: const Color(0xFFB8A9D6),
      outlineVariant: const Color(0xFFD9CCE9),
      shadow: Colors.black.withValues(alpha: 0.25),
      scrim: Colors.black.withValues(alpha: 0.5),
      inverseSurface: const Color(0xFF362B4D),
      onInverseSurface: Colors.white,
      inversePrimary: const Color(0xFFE3D5FF),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
  cardTheme: CardThemeData(
        elevation: 3,
        margin: const EdgeInsets.all(8),
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
        fillColor: colorScheme.surfaceVariant.withValues(alpha: 0.35),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tertiary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tertiary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
        labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: secondary,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 32,
        thickness: 0.8,
      ),
      textTheme: Typography.blackCupertino.copyWith(
        headlineLarge: const TextStyle(fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}