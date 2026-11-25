@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techpulse/data/local_store.dart';
import 'package:techpulse/state/providers.dart';
import 'package:techpulse/ui/home_shell.dart';
import 'package:techpulse/ui/news/news_detail_screen.dart';
import 'package:techpulse/ui/radar/paper_detail_screen.dart';
import 'package:techpulse/ui/radar/radar_cards.dart';
import 'package:techpulse/ui/radar/radar_screen.dart';
import 'package:techpulse/ui/security/security_screen.dart';
import 'package:techpulse/ui/settings/settings_screen.dart';

import '../helpers.dart';

/// Rapor ve görsel kontrol için ekran görüntüsü üretir:
/// `flutter test --tags screenshots --update-goldens`
/// Görüntüler test/screenshots/goldens/ klasörüne yazılır.
void main() {
  setUpAll(() async {
    await initTestLocale();
    await loadAppFonts();
  });

  Future<void> shoot(WidgetTester tester, String name, Widget home, {bool dark = false, Future<void> Function()? act}) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp(home: home, prefs: {'settings.themeMode': dark ? 'dark' : 'light'}));
    await settle(tester);
    if (act != null) {
      await act();
      await settle(tester, frames: 8);
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    await settle(tester, frames: 30);
  }

  for (final dark in [false, true]) {
    final suffix = dark ? 'koyu' : 'acik';

    testWidgets('gundem_$suffix', (tester) => shoot(tester, '01_gundem_$suffix', const HomeShell(), dark: dark));

    testWidgets('radar_modeller_$suffix', (tester) => shoot(tester, '02_radar_modeller_$suffix', const HomeShell(initialIndex: 1), dark: dark));

    testWidgets('guvenlik_$suffix', (tester) => shoot(tester, '05_guvenlik_$suffix', const HomeShell(initialIndex: 2), dark: dark));
  }

  testWidgets('radar_makaleler', (tester) => shoot(tester, '03_radar_makaleler', const RadarScreen(initialTab: 1)));

  testWidgets('radar_projeler', (tester) => shoot(tester, '04_radar_projeler', const RadarScreen(initialTab: 2)));

  testWidgets('haber_detayi', (tester) async {
    final item = parseNews(fixture('news.json')).items.first;
    await shoot(tester, '06_haber_detayi', NewsDetailScreen(item: item));
  });

  testWidgets('makale_detayi', (tester) async {
    final paper = parsePapers(fixture('papers.json')).items.first;
    await shoot(tester, '07_makale_detayi', PaperDetailScreen(paper: paper));
  });

  testWidgets('model_karti', (tester) async {
    await shoot(
      tester,
      '08_model_karti',
      const HomeShell(initialIndex: 1),
      act: () => tester.tap(find.byType(ModelCard).first),
    );
  });

  testWidgets('guvenlik_karti', (tester) async {
    await shoot(
      tester,
      '09_guvenlik_karti',
      const HomeShell(initialIndex: 2),
      act: () => tester.tap(find.byType(VulnerabilityCard).first),
    );
  });

  testWidgets('arama', (tester) async {
    await shoot(
      tester,
      '10_arama',
      const HomeShell(),
      act: () async {
        await tester.tap(find.byTooltip('Ara').first);
        await settle(tester, frames: 6);
        await tester.enterText(find.byType(TextField), 'model');
      },
    );
  });

  testWidgets('kaydedilenler', (tester) async {
    await shoot(
      tester,
      '11_kaydedilenler',
      const HomeShell(),
      act: () async {
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.byTooltip('Kaydet').first);
          await settle(tester, frames: 3);
        }
        await tester.tap(find.text('Kaydedilenler'));
      },
    );
  });

  testWidgets('ayarlar', (tester) => shoot(tester, '12_ayarlar', const SettingsScreen()));

  testWidgets('cevrimdisi', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp(source: FakeSource(allFixtures(), offline: true), store: MemoryStore()));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/13_ilk_acilis_internetsiz.png'));
  });
}
