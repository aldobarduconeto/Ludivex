import 'package:flutter/material.dart';

abstract final class LudivexTheme {
  static const accent = Color(0xFF82E2A5);

  static ThemeData buildLight() => build(Brightness.light);
  static ThemeData buildDark() => build(Brightness.dark, oled: false);
  static ThemeData buildOled() => build(Brightness.dark, oled: true);

  static ThemeData build(Brightness brightness, {bool oled = false}) {
    final dark = brightness == Brightness.dark;
    final isOled = dark && oled;
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF20B969),
      brightness: brightness,
      primary: dark ? accent : const Color(0xFF176B43),
      secondary: dark ? const Color(0xFF8ABAF5) : const Color(0xFF285D9B),
      onSecondary: dark ? const Color(0xFF041626) : Colors.white,
      onPrimary: dark ? const Color(0xFF18220D) : Colors.white,
      surface: isOled
          ? const Color(0xFF000000)
          : (dark ? const Color(0xFF15191F) : Colors.white),
      onSurface: dark ? const Color(0xFFF0F2F5) : const Color(0xFF1C2634),
      onSurfaceVariant: dark
          ? const Color(0xFF9AA6B6)
          : const Color(0xFF647083),
      outlineVariant: isOled
          ? const Color(0xFF22262E)
          : (dark ? const Color(0xFF2A3039) : const Color(0xFFE5E8ED)),
      primaryContainer: dark
          ? (isOled ? const Color(0xFF0F2618) : const Color(0xFF173824))
          : const Color(0xFFD6F5DC),
      onPrimaryContainer: dark
          ? const Color(0xFFC4FFD0)
          : const Color(0xFF12351C),
      secondaryContainer: dark
          ? (isOled ? const Color(0xFF0D1E2A) : const Color(0xFF163044))
          : const Color(0xFFDCEFFF),
      onSecondaryContainer: dark
          ? const Color(0xFFC2E5FF)
          : const Color(0xFF10334C),
      surfaceContainerHighest: isOled
          ? const Color(0xFF111418)
          : (dark ? const Color(0xFF22272F) : const Color(0xFFEDF0F4)),
      surfaceContainerLow: isOled
          ? const Color(0xFF08090C)
          : (dark ? const Color(0xFF191E25) : const Color(0xFFF8FAFB)),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
    );
    return base.copyWith(
      splashFactory: InkRipple.splashFactory,
      hoverColor: colors.primary.withValues(alpha: .06),
      scaffoldBackgroundColor: isOled
          ? const Color(0xFF000000)
          : (dark ? const Color(0xFF0E1116) : const Color(0xFFF7F8FA)),
      textTheme: base.textTheme
          .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface)
          .copyWith(
            headlineLarge: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color: colors.onSurface,
            ),
            headlineMedium: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -.8,
              color: colors.onSurface,
            ),
            titleLarge: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -.4,
              color: colors.onSurface,
            ),
            bodyMedium: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              height: 1.5,
              color: colors.onSurface,
            ),
            bodySmall: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          )
          .apply(fontFamily: 'Roboto'),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      dividerColor: colors.outlineVariant.withValues(alpha: .55),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isOled ? const Color(0xFF000000) : Colors.transparent,
        foregroundColor: colors.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: isOled ? const Color(0xFF07090C) : colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isOled
                ? const Color(0xFF1E222A)
                : colors.outlineVariant.withValues(alpha: .45),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        helperMaxLines: 3,
        errorMaxLines: 3,
        filled: true,
        fillColor: isOled ? const Color(0xFF07090C) : colors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Roboto',
          color: colors.onSurfaceVariant,
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isOled ? const Color(0xFF22262E) : colors.outlineVariant,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: isOled
              ? const BorderSide(color: Color(0xFF1D222A))
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide.none,
        backgroundColor: isOled
            ? const Color(0xFF0E1115)
            : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedColor: colors.primary.withValues(alpha: .12),
        labelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: isOled ? const Color(0xFF000000) : colors.surface,
        elevation: 0,
        indicatorColor: colors.primary.withValues(alpha: .13),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          side: BorderSide(
            color: isOled ? const Color(0xFF22262E) : colors.outlineVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isOled
            ? const Color(0xFF0A0C0F)
            : colors.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isOled
                ? const Color(0xFF22262E)
                : colors.outlineVariant.withValues(alpha: .7),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isOled ? const Color(0xFF0E1115) : colors.surfaceContainerLow,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(color: colors.onInverseSurface, fontSize: 12),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isOled ? const Color(0xFF07090C) : colors.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
