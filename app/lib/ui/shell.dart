import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'discover/discover_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'saved/saved_screen.dart';

/// Alt gezinme çubuğu: Ana Sayfa, Keşfet, Kaydedilenler, Profil. Sekmeler bellekte tutulur;
/// sekme değiştirince kaydırma konumu kaybolmaz.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(appTabProvider);
    final saved = ref.watch(bookmarksProvider.select((v) => v.value?.length ?? 0));
    return Scaffold(
      body: IndexedStack(
        index: tab.index,
        children: const [HomeScreen(), DiscoverScreen(), SavedScreen(), ProfileScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: (index) => ref.read(appTabProvider.notifier).select(AppTab.values[index]),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
          const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Keşfet'),
          NavigationDestination(
            icon: Badge(isLabelVisible: saved > 0, label: Text('$saved'), child: const Icon(Icons.bookmark_outline_rounded)),
            selectedIcon: const Icon(Icons.bookmark_rounded),
            label: 'Kaydedilenler',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}
