import 'package:flutter/material.dart';

abstract final class LudivexTheme {
  static const accent = Color(0xFFBCACFF);

  static ThemeData build(
    Brightness brightness, {
    bool oled = false,
    Color? accentColor,
  }) {
    final dark = brightness == Brightness.dark;
    final isOled = dark && oled;
    var colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7957DC),
      brightness: brightness,
      primary: dark ? accent : const Color(0xFF5733AD),
      secondary: dark ? const Color(0xFF9FD4F6) : const Color(0xFF245876),
      onSecondary: dark ? const Color(0xFF041626) : Colors.white,
      onPrimary: dark ? const Color(0xFF211743) : Colors.white,
      surface: isOled
          ? const Color(0xFF000000)
          : (dark ? const Color(0xFF17181C) : Colors.white),
      onSurface: dark ? const Color(0xFFF1F2F5) : const Color(0xFF191B20),
      onSurfaceVariant: dark
          ? const Color(0xFFAFB3BE)
          : const Color(0xFF565B67),
      outlineVariant: isOled
          ? const Color(0xFF22262E)
          : (dark ? const Color(0xFF343740) : const Color(0xFFDCE0E7)),
      primaryContainer: dark
          ? (isOled ? const Color(0xFF251B3A) : const Color(0xFF30264E))
          : const Color(0xFFEDE4FF),
      onPrimaryContainer: dark
          ? const Color(0xFFE9DEFF)
          : const Color(0xFF301F59),
      secondaryContainer: dark
          ? (isOled ? const Color(0xFF0D1E2A) : const Color(0xFF163044))
          : const Color(0xFFDCEFFF),
      onSecondaryContainer: dark
          ? const Color(0xFFC2E5FF)
          : const Color(0xFF10334C),
      surfaceContainerHighest: isOled
          ? const Color(0xFF111418)
          : (dark ? const Color(0xFF292C34) : const Color(0xFFEAEDF2)),
      surfaceContainerLow: isOled
          ? const Color(0xFF08090C)
          : (dark ? const Color(0xFF1C1F25) : const Color(0xFFF5F6F8)),
      surfaceContainer: isOled
          ? const Color(0xFF0C0B10)
          : (dark ? const Color(0xFF20232A) : const Color(0xFFF0F2F5)),
      surfaceContainerHigh: isOled
          ? const Color(0xFF100F15)
          : (dark ? const Color(0xFF252830) : const Color(0xFFEDEFF3)),
    );
    if (accentColor != null) {
      final palette = ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: brightness,
      );
      colors = colors.copyWith(
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        primaryContainer: palette.primaryContainer,
        onPrimaryContainer: palette.onPrimaryContainer,
        secondary: palette.secondary,
        onSecondary: palette.onSecondary,
        secondaryContainer: palette.secondaryContainer,
        onSecondaryContainer: palette.onSecondaryContainer,
      );
    }
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
          : (dark ? const Color(0xFF101115) : const Color(0xFFF7F8FA)),
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
          borderRadius: BorderRadius.circular(12),
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
        fillColor: isOled
            ? const Color(0xFF07090C)
            : colors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
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
        height: 64,
        backgroundColor: isOled ? const Color(0xFF000000) : colors.surface,
        elevation: 0,
        indicatorColor: colors.primaryContainer,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        elevation: 2,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
