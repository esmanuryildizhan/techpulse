@Tags(['screenshots'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techpulse/data/local_store.dart';
import 'package:techpulse/data/models.dart';
import 'package:techpulse/state/providers.dart';
import 'package:techpulse/ui/discover/discover_screen.dart';
import 'package:techpulse/ui/news/news_detail_screen.dart';
import 'package:techpulse/ui/onboarding/onboarding_screen.dart';
import 'package:techpulse/ui/profile/info_pages.dart';
import 'package:techpulse/ui/profile/interests_screen.dart';
import 'package:techpulse/ui/profile/profile_screen.dart';
import 'package:techpulse/ui/radar/radar_details.dart';
import 'package:techpulse/ui/search/search_screen.dart';
import 'package:techpulse/ui/shell.dart';

import '../helpers.dart';

/// Görsel kontrol ve rapor için ekran görüntüsü üretir:
/// `flutter test --tags screenshots --update-goldens`
/// Görüntüler test/screenshots/goldens/ klasörüne yazılır. Testlerde ağ görseli indirilmez;
/// görsel yerine her habere özel çizilen kapak görünür.
void main() {
  late List<NewsItem> news;

  setUpAll(() async {
    await initTestLocale();
    await loadAppFonts();
    news = parseNews(fixture('news.json')).items;
  });

  NewsItem richest() =>
      news.firstWhere((n) => n.story?.technical != null && n.imageUrl != null && n.story!.glossary.length > 3);

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget? home, {
    bool dark = false,
    bool onboarded = true,
    double textScale = 1,
    Map<String, Object> prefs = const {},
    LocalStore? store,
    Future<void> Function()? act,
  }) async {
    usePhoneSize(tester);
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.pumpWidget(
      await buildTestApp(
        home: home,
        store: store,
        onboarded: onboarded,
        prefs: {'settings.themeMode': dark ? 'dark' : 'light', ...prefs},
      ),
    );
    await settle(tester);
    if (act != null) {
      await act();
      await settle(tester, frames: 10);
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    await settle(tester, frames: 40);
  }

  const profile = {
    'profile.interests': <String>['ai', 'security', 'dev'],
    'profile.name': 'Esma Nur',
  };

  Finder nav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  testWidgets('akis_acik', (tester) => shoot(tester, '01_akis_acik', const AppShell(), prefs: profile));

  testWidgets('akis_koyu', (tester) => shoot(tester, '02_akis_koyu', const AppShell(), dark: true, prefs: profile));

  testWidgets('akis_kisaca', (tester) async {
    await shoot(
      tester,
      '03_akis_kisaca',
      const AppShell(),
      prefs: profile,
      act: () => tester.drag(find.byType(CustomScrollView).first, const Offset(0, -560)),
    );
  });

  testWidgets('akis_son_gelismeler', (tester) async {
    await shoot(
      tester,
      '04_akis_son_gelismeler',
      const AppShell(),
      prefs: {'profile.name': 'Esma Nur'},
      act: () async {
        await tester.tap(find.text('Tüm Gündem'));
        await settle(tester, frames: 3);
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -1150));
      },
    );
  });

  testWidgets('akis_filtre', (tester) async {
    await shoot(
      tester,
      '05_akis_filtre',
      const AppShell(),
      prefs: profile,
      act: () => tester.tap(find.byTooltip('Filtrele')),
    );
  });

  testWidgets('haber_detayi', (tester) => shoot(tester, '06_haber_detayi', NewsDetailScreen(item: richest())));

  testWidgets('haber_detayi_devami', (tester) async {
    await shoot(
      tester,
      '07_haber_detayi_devami',
      NewsDetailScreen(item: richest()),
      act: () => tester.drag(find.byType(CustomScrollView), const Offset(0, -900)),
    );
  });

  testWidgets('haber_teknik', (tester) async {
    await shoot(
      tester,
      '08_haber_teknik_koyu',
      NewsDetailScreen(item: richest()),
      dark: true,
      act: () async {
        await tester.tap(find.text('Teknik derinlik'));
        await settle(tester, frames: 4);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -620));
      },
    );
  });

  testWidgets('kavram_cekmecesi', (tester) async {
    final item = richest();
    await shoot(
      tester,
      '09_kavram_cekmecesi',
      NewsDetailScreen(item: item),
      act: () async {
        final scroll = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(find.text('Bu haberdeki kavramlar'), 500, scrollable: scroll);
        await settle(tester, frames: 3);
        await tester.tap(find.text(item.story!.glossary.first.term).last);
      },
    );
  });

  testWidgets('haber_kaynak', (tester) async {
    await shoot(
      tester,
      '10_haber_kaynak',
      NewsDetailScreen(item: richest()),
      act: () async {
        final scroll = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(find.text('Haberin aslını aç'), 600, scrollable: scroll);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      },
    );
  });

  testWidgets('kesfet', (tester) => shoot(tester, '11_kesfet', const Scaffold(body: DiscoverScreen())));

  testWidgets('kesfet_konular', (tester) async {
    await shoot(
      tester,
      '12_kesfet_konular',
      const Scaffold(body: DiscoverScreen()),
      act: () => tester.drag(find.byType(CustomScrollView), const Offset(0, -900)),
    );
  });

  testWidgets('radar_modeller', (tester) {
    return shoot(tester, '13_radar_modeller', const AppShell(), act: () => tester.tap(nav('Radar')));
  });

  testWidgets('radar_projeler', (tester) async {
    await shoot(
      tester,
      '14_radar_projeler',
      const AppShell(),
      act: () async {
        await tester.tap(nav('Radar'));
        await settle(tester, frames: 4);
        await tester.tap(find.text('Projeler'));
      },
    );
  });

  testWidgets('radar_tehditler', (tester) async {
    await shoot(
      tester,
      '15_radar_tehditler',
      const AppShell(),
      dark: true,
      act: () async {
        await tester.tap(nav('Radar'));
        await settle(tester, frames: 4);
        await tester.tap(find.text('Tehditler'));
      },
    );
  });

  testWidgets('proje_detayi', (tester) {
    final repo = parseRepos(fixture('repos.json')).items.firstWhere((r) => r.story != null);
    return shoot(tester, '16_proje_detayi', RepoDetailScreen(repo: repo));
  });

  testWidgets('tehdit_detayi', (tester) {
    final vuln = parseSecurity(fixture('security.json')).items.first;
    return shoot(tester, '17_tehdit_detayi', VulnerabilityDetailScreen(vuln: vuln));
  });

  testWidgets('model_detayi', (tester) {
    final model = parseModels(fixture('models.json')).items.first;
    return shoot(tester, '18_model_detayi', ModelDetailScreen(model: model), dark: true);
  });

  testWidgets('kaydedilenler', (tester) async {
    final visible = news.where((n) => !n.hidden).toList();
    final papers = parsePapers(fixture('papers.json')).items;
    final repos = parseRepos(fixture('repos.json')).items;
    final store = MemoryStore();
    Future<void> save(BookmarkKind kind, Entry entry, int hoursAgo) => store.saveRecord(
      UserList.bookmarks,
      BookmarkRecord(
        key: BookmarkRecord.keyFor(kind, entry.id),
        kind: kind,
        payload: jsonEncode(entry.raw),
        savedAt: testNow.subtract(Duration(hours: hoursAgo)),
      ),
    );
    await save(BookmarkKind.news, visible[0], 1);
    await save(BookmarkKind.news, visible[3], 3);
    await save(BookmarkKind.paper, papers[0], 26);
    await save(BookmarkKind.repo, repos[1], 30);
    await save(BookmarkKind.news, visible[8], 50);
    await shoot(tester, '19_kaydedilenler', const AppShell(), store: store, act: () => tester.tap(nav('Kaydedilen')));
  });

  testWidgets('kaydedilenler_bos', (tester) {
    return shoot(tester, '20_kaydedilenler_bos', const AppShell(), act: () => tester.tap(nav('Kaydedilen')));
  });

  testWidgets('profil', (tester) => shoot(tester, '21_profil', const Scaffold(body: ProfileScreen()), prefs: profile));

  testWidgets('profil_devami_koyu_mavi', (tester) async {
    await shoot(
      tester,
      '22_profil_devami_koyu_mavi',
      const Scaffold(body: ProfileScreen()),
      dark: true,
      prefs: {...profile, 'settings.accent': 'blue'},
      act: () => tester.drag(find.byType(ListView), const Offset(0, -560)),
    );
  });

  testWidgets('akis_koyu_mavi', (tester) {
    return shoot(
      tester,
      '23_akis_koyu_mavi',
      const AppShell(),
      dark: true,
      prefs: {...profile, 'settings.accent': 'blue'},
    );
  });

  testWidgets('ilgi_alanlari', (tester) => shoot(tester, '24_ilgi_alanlari', const InterestsScreen(), prefs: profile));

  testWidgets('arama', (tester) async {
    await shoot(
      tester,
      '25_arama',
      const SearchScreen(),
      act: () async {
        await tester.enterText(find.byType(TextField), 'yapay zeka');
        await settle(tester, frames: 5);
        FocusManager.instance.primaryFocus?.unfocus();
      },
    );
  });

  testWidgets('karsilama', (tester) => shoot(tester, '26_karsilama', null, onboarded: false));

  testWidgets('karsilama_konular', (tester) async {
    await shoot(
      tester,
      '27_karsilama_konular_koyu',
      const OnboardingScreen(),
      dark: true,
      act: () async {
        await tester.tap(find.text('Devam'));
        await settle(tester, frames: 6);
        await tester.tap(find.text('Yapay Zekâ'));
        await tester.tap(find.text('Siber Güvenlik'));
      },
    );
  });

  testWidgets('hakkinda', (tester) => shoot(tester, '28_hakkinda', const AboutScreen()));

  testWidgets('internetsiz', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(await buildTestApp(source: FakeSource(allFixtures(), offline: true), store: MemoryStore()));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/29_ilk_acilis_internetsiz.png'));
  });

  testWidgets('akis_buyuk_yazi', (tester) {
    return shoot(tester, '30_akis_buyuk_yazi', const AppShell(), prefs: profile, textScale: 1.3);
  });

  testWidgets('kesfet_buyuk_yazi', (tester) {
    return shoot(
      tester,
      '31_kesfet_buyuk_yazi',
      const Scaffold(body: DiscoverScreen()),
      textScale: 1.3,
      act: () {
        return tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      },
    );
  });
}
