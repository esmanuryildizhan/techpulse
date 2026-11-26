import 'package:flutter/material.dart';

/// Haber konuları. Kimlikler veri hattındaki (pipeline/src/categories.ts) kimliklerle aynıdır.
/// Adlar kullanıcıya ne göreceğini açıkça söyleyecek biçimde seçildi ("Güvenlik" değil "Siber Güvenlik").
enum TechCategory {
  ai(
    key: 'ai',
    label: 'Yapay Zekâ',
    description: 'Modeller, araştırmalar ve yapay zekâ ürünleri',
    icon: Icons.auto_awesome_outlined,
    color: Color(0xFFAD99F2),
    lightColor: Color(0xFF6447C2),
  ),
  security(
    key: 'security',
    label: 'Siber Güvenlik',
    description: 'Güvenlik açıkları, saldırılar ve veri ihlalleri',
    icon: Icons.shield_outlined,
    color: Color(0xFFF08E98),
    lightColor: Color(0xFFBE3647),
  ),
  dev(
    key: 'dev',
    label: 'Yazılım Geliştirme',
    description: 'Programlama dilleri, araçlar ve açık kaynak',
    icon: Icons.code_rounded,
    color: Color(0xFF8EB2F0),
    lightColor: Color(0xFF2D60C2),
  ),
  data(
    key: 'data',
    label: 'Veri Bilimi',
    description: 'Analitik, veri mühendisliği ve istatistik',
    icon: Icons.insights_rounded,
    color: Color(0xFF72CDBB),
    lightColor: Color(0xFF167D6D),
  ),
  hardware(
    key: 'hardware',
    label: 'Donanım ve Çip Teknolojileri',
    shortLabel: 'Donanım ve Çip',
    description: 'İşlemciler, ekran kartları ve cihazlar',
    icon: Icons.memory_rounded,
    color: Color(0xFFE6B26C),
    lightColor: Color(0xFF9C5F0E),
  ),
  cloud(
    key: 'cloud',
    label: 'Bulut ve DevOps',
    description: 'Bulut platformları, altyapı ve dağıtım',
    icon: Icons.cloud_outlined,
    color: Color(0xFF80C1E0),
    lightColor: Color(0xFF1C7299),
  ),
  mobile(
    key: 'mobile',
    label: 'Mobil Teknolojiler',
    description: 'Android, iOS, telefonlar ve uygulamalar',
    icon: Icons.smartphone_rounded,
    color: Color(0xFF8BC992),
    lightColor: Color(0xFF2F7A3B),
  ),
  science(
    key: 'science',
    label: 'Uzay ve Bilim',
    description: 'Uzay araştırmaları, fizik ve bilimsel keşifler',
    icon: Icons.rocket_launch_outlined,
    color: Color(0xFFE897C2),
    lightColor: Color(0xFFA8396F),
  ),
  industry(
    key: 'industry',
    label: 'Teknoloji Dünyası',
    description: 'Şirketler, girişimler, yatırımlar ve politika',
    icon: Icons.public_rounded,
    color: Color(0xFFB2B6BF),
    lightColor: Color(0xFF5A606C),
  );

  const TechCategory({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.lightColor,
    String? shortLabel,
  }) : _shortLabel = shortLabel;

  final String key;
  final String label;
  final String description;
  final IconData icon;

  /// Koyu temadaki vurgu rengi.
  final Color color;

  /// Açık temada okunur kalan koyu ton.
  final Color lightColor;
  final String? _shortLabel;

  /// Kartlardaki küçük kategori etiketi için kısa ad.
  String get shortLabel => _shortLabel ?? label;

  Color tone(Brightness brightness) => brightness == Brightness.dark ? color : lightColor;

  static TechCategory fromKey(Object? key) {
    if (key == 'software') return TechCategory.dev; // önceki sürümün kimliği
    for (final category in values) {
      if (category.key == key) return category;
    }
    return TechCategory.industry;
  }

  static TechCategory? tryKey(String? key) {
    for (final category in values) {
      if (category.key == key) return category;
    }
    return null;
  }
}

/// Türkçeye uygun büyük harf: "Siber güvenlik" → "SİBER GÜVENLİK" (Dart'ın toUpperCase'i "I" üretir).
String trUpper(String text) => text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
