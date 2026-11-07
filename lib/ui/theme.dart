import 'package:flutter/material.dart';

import '../brand.dart';

/// Build a Material 3 palette from the selected colour and palette style.
/// The old implementation always returned a fixed brown scheme, ignoring the
/// user's colour selection in Settings.
ColorScheme brewScheme(Color seed, Brightness brightness, DynamicSchemeVariant variant) {
  return ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: variant,
  );
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
    scaffoldBackgroundColor: scheme.surface,
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
      indicatorColor: scheme.secondaryContainer,
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
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: scheme.surfaceContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
