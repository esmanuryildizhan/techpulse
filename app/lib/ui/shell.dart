import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'discover/discover_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'radar/radar_screen.dart';
import 'saved/saved_screen.dart';

/// Alt gezinme çubuğu ve beş sekme. Sekmeler birbirine geçerken kaydırma konumlarını korur; açık sekmeye
/// yeniden dokunmak sayfayı başa kaydırır.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(appTabProvider);
    return PopScope(
      // Ana sayfa dışındaki bir sekmedeyken geri tuşu önce ana sayfaya döner.
      canPop: tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(appTabProvider.notifier).select(AppTab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: tab.index,
          children: const [HomeScreen(), DiscoverScreen(), RadarScreen(), SavedScreen(), ProfileScreen()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab.index,
          onDestinationSelected: (i) => ref.read(appTabProvider.notifier).select(AppTab.values[i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Akış',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Keşfet',
            ),
            NavigationDestination(
              icon: Icon(Icons.radar_outlined),
              selectedIcon: Icon(Icons.radar_rounded),
              label: 'Radar',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'Kaydedilen',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
