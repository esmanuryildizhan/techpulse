import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// TechPulse tasarım sistemi.
///
/// Kimlik: "kâğıt ve mürekkep". Açık temada sıcak kâğıt beyazı zemin ve koyu mürekkep metin, koyu temada
/// lacivert değil sıcak kömür grisi. Tek bir vurgu rengi vardır ve kullanıcı Profil → Görünüm'den
/// değiştirebilir. Başlıklar ve haber metni serif (Source Serif 4), arayüz yazıları Inter'dir.

/// Kullanıcının seçebildiği vurgu renkleri.
enum AccentColor {
  orange('Turuncu', Color(0xFFCF4520), Color(0xFFFF8A66)),
  blue('Mavi', Color(0xFF2B66D1), Color(0xFF79A6FF)),
  green('Yeşil', Color(0xFF1B8556), Color(0xFF55C58C)),
  purple('Mor', Color(0xFF7246D2), Color(0xFFAE93FF)),
  pink('Pembe', Color(0xFFCC3368), Color(0xFFFF7FA9)),
  graphite('Grafit', Color(0xFF3A414D), Color(0xFFC7CDD8));

  const AccentColor(this.label, this.light, this.dark);

  final String label;
  final Color light;
  final Color dark;

  Color tone(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  static AccentColor fromName(String? name) => values.where((c) => c.name == name).firstOrNull ?? AccentColor.orange;
}

@immutable
class TpColors extends ThemeExtension<TpColors> {
  const TpColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.brand,
    required this.success,
    required this.warning,
    required this.danger,
    required this.skeleton,
  });

  factory TpColors.of(Brightness brightness, AccentColor accentColor) {
    final accent = accentColor.tone(brightness);
    // Düğme yazısı: beyaz yeterince okunuyorsa (WCAG 4.5:1) beyaz, değilse hangisi daha okunursa o.
    const ink = Color(0xFF16150F);
    final onAccent = _contrast(Colors.white, accent) >= 4.5 || _contrast(Colors.white, accent) >= _contrast(ink, accent)
        ? Colors.white
        : ink;
    if (brightness == Brightness.dark) {
      return TpColors(
        bg: const Color(0xFF141311),
        surface: const Color(0xFF1C1B18),
        surfaceAlt: const Color(0xFF262420),
        border: const Color(0xFF302D28),
        text: const Color(0xFFEEEBE4),
        textSecondary: const Color(0xFFB0ABA1),
        textTertiary: const Color(0xFF807B72),
        accent: accent,
        onAccent: onAccent,
        accentSoft: accent.withValues(alpha: 0.16),
        brand: accentColor.light,
        success: const Color(0xFF5CC48D),
        warning: const Color(0xFFE5A846),
        danger: const Color(0xFFFF7468),
        skeleton: const Color(0xFF26241F),
      );
    }
    return TpColors(
      bg: const Color(0xFFF6F4EF),
      surface: Colors.white,
      surfaceAlt: const Color(0xFFEEEBE4),
      border: const Color(0xFFE3DFD6),
      text: const Color(0xFF1B1A16),
      textSecondary: const Color(0xFF5D5A52),
      textTertiary: const Color(0xFF8B877D),
      accent: accent,
      onAccent: onAccent,
      accentSoft: accent.withValues(alpha: 0.10),
      brand: accentColor.light,
      success: const Color(0xFF237A4B),
      warning: const Color(0xFFB0670A),
      danger: const Color(0xFFC2352B),
      skeleton: const Color(0xFFE9E6DF),
    );
  }

  /// Sayfa zemini.
  final Color bg;

  /// Kartlar ve alt çubuk.
  final Color surface;

  /// Arama kutusu, çipler, kutucuklar.
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;

  /// Logonun zemini: iki temada da aynı (uygulama simgesiyle birebir), beyaz balonla okunur.
  final Color brand;
  final Color success;
  final Color warning;
  final Color danger;
  final Color skeleton;

  @override
  TpColors copyWith() => this;

  @override
  TpColors lerp(covariant TpColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return TpColors(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      border: c(border, other.border),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentSoft: c(accentSoft, other.accentSoft),
      brand: c(brand, other.brand),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      skeleton: c(skeleton, other.skeleton),
    );
  }
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

extension ThemeX on BuildContext {
  TpColors get tp => Theme.of(this).extension<TpColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  Brightness get brightness => Theme.of(this).brightness;
}

/// Ölçüler ve yazı stilleri.
abstract final class Tp {
  static const double radius = 14;
  static const double radiusSmall = 10;

  /// Sayfa kenar boşluğu.
  static const double page = 20;

  /// Bölümler arası dikey boşluk.
  static const double section = 32;

  static const String sans = 'Inter';
  static const String serif = 'SourceSerif4';
  static const String monoFont = 'JetBrainsMono';

  /// Haber metni (serif). [scale]: kullanıcının yazı boyutu tercihi.
  static TextStyle article(BuildContext context, double scale) =>
      TextStyle(fontFamily: serif, fontSize: 17.5 * scale, height: 1.62, color: context.tp.text, letterSpacing: 0.05);

  /// Haber başlıkları (serif).
  static TextStyle headline(
    BuildContext context, {
    double size = 19,
    FontWeight weight = FontWeight.w600,
    double height = 1.28,
  }) => TextStyle(
    fontFamily: serif,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: context.tp.text,
    letterSpacing: -0.1,
  );
}

abstract final class AppTheme {
  static ThemeData light(AccentColor accent) => _build(Brightness.light, accent);
  static ThemeData dark(AccentColor accent) => _build(Brightness.dark, accent);

  static ThemeData _build(Brightness brightness, AccentColor accentColor) {
    final tp = TpColors.of(brightness, accentColor);
    final scheme = ColorScheme.fromSeed(seedColor: tp.accent, brightness: brightness).copyWith(
      primary: tp.accent,
      onPrimary: tp.onAccent,
      secondary: tp.accent,
      onSecondary: tp.onAccent,
      error: tp.danger,
      surface: tp.surface,
      onSurface: tp.text,
      onSurfaceVariant: tp.textSecondary,
      surfaceContainerHighest: tp.surfaceAlt,
      surfaceContainerHigh: tp.surfaceAlt,
      surfaceContainer: tp.surface,
      surfaceContainerLow: tp.surface,
      outline: tp.border,
      outlineVariant: tp.border,
    );

    TextStyle sans(double size, FontWeight weight, {double height = 1.4, Color? color, double spacing = 0}) =>
        TextStyle(
          fontFamily: Tp.sans,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color ?? tp.text,
          letterSpacing: spacing,
        );
    TextStyle serif(double size, FontWeight weight, {double height = 1.25}) => TextStyle(
      fontFamily: Tp.serif,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: tp.text,
      letterSpacing: -0.2,
    );

    final textTheme = TextTheme(
      displaySmall: serif(30, FontWeight.w700, height: 1.15),
      headlineMedium: serif(27, FontWeight.w700, height: 1.18),
      headlineSmall: serif(23, FontWeight.w700, height: 1.22),
      titleLarge: serif(20, FontWeight.w600),
      titleMedium: serif(17, FontWeight.w600, height: 1.3),
      titleSmall: sans(15, FontWeight.w600, height: 1.35),
      bodyLarge: sans(16, FontWeight.w400, height: 1.5),
      bodyMedium: sans(14.5, FontWeight.w400, height: 1.5, color: tp.textSecondary),
      bodySmall: sans(13, FontWeight.w400, height: 1.45, color: tp.textSecondary),
      labelLarge: sans(14.5, FontWeight.w600, height: 1.2),
      labelMedium: sans(12.5, FontWeight.w600, height: 1.2, color: tp.textSecondary),
      labelSmall: sans(11.5, FontWeight.w500, height: 1.2, color: tp.textTertiary, spacing: 0.1),
    );

    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tp.radiusSmall));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: Tp.sans,
      textTheme: textTheme,
      scaffoldBackgroundColor: tp.bg,
      canvasColor: tp.bg,
      extensions: [tp],
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(color: tp.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: tp.bg,
        foregroundColor: tp.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: sans(17, FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tp.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: tp.accentSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) =>
              IconThemeData(size: 23, color: states.contains(WidgetState.selected) ? tp.accent : tp.textTertiary),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => sans(
            11.5,
            states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? tp.text : tp.textTertiary,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: tp.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tp.radius),
          side: BorderSide(color: tp.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tp.surfaceAlt,
        hintStyle: sans(15, FontWeight.w400, color: tp.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Tp.radiusSmall), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tp.radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tp.radiusSmall),
          borderSide: BorderSide(color: tp.accent, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tp.surfaceAlt,
        selectedColor: tp.accent,
        disabledColor: tp.surfaceAlt,
        side: BorderSide.none,
        shape: StadiumBorder(side: BorderSide(color: tp.border.withValues(alpha: 0))),
        labelStyle: sans(13.5, FontWeight.w500, color: tp.text),
        secondaryLabelStyle: sans(13.5, FontWeight.w600, color: tp.onAccent),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
        checkmarkColor: tp.onAccent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tp.accent,
          foregroundColor: tp.onAccent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: rounded,
          textStyle: sans(15, FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tp.text,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: tp.border),
          shape: rounded,
          textStyle: sans(15, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: tp.accent, textStyle: sans(14, FontWeight.w600), shape: rounded),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: tp.text)),
      // Seçili parça vurgu rengiyle dolar; seçili olmayanlar boş kalır. (Önceki tasarımda seçili olmayan
      // parça gri boyanıyordu ve seçili sanılıyordu.)
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? tp.accent : tp.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? tp.onAccent : tp.textSecondary,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? tp.onAccent : tp.textSecondary,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: tp.border)),
          textStyle: WidgetStatePropertyAll(sans(13.5, FontWeight.w600)),
          visualDensity: VisualDensity.compact,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tp.onAccent : tp.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tp.accent : tp.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tp.accent : tp.border,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tp.accent : tp.textTertiary,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tp.accent : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(tp.onAccent),
        side: BorderSide(color: tp.textTertiary, width: 1.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: tp.accent, linearTrackColor: Colors.transparent),
      listTileTheme: ListTileThemeData(
        iconColor: tp.textSecondary,
        textColor: tp.text,
        titleTextStyle: sans(15.5, FontWeight.w500),
        subtitleTextStyle: sans(13, FontWeight.w400, color: tp.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tp.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: tp.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tp.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: sans(18, FontWeight.w700),
        contentTextStyle: sans(15, FontWeight.w400, color: tp.textSecondary, height: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark ? const Color(0xFFEEEBE4) : const Color(0xFF23211D),
        contentTextStyle: sans(
          14,
          FontWeight.w500,
          color: brightness == Brightness.dark ? const Color(0xFF1B1A16) : Colors.white,
        ),
        actionTextColor: brightness == Brightness.dark ? accentColor.light : accentColor.dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: tp.text, borderRadius: BorderRadius.circular(8)),
        textStyle: sans(12.5, FontWeight.w500, color: tp.bg),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tp.text,
        unselectedLabelColor: tp.textTertiary,
        labelStyle: sans(14.5, FontWeight.w600),
        unselectedLabelStyle: sans(14.5, FontWeight.w500),
        indicatorColor: tp.accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: tp.border,
        overlayColor: WidgetStatePropertyAll(tp.accentSoft),
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
