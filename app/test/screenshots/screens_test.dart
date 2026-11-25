@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techpulse/data/local_store.dart';
import 'package:techpulse/state/providers.dart';
import 'package:techpulse/ui/discover/discover_screen.dart';
import 'package:techpulse/ui/news/news_detail_screen.dart';
import 'package:techpulse/ui/onboarding/onboarding_screen.dart';
import 'package:techpulse/ui/profile/profile_screen.dart';
import 'package:techpulse/ui/radar/radar_cards.dart';
import 'package:techpulse/ui/radar/radar_screen.dart';
import 'package:techpulse/ui/search/search_screen.dart';
import 'package:techpulse/ui/shell.dart';
import 'package:techpulse/ui/threats/threats_screen.dart';
import 'package:techpulse/ui/updates/updates_screen.dart';

import '../helpers.dart';

/// Rapor ve görsel kontrol için ekran görüntüsü üretir:
/// `flutter test --tags screenshots --update-goldens`
/// Görüntüler test/screenshots/goldens/ klasörüne yazılır. Testlerde ağ görseli indirilmez;
/// görsel yerine her habere özel çizilen kapak görünür.
void main() {
  setUpAll(() async {
    await initTestLocale();
    await loadAppFonts();
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget? home, {
    bool dark = true,
    bool onboarded = true,
    Map<String, Object> prefs = const {},
    Future<void> Function()? act,
  }) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      await buildTestApp(home: home, onboarded: onboarded, prefs: {'settings.themeMode': dark ? 'dark' : 'light', ...prefs}),
    );
    await settle(tester);
    if (act != null) {
      await act();
      await settle(tester, frames: 10);
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    await settle(tester, frames: 30);
  }

  const interests = {'profile.interests': <String>['ai', 'security', 'mobile']};

  testWidgets('ana_sayfa_koyu', (tester) => shoot(tester, '01_ana_sayfa_koyu', const AppShell(), prefs: interests));

  testWidgets('ana_sayfa_acik', (tester) => shoot(tester, '02_ana_sayfa_acik', const AppShell(), dark: false, prefs: interests));

  testWidgets('ana_sayfa_kaydirilmis', (tester) async {
    await shoot(
      tester,
      '03_ana_sayfa_one_cikanlar',
      const AppShell(),
      prefs: interests,
      act: () => tester.drag(find.byType(CustomScrollView).first, const Offset(0, -560)),
    );
  });

  testWidgets('haber_detayi', (tester) async {
    final item = parseNews(fixture('news.json')).items.first;
    await shoot(tester, '04_haber_detayi', NewsDetailScreen(item: item));
  });

  testWidgets('haber_detayi_devami', (tester) async {
    final item = parseNews(fixture('news.json')).items.first;
    await shoot(
      tester,
      '05_haber_detayi_devami',
      NewsDetailScreen(item: item),
      act: () => tester.drag(find.byType(CustomScrollView), const Offset(0, -700)),
    );
  });

  testWidgets('kesfet', (tester) => shoot(tester, '06_kesfet', const DiscoverScreen()));

  testWidgets('kesfet_devami', (tester) async {
    await shoot(
      tester,
      '07_kesfet_devami',
      const DiscoverScreen(),
      act: () => tester.drag(find.byType(CustomScrollView), const Offset(0, -760)),
    );
  });

  testWidgets('radar_modeller', (tester) => shoot(tester, '08_radar_modeller', const RadarScreen()));

  testWidgets('radar_makaleler', (tester) => shoot(tester, '09_radar_makaleler', const RadarScreen(initialTab: RadarTab.papers)));

  testWidgets('radar_projeler', (tester) => shoot(tester, '10_radar_projeler', const RadarScreen(initialTab: RadarTab.repos)));

  testWidgets('model_karti', (tester) async {
    await shoot(tester, '11_model_karti', const RadarScreen(), act: () => tester.tap(find.byType(ModelCard).first));
  });

  testWidgets('tehditler', (tester) => shoot(tester, '12_tehditler', const ThreatsScreen()));

  testWidgets('tehdit_karti', (tester) async {
    await shoot(tester, '13_tehdit_karti', const ThreatsScreen(), act: () => tester.tap(find.byType(VulnerabilityCard).first));
  });

  testWidgets('kaydedilenler', (tester) async {
    await shoot(
      tester,
      '14_kaydedilenler',
      const AppShell(),
      act: () async {
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byTooltip('Kaydet').first);
          await settle(tester, frames: 3);
        }
        await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Kaydedilenler')));
        await settle(tester, frames: 40);
      },
    );
  });

  testWidgets('kaydedilenler_bos', (tester) async {
    await shoot(
      tester,
      '15_kaydedilenler_bos',
      const AppShell(),
      act: () => tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Kaydedilenler'))),
    );
  });

  testWidgets('profil', (tester) {
    return shoot(tester, '16_profil', const ProfileScreen(), prefs: {...interests, 'profile.name': 'Esma Nur Yıldızhan'});
  });

  testWidgets('arama', (tester) async {
    await shoot(
      tester,
      '17_arama',
      const SearchScreen(),
      act: () async {
        await tester.enterText(find.byType(TextField), 'yapay zeka');
        await settle(tester, frames: 5);
      },
    );
  });

  testWidgets('yenilikler', (tester) => shoot(tester, '18_yenilikler', const UpdatesScreen(), prefs: interests));

  testWidgets('karsilama', (tester) => shoot(tester, '19_karsilama', null, onboarded: false));

  testWidgets('karsilama_acik', (tester) => shoot(tester, '20_karsilama_acik', const OnboardingScreen(), dark: false));

  testWidgets('cevrimdisi', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp(source: FakeSource(allFixtures(), offline: true), store: MemoryStore()));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/21_ilk_acilis_internetsiz.png'));
  });
}
