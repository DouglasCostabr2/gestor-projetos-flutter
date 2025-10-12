import 'package:flutter/material.dart';
import 'transitions.dart';

class AppTheme {
  static const Color seed = Color(0xFF3F51B5);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    return _baseTheme(scheme);
  }

  static ThemeData dark() {
    // Dark palette - EXACT colors from side menu for consistency across entire app
    const accent = Color(0xFF7AB6FF); // subtle blue for accents/buttons
    final base = ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark);
    final scheme = base.copyWith(
      // Main background - same as side menu card
      surface: const Color(0xFF151515),
      // Container surfaces - all using side menu card color for consistency
      surfaceContainerLowest: const Color(0xFF151515),
      surfaceContainerLow: const Color(0xFF151515),
      surfaceContainer: const Color(0xFF151515),
      surfaceContainerHigh: const Color(0xFF151515),
      surfaceContainerHighest: const Color(0xFF151515),
      // Text colors - exact match with side menu
      onSurface: const Color(0xFFEAEAEA),
      onSurfaceVariant: const Color(0xFF9AA0A6),
      // Dividers and outlines - exact match with side menu
      outline: const Color(0xFF2A2A2A),
      outlineVariant: const Color(0xFF2A2A2A),
      // Errors - exact match with side menu
      error: const Color(0xFFFF4D4D),
      onError: const Color(0xFF000000),
      errorContainer: const Color(0xFF5C1F1F),
      onErrorContainer: const Color(0xFFFF4D4D),
      // Primary accent color
      primary: accent,
      onPrimary: const Color(0xFF000000),
      // Success colors (using tertiary for success states)
      tertiary: const Color(0xFF4CAF50),
      onTertiary: const Color(0xFF000000),
      tertiaryContainer: const Color(0xFF1B3A1D),
      onTertiaryContainer: const Color(0xFF4CAF50),
    );
    return _baseTheme(scheme);
  }

  static ThemeData _baseTheme(ColorScheme scheme) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Transitions (disable page animations like before)
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.windows: NoAnimationPageTransitionsBuilder(),
        TargetPlatform.linux: NoAnimationPageTransitionsBuilder(),
        TargetPlatform.macOS: NoAnimationPageTransitionsBuilder(),
        TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
        TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
        TargetPlatform.fuchsia: NoAnimationPageTransitionsBuilder(),
      }),

      // Backgrounds
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: scheme.outlineVariant,

      // App bars
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        surfaceTintColor: scheme.surfaceTint,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: scheme.surfaceTint,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Buttons - matching side menu style (neutral gray, not blue)
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.12);
            }
            // Neutral gray background like side menu items
            return scheme.surfaceContainerHighest;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            // White text on gray button
            return scheme.onSurface;
          }),
          overlayColor: WidgetStateProperty.all(scheme.onSurface.withValues(alpha: 0.08)),
          elevation: WidgetStateProperty.all(0),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          minimumSize: WidgetStateProperty.all(const Size(0, 48)), // Altura mínima consistente
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.resolveWith((states) {
            final color = states.contains(WidgetState.disabled)
                ? scheme.outline.withValues(alpha: 0.5)
                : scheme.outline;
            return BorderSide(color: color);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.onSurface;
          }),
          overlayColor: WidgetStateProperty.all(scheme.onSurface.withValues(alpha: 0.08)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          minimumSize: WidgetStateProperty.all(const Size(0, 48)), // Altura mínima consistente
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.onSurface;
          }),
          overlayColor: WidgetStateProperty.all(scheme.onSurface.withValues(alpha: 0.08)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          minimumSize: WidgetStateProperty.all(const Size(0, 48)), // Altura mínima consistente
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.12);
            }
            // Neutral gray background like side menu items
            return scheme.surfaceContainerHighest;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            // White text on gray button
            return scheme.onSurface;
          }),
          overlayColor: WidgetStateProperty.all(scheme.onSurface.withValues(alpha: 0.08)),
          elevation: WidgetStateProperty.all(0),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          minimumSize: WidgetStateProperty.all(const Size(0, 48)), // Altura mínima consistente
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: scheme.error, width: 2)),
      ),

      // Dropdown menus
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          maximumSize: WidgetStateProperty.all(const Size(double.infinity, 300)),
          backgroundColor: WidgetStateProperty.all(scheme.surfaceContainerHighest),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: scheme.onSurfaceVariant),
          hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: scheme.primary, width: 2)),
          errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: scheme.error)),
          focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: scheme.error, width: 2)),
        ),
      ),

      // PopupMenu (usado por DropdownButtonFormField)
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // MenuBar/MenuAnchor (usado internamente por DropdownMenu e DropdownButtonFormField)
      menuTheme: MenuThemeData(
        style: MenuStyle(
          maximumSize: WidgetStateProperty.all(const Size(double.infinity, 300)),
          backgroundColor: WidgetStateProperty.all(scheme.surfaceContainerHighest),
        ),
      ),

      // Lists / navigation
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        selectedColor: scheme.primary,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
      ),
    );
  }
}

