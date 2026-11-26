import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'state/providers.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/shell.dart';

class TechPulseApp extends ConsumerWidget {
  const TechPulseApp({super.key, this.home});

  /// Testlerde belirli bir ekranı doğrudan açmak için.
  final Widget? home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final accent = ref.watch(settingsProvider.select((s) => s.accent));
    final onboarded = ref.watch(profileProvider.select((p) => p.onboarded));
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: themeMode,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home:
          home ??
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: onboarded
                ? const AppShell(key: ValueKey('shell'))
                : const OnboardingScreen(key: ValueKey('onboarding')),
          ),
    );
  }
}
