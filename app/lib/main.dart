import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/local_store.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih ve sayı biçimleri ("24 Kasım", "1,2 Mn").
  Intl.defaultLocale = 'tr';
  await initializeDateFormatting('tr');

  // Paketle gelen yazı tiplerinin lisanslarını "Lisanslar" sayfasına ekle.
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [('Inter', 'OFL-Inter.txt'), ('JetBrains Mono', 'OFL-JetBrainsMono.txt')]) {
      final text = await rootBundle.loadString('assets/fonts/$file');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });

  final prefs = await SharedPreferences.getInstance();
  final store = await openLocalStore();

  runApp(
    ProviderScope(
      // Ağ hatasında en fazla 3 kez, artan aralıklarla (1, 2, 4 sn) kendiliğinden yeniden dener.
      retry: (retryCount, error) => retryCount >= 3 ? null : Duration(seconds: 1 << retryCount),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localStoreProvider.overrideWithValue(store),
      ],
      child: const TechPulseApp(),
    ),
  );
}
