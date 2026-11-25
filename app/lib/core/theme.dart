import 'package:flutter/material.dart';

import '../data/models.dart';

/// Material 3 teması. Bütün renkler tek bir tohum renkten (indigo) türetilir;
/// koyu tema aynı tohumdan otomatik üretilir. Yazı tipi: Inter (uygulamayla birlikte gelir).
abstract final class AppTheme {
  static const Color seed = Color(0xFF4F46E5);
  static const String monoFont = 'JetBrainsMono';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final base = ThemeData(colorScheme: scheme, fontFamily: 'Inter', useMaterial3: true);
    final text = base.textTheme;
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.25),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.3),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.55),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: const WidgetStatePropertyAll<TextStyle?>(
          TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6), space: 1, thickness: 1),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      visualDensity: VisualDensity.standard,
    );
  }
}

/// Her haber konusunun rengi; açık ve koyu temada okunur kalacak tonlar seçildi.
Color categoryColor(NewsCategory category, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (category) {
    NewsCategory.all => dark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
    NewsCategory.ai => dark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
    NewsCategory.software => dark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
    NewsCategory.hardware => dark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
    NewsCategory.security => dark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
    NewsCategory.industry => dark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
  };
}

Color modalityColor(Modality modality, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (modality) {
    Modality.text => dark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
    Modality.vision => dark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
    Modality.audio => dark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
    Modality.multimodal => dark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
    Modality.other => dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
  };
}

/// Kaynak rozetleri için kimliğe göre sabit bir renk seçer.
Color sourceColor(String sourceId, Brightness brightness) {
  const light = [
    Color(0xFF4F46E5),
    Color(0xFF0E7490),
    Color(0xFFB45309),
    Color(0xFF7C3AED),
    Color(0xFF15803D),
    Color(0xFFBE123C),
    Color(0xFF1D4ED8),
    Color(0xFF9333EA),
  ];
  const dark = [
    Color(0xFFA5B4FC),
    Color(0xFF67E8F9),
    Color(0xFFFCD34D),
    Color(0xFFC4B5FD),
    Color(0xFF86EFAC),
    Color(0xFFFDA4AF),
    Color(0xFF93C5FD),
    Color(0xFFD8B4FE),
  ];
  var hash = 0;
  for (final unit in sourceId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final palette = brightness == Brightness.dark ? dark : light;
  return palette[hash % palette.length];
}
