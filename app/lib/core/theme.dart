import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// TechPulse tasarım sistemi.
///
/// Varsayılan tema koyu: çok koyu lacivert zemin, antrasit-lacivert kartlar, elektrik moru marka rengi.
/// Mor yalnızca vurgularda (aktif sekme, seçili kategori, ana düğme, küçük ikonlar) kullanılır.
/// Açık tema aynı hiyerarşiyi korur.
@immutable
class TpColors extends ThemeExtension<TpColors> {
  const TpColors({
    required this.background,
    required this.card,
    required this.cardHigh,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primarySoft,
    required this.secondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.skeleton,
  });

  final Color background;
  final Color card;
  final Color cardHigh;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;

  /// Mor vurgunun saydam zemini (seçili çip, bilgi kutusu).
  final Color primarySoft;
  final Color secondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color skeleton;

  static const dark = TpColors(
    background: Color(0xFF0B0D17),
    card: Color(0xFF151827),
    cardHigh: Color(0xFF1D2233),
    border: Color(0xFF262B3D),
    textPrimary: Color(0xFFF4F5FA),
    textSecondary: Color(0xFFA5A9BA),
    textMuted: Color(0xFF74798D),
    primary: Color(0xFF7047F5),
    primarySoft: Color(0x297047F5),
    secondary: Color(0xFF3988FF),
    success: Color(0xFF34D399),
    warning: Color(0xFFFB923C),
    danger: Color(0xFFFF6B86),
    skeleton: Color(0xFF1D2233),
  );

  static const light = TpColors(
    background: Color(0xFFF4F5FA),
    card: Color(0xFFFFFFFF),
    cardHigh: Color(0xFFEDEFF6),
    border: Color(0xFFE1E4EE),
    textPrimary: Color(0xFF12142A),
    textSecondary: Color(0xFF4D5268),
    textMuted: Color(0xFF7C8197),
    primary: Color(0xFF6A3FF0),
    primarySoft: Color(0x1F6A3FF0),
    secondary: Color(0xFF2F7BF5),
    success: Color(0xFF15803D),
    warning: Color(0xFFC2410C),
    danger: Color(0xFFD12A4D),
    skeleton: Color(0xFFE6E9F2),
  );

  @override
  TpColors copyWith() => this;

  @override
  TpColors lerp(ThemeExtension<TpColors>? other, double t) {
    if (other is! TpColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return TpColors(
      background: l(background, other.background),
      card: l(card, other.card),
      cardHigh: l(cardHigh, other.cardHigh),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      primary: l(primary, other.primary),
      primarySoft: l(primarySoft, other.primarySoft),
      secondary: l(secondary, other.secondary),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      skeleton: l(skeleton, other.skeleton),
    );
  }
}

extension TpThemeX on BuildContext {
  TpColors get tp => Theme.of(this).extension<TpColors>() ?? TpColors.dark;
  TextTheme get text => Theme.of(this).textTheme;
  Brightness get brightness => Theme.of(this).brightness;
}

/// Ölçüler: 4'ün katları; kart köşeleri 16.
abstract final class Tp {
  static const double radius = 16;
  static const double radiusSmall = 12;
  static const double page = 20;
  static const String monoFont = 'JetBrainsMono';
}

abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark, TpColors.dark);
  static ThemeData light() => _build(Brightness.light, TpColors.light);

  static ThemeData _build(Brightness brightness, TpColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: Colors.white,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.textPrimary,
      secondary: c.secondary,
      onSecondary: Colors.white,
      secondaryContainer: c.cardHigh,
      onSecondaryContainer: c.textPrimary,
      tertiary: c.secondary,
      onTertiary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.background,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.card,
      surfaceContainer: c.card,
      surfaceContainerHigh: c.cardHigh,
      surfaceContainerHighest: c.cardHigh,
      outline: c.border,
      outlineVariant: c.border,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.background,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final base = ThemeData(colorScheme: scheme, fontFamily: 'Inter', useMaterial3: true, brightness: brightness);
    final t = base.textTheme;
    TextStyle? s(TextStyle? style, double size, FontWeight weight, {double? height, double spacing = 0, Color? color}) =>
        style?.copyWith(fontSize: size, fontWeight: weight, height: height, letterSpacing: spacing, color: color ?? c.textPrimary);

    final textTheme = t.copyWith(
      headlineMedium: s(t.headlineMedium, 26, FontWeight.w700, height: 1.2, spacing: -0.6),
      headlineSmall: s(t.headlineSmall, 22, FontWeight.w700, height: 1.25, spacing: -0.4),
      titleLarge: s(t.titleLarge, 19, FontWeight.w700, height: 1.3, spacing: -0.3),
      titleMedium: s(t.titleMedium, 16, FontWeight.w600, height: 1.35, spacing: -0.1),
      titleSmall: s(t.titleSmall, 14, FontWeight.w600, height: 1.35),
      bodyLarge: s(t.bodyLarge, 16, FontWeight.w400, height: 1.65, color: c.textPrimary),
      bodyMedium: s(t.bodyMedium, 14, FontWeight.w400, height: 1.5, color: c.textSecondary),
      bodySmall: s(t.bodySmall, 12.5, FontWeight.w400, height: 1.4, color: c.textMuted),
      labelLarge: s(t.labelLarge, 14, FontWeight.w600, color: c.textPrimary),
      labelMedium: s(t.labelMedium, 12.5, FontWeight.w600, color: c.textSecondary),
      labelSmall: s(t.labelSmall, 11, FontWeight.w600, spacing: 0.6, color: c.textMuted),
    );

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: textTheme,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primarySoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? c.primary : c.textMuted, size: 24),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? c.primary : c.textMuted,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tp.radius), side: BorderSide(color: c.border)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: c.primary,
        disabledColor: c.card,
        side: BorderSide(color: c.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textSecondary),
        secondaryLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        hintStyle: TextStyle(fontFamily: 'Inter', color: c.textMuted, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Tp.radiusSmall), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tp.radiusSmall), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tp.radiusSmall), borderSide: BorderSide(color: c.primary, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tp.radiusSmall)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: c.border),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tp.radiusSmall)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: c.border)),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primarySoft : c.card),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.textPrimary : c.textSecondary),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : c.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.cardHigh),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.border),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.textPrimary,
        unselectedLabelColor: c.textMuted,
        indicatorColor: c.primary,
        dividerColor: c.border,
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.label,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.cardHigh,
        contentTextStyle: TextStyle(fontFamily: 'Inter', color: c.textPrimary, fontSize: 14),
        actionTextColor: c.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tp.radiusSmall)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
