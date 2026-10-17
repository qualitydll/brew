import 'package:flutter/material.dart';

import '../brand.dart';

/// FClash-style dark theme with brown/orange color scheme
ColorScheme fclashScheme() {
  return ColorScheme(
    brightness: Brightness.dark,
    primary: kFClashAccentBright,
    onPrimary: Colors.white,
    primaryContainer: kFClashAccent.withValues(alpha: 0.3),
    onPrimaryContainer: Colors.white,
    secondary: kFClashAccentLight,
    onSecondary: Colors.white,
    secondaryContainer: kFClashAccent.withValues(alpha: 0.2),
    onSecondaryContainer: Colors.white,
    tertiary: kFClashAccent,
    onTertiary: Colors.white,
    tertiaryContainer: kFClashAccent.withValues(alpha: 0.4),
    onTertiaryContainer: Colors.white,
    error: Color(0xFFCF6679),
    onError: Colors.black,
    errorContainer: Color(0xFFB1384C),
    onErrorContainer: Colors.white,
    background: kFClashBackground,
    onBackground: Color(0xFFE0D5CF),
    surface: kFClashSurface,
    onSurface: Color(0xFFE0D5CF),
    surfaceVariant: kFClashCardBackground,
    onSurfaceVariant: Color(0xFFB5A6A0),
    outline: Color(0xFF6F5B4D).withValues(alpha: 0.5),
    outlineVariant: Color(0xFF36302C),
    inverseSurface: Color(0xFFE0D5CF),
    onInverseSurface: Color(0xFF36302C),
    inversePrimary: kFClashAccent,
    shadow: Colors.black,
    scrim: Colors.black.withValues(alpha: 0.8),
  );
}

/// Material You scheme; the default brew orange gets a coffee-brown tertiary.
ColorScheme brewScheme(Color seed, Brightness b, DynamicSchemeVariant v) {
  // Always use FClash dark theme for consistent styling
  return fclashScheme();
}

ThemeData buildTheme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final t = base.textTheme.apply(
    fontFamily: kBrandFont,
    fontFamilyFallback: kBrandFallback,
  );
  TextStyle? head(TextStyle? s) =>
      s?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5);
  return base.copyWith(
    scaffoldBackgroundColor: kFClashBackground,
    textTheme: t.copyWith(
      displayLarge: head(t.displayLarge),
      displayMedium: head(t.displayMedium),
      displaySmall: head(t.displaySmall),
      headlineLarge: head(t.headlineLarge),
      headlineMedium: head(t.headlineMedium),
      headlineSmall: head(t.headlineSmall),
      titleLarge: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: kFClashAccent.withValues(alpha: 0.4),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      labelType: NavigationRailLabelType.all,
      selectedLabelTextStyle: TextStyle(
        fontFamily: kBrandFont,
        fontFamilyFallback: kBrandFallback,
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: kBrandFont,
        fontFamilyFallback: kBrandFallback,
        color: scheme.onSurfaceVariant,
        fontSize: 12,
      ),
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kFClashSurface.withValues(alpha: 0.95),
      indicatorColor: kFClashAccent.withValues(alpha: 0.4),
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: kFClashCardBackground,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: kFClashCardBackground,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kFClashSurface.withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    cardTheme: CardThemeData(
      color: kFClashCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

const seedPalette = <Color>[
  kBrewOrange,
  kBrewCoffee,
  kBrewCaramel,
  Color(0xFFB3261E),
  Color(0xFF984061),
  Color(0xFF6750A4),
  Color(0xFF0061A4),
  Color(0xFF006A6A),
  Color(0xFF386A20),
];

const variantNames = {
  DynamicSchemeVariant.tonalSpot: 'Спокойная',
  DynamicSchemeVariant.expressive: 'Выразительная',
  DynamicSchemeVariant.vibrant: 'Яркая',
  DynamicSchemeVariant.fidelity: 'Точная',
  DynamicSchemeVariant.rainbow: 'Радуга',
  DynamicSchemeVariant.fruitSalad: 'Фруктовая',
  DynamicSchemeVariant.content: 'Контент',
  DynamicSchemeVariant.monochrome: 'Монохром',
  DynamicSchemeVariant.neutral: 'Нейтральная',
};
