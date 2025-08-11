import 'package:flutter/material.dart';

@immutable
class AppGradients extends ThemeExtension<AppGradients> {
  final Gradient primaryGradient;
  final Gradient elevatedGradient;

  const AppGradients({
    required this.primaryGradient,
    required this.elevatedGradient,
  });

  @override
  AppGradients copyWith({Gradient? primaryGradient, Gradient? elevatedGradient}) => AppGradients(
        primaryGradient: primaryGradient ?? this.primaryGradient,
        elevatedGradient: elevatedGradient ?? this.elevatedGradient,
      );

  @override
  AppGradients lerp(ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) return this;
    return AppGradients(
      primaryGradient: LinearGradient(
        colors: List.generate(2, (i) => Color.lerp(
              (primaryGradient as LinearGradient).colors[i],
              (other.primaryGradient as LinearGradient).colors[i],
              t,
            )!),
      ),
      elevatedGradient: LinearGradient(
        colors: List.generate(2, (i) => Color.lerp(
              (elevatedGradient as LinearGradient).colors[i],
              (other.elevatedGradient as LinearGradient).colors[i],
              t,
            )!),
      ),
    );
  }
}

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

  // Génération de nuances dérivées du logo :
  // Couleurs bases estimées depuis l'image: Violet #6A35B5, Violet profond #4C1E87, Doré #F2B705
  // Nuances supplémentaires calculées manuellement pour cohérence UI.
  static ThemeData get lightTheme {
    // Palette bleu / noir / blanc :
    // Base: Profond #0D47A1, Medium #1565C0, Accent clair #42A5F5, Background très clair #F5F8FC
    const primary = Color(0xFF0D47A1);          // Bleu profond
    const primaryLight = Color(0xFF1565C0);     // Bleu moyen
    const primaryUltraLight = Color(0xFFF5F8FC); // Fond très clair
    const primaryDeep = Color(0xFF082D63);      // Bleu encore plus sombre
    const accentBlue = Color(0xFF42A5F5);       // Accent clair
    const accentBlueSoft = Color(0xFFB3DAFF);   // Conteneur clair
    const error = Color(0xFFD32F2F);            // Rouge standard Material

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryLight,
      onPrimaryContainer: Colors.white,
      secondary: accentBlue,
      onSecondary: Colors.white,
      secondaryContainer: accentBlueSoft,
      onSecondaryContainer: const Color(0xFF06213D),
      tertiary: primaryDeep,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF6633AA),
      onTertiaryContainer: Colors.white,
      error: error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFE5E5),
      onErrorContainer: error,
      background: primaryUltraLight,
      onBackground: const Color(0xFF201A2A),
      surface: Colors.white,
      onSurface: const Color(0xFF2C2540),
      surfaceVariant: const Color(0xFFE3EEF9),
      onSurfaceVariant: const Color(0xFF385270),
      outline: const Color(0xFF98B3CC),
      outlineVariant: const Color(0xFFC9D9E6),
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
      backgroundColor: primaryDeep,
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
        backgroundColor: primaryDeep,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.55),
        labelStyle: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedColor: colorScheme.secondary,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentBlue,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 32,
        thickness: 0.8,
      ),
      extensions: const [
        AppGradients(
          primaryGradient: LinearGradient(
            colors: [Color(0xFF082D63), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          elevatedGradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
      textTheme: Typography.blackCupertino.copyWith(
        headlineLarge: const TextStyle(fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  static ThemeData get darkTheme {
    // Palette sombre bleue / anthracite
    const primary = Color(0xFF82B1FF);        // Bleu clair lisible
    const primaryDeep = Color(0xFF0A2B55);    // Bleu nuit
    const accent = Color(0xFF1565C0);         // Accent actif
    const accentContainer = Color(0xFF0D47A1);
    const surface = Color(0xFF121821);        // Anthracite bleuté
    const surfaceVariant = Color(0xFF1F2933);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.black,
      primaryContainer: primaryDeep,
      onPrimaryContainer: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: accentContainer,
      onSecondaryContainer: Colors.white,
      tertiary: primaryDeep,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF103A70),
      onTertiaryContainer: Colors.white,
      error: const Color(0xFFFF7474),
      onError: Colors.black,
      errorContainer: const Color(0xFF3B0D0D),
      onErrorContainer: const Color(0xFFFFB3B3),
      background: const Color(0xFF0D1218),
      onBackground: Colors.white,
      surface: surface,
      onSurface: Colors.white,
      surfaceVariant: surfaceVariant,
      onSurfaceVariant: const Color(0xFFC7B6E2),
      outline: const Color(0xFF3E5367),
      outlineVariant: const Color(0xFF2C3C4B),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFE3EEF9),
      onInverseSurface: const Color(0xFF142536),
      inversePrimary: const Color(0xFF1565C0),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: colorScheme.surfaceVariant.withValues(alpha: 0.5),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.tertiary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      extensions: const [
        AppGradients(
          primaryGradient: LinearGradient(
            colors: [Color(0xFF0A2B55), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          elevatedGradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );
  }
}