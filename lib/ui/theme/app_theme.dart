import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF00A884);
  static const darkBackground = Color(0xFF070A0F);
  static const darkSurface = Color(0xFF111827);
  static const darkSurfaceAlt = Color(0xFF182233);
  static const textMuted = Color(0xFF6B7280);

  static ThemeData light() {
    final theme =
        FlexThemeData.light(
          scheme: FlexScheme.tealM3,
          useMaterial3: true,
          surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
          blendLevel: 6,
          appBarStyle: FlexAppBarStyle.scaffoldBackground,
          subThemesData: const FlexSubThemesData(
            interactionEffects: true,
            tintedDisabledControls: true,
            blendOnLevel: 8,
            blendOnColors: false,
            useM2StyleDividerInM3: true,
            inputDecoratorRadius: 16,
            cardRadius: 12,
            navigationBarIndicatorRadius: 16,
            alignedDropdown: true,
          ),
          keyColors: const FlexKeyColors(useSecondary: true, useTertiary: true),
          visualDensity: FlexColorScheme.comfortablePlatformDensity,
        ).copyWith(
          scaffoldBackgroundColor: const Color(0xFFF7F9FA),
          appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        );
    return _readable(theme);
  }

  static ThemeData dark() {
    final theme = FlexThemeData.dark(
      scheme: FlexScheme.tealM3,
      useMaterial3: true,
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 14,
      appBarStyle: FlexAppBarStyle.scaffoldBackground,
      subThemesData: const FlexSubThemesData(
        interactionEffects: true,
        tintedDisabledControls: true,
        blendOnLevel: 18,
        inputDecoratorRadius: 16,
        cardRadius: 12,
        navigationBarIndicatorRadius: 16,
        alignedDropdown: true,
      ),
      keyColors: const FlexKeyColors(useSecondary: true, useTertiary: true),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
    ).copyWith(scaffoldBackgroundColor: darkBackground);
    return _readable(theme);
  }

  static ThemeData _readable(ThemeData theme) {
    final text = theme.textTheme;
    const buttonStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(48, 48)),
      textStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return theme.copyWith(
      textTheme: text.copyWith(
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 18),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 16),
        bodySmall: text.bodySmall?.copyWith(fontSize: 14),
        titleLarge: text.titleLarge?.copyWith(fontSize: 22),
        titleMedium: text.titleMedium?.copyWith(fontSize: 20),
        titleSmall: text.titleSmall?.copyWith(fontSize: 18),
        labelLarge: text.labelLarge?.copyWith(fontSize: 16),
        labelMedium: text.labelMedium?.copyWith(fontSize: 14),
        labelSmall: text.labelSmall?.copyWith(fontSize: 14),
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: (theme.filledButtonTheme.style ?? const ButtonStyle()).merge(
          buttonStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (theme.outlinedButtonTheme.style ?? const ButtonStyle()).merge(
          buttonStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: (theme.textButtonTheme.style ?? const ButtonStyle()).merge(
          buttonStyle,
        ),
      ),
    );
  }
}
