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
    const primary = Color(0xFF6A35B5);          // Violet principal
    const primaryLight = Color(0xFF8F5FDD);     // Éclairci
    const primaryUltraLight = Color(0xFFE8D9FA); // Très clair pour backgrounds
    const primaryDeep = Color(0xFF4C1E87);      // Profond
    const accentGold = Color(0xFFF2B705);       // Doré accent
    const accentGoldLight = Color(0xFFFFD866);  // Doré clair container
    const error = Color(0xFFD93030);            // Rouge révisé

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryLight,
      onPrimaryContainer: Colors.white,
      secondary: accentGold,
      onSecondary: Colors.black87,
      secondaryContainer: accentGoldLight,
      onSecondaryContainer: Colors.black87,
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
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.25),
        labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentGold,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 32,
        thickness: 0.8,
      ),
      extensions: const [
        AppGradients(
          primaryGradient: LinearGradient(
            colors: [primaryDeep, primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
            elevatedGradient: LinearGradient(
            colors: [primaryLight, primaryDeep],
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
    const primary = Color(0xFFBFA3FF);
    const primaryDeep = Color(0xFF2E0F55);
    const accentGold = Color(0xFFFFD770);
    const accentGoldDeep = Color(0xFF8A6400);
    const surface = Color(0xFF1E1A26);
    const surfaceVariant = Color(0xFF322A40);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.black,
      primaryContainer: primaryDeep,
      onPrimaryContainer: Colors.white,
      secondary: accentGold,
      onSecondary: Colors.black,
      secondaryContainer: accentGoldDeep,
      onSecondaryContainer: Colors.white,
      tertiary: primaryDeep,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF43236F),
      onTertiaryContainer: Colors.white,
      error: const Color(0xFFFF7474),
      onError: Colors.black,
      errorContainer: const Color(0xFF3B0D0D),
      onErrorContainer: const Color(0xFFFFB3B3),
      background: const Color(0xFF16121D),
      onBackground: Colors.white,
      surface: surface,
      onSurface: Colors.white,
      surfaceVariant: surfaceVariant,
      onSurfaceVariant: const Color(0xFFC7B6E2),
      outline: const Color(0xFF6D5A89),
      outlineVariant: const Color(0xFF4C3E5F),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFE9DEF7),
      onInverseSurface: const Color(0xFF271F33),
      inversePrimary: const Color(0xFF6A35B5),
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
      extensions: [
        const AppGradients(
          primaryGradient: LinearGradient(
            colors: [primaryDeep, primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          elevatedGradient: LinearGradient(
            colors: [primaryDeep, Color(0xFF43236F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );
  }
}