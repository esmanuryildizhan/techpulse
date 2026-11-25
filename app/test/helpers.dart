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
    if (offline) throw const AppException('İnternet bağlantısı kurulamadı.', offline: true);
    final body = files[path];
    if (body == null) throw const AppException('Veri henüz yayınlanmamış (404).');
    return body;
  }
}

Future<void> initTestLocale() async {
  Intl.defaultLocale = 'tr';
  await initializeDateFormatting('tr');
}

/// Uygulamayı sahte veriyle kurar.
Future<Widget> buildTestApp({
  FakeSource? source,
  LocalStore? store,
  Widget? home,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  return ProviderScope(
    // Testlerde otomatik yeniden deneme kapalı: hata hemen görünsün, bekleyen zamanlayıcı kalmasın.
    retry: (retryCount, error) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      localStoreProvider.overrideWithValue(store ?? MemoryStore()),
      dataSourceProvider.overrideWithValue(source ?? FakeSource(allFixtures())),
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

/// Uygulamayla gelen yazı tiplerini (Inter, JetBrains Mono, Material ikonları) test ortamına yükler;
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
