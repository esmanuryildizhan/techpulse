import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techpulse/app.dart';
import 'package:techpulse/core/config.dart';
import 'package:techpulse/core/formatting.dart';
import 'package:techpulse/data/data_source.dart';
import 'package:techpulse/data/local_store.dart';
import 'package:techpulse/state/providers.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

Map<String, String> allFixtures() => {
  for (final name in ['news', 'models', 'papers', 'repos', 'security', 'meta']) '$name.json': fixture('$name.json'),
};

/// Sahte veri kaynağı: ağ yerine test/fixtures klasöründeki dosyaları döndürür.
class FakeSource implements DataSource {
  FakeSource(this.files, {this.offline = false});

  final Map<String, String> files;
  bool offline;
  int calls = 0;

  @override
  Future<String> getText(String path) async {
    calls++;
    if (offline) throw const AppException('İnternet bağlantısı kurulamadı.', kind: ErrorKind.offline);
    final body = files[path];
    if (body == null) throw const AppException('Veri henüz yayınlanmamış (404).', kind: ErrorKind.notFound);
    return body;
  }
}

Future<void> initTestLocale() async {
  Intl.defaultLocale = 'tr';
  await initializeDateFormatting('tr');
}

/// Test verisinin üretildiği ana yakın sabit bir "şimdi": sıralama ve yenilikler her çalıştırmada aynı olsun.
final testNow = DateTime.utc(2026, 11, 26, 7);

/// Uygulamayı sahte veriyle kurar. Varsayılan olarak ilk açılış ekranı geçilmiş sayılır.
Future<Widget> buildTestApp({
  FakeSource? source,
  LocalStore? store,
  Widget? home,
  Map<String, Object> prefs = const {},
  bool onboarded = true,
}) async {
  // Testlerde ağdan görsel indirilmez; konuya özel kapaklar çizilir.
  AppConfig.networkImages = false;
  Fmt.now = () => testNow;
  SharedPreferences.setMockInitialValues({if (onboarded) 'profile.onboarded': true, ...prefs});
  final preferences = await SharedPreferences.getInstance();
  return ProviderScope(
    // Testlerde otomatik yeniden deneme kapalı: hata hemen görünsün, bekleyen zamanlayıcı kalmasın.
    retry: (retryCount, error) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      localStoreProvider.overrideWithValue(store ?? MemoryStore()),
      dataSourceProvider.overrideWithValue(source ?? FakeSource(allFixtures())),
      clockProvider.overrideWithValue(() => testNow),
    ],
    child: TechPulseApp(home: home),
  );
}

/// Test ekranını gerçek bir telefon boyutuna getirir (411 x 914 mantıksal piksel).
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

/// Zamanlayıcılar ve asenkron işler tamamlansın diye birkaç kare ilerletir.
/// (Yükleniyor animasyonu sürekli döndüğü için pumpAndSettle kullanılmaz.)
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Uygulamayla gelen yazı tiplerini (Inter, Source Serif 4, JetBrains Mono, Material ikonları) test ortamına yükler;
/// yoksa ekran görüntülerinde yazılar kutucuk olarak çizilir.
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest) {
    final family = entry as Map<String, dynamic>;
    final loader = FontLoader(family['family'] as String);
    for (final font in family['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load((font as Map<String, dynamic>)['asset'] as String));
    }
    await loader.load();
  }
}
