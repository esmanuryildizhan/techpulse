import 'package:flutter/material.dart';

import 'news/news_screen.dart';
import 'radar/radar_screen.dart';
import 'saved/saved_screen.dart';
import 'security/security_screen.dart';

/// Ana iskelet: alttaki gezinme çubuğu ve dört sekme.
/// Sekmeler IndexedStack içinde tutulur; sekme değiştirince kaydırma konumu kaybolmaz.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.feed_outlined), selectedIcon: Icon(Icons.feed), label: 'Gündem'),
    NavigationDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome),
      label: 'YZ Radarı',
    ),
    NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Güvenlik'),
    NavigationDestination(
      icon: Icon(Icons.bookmarks_outlined),
      selectedIcon: Icon(Icons.bookmarks),
      label: 'Kaydedilenler',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [NewsScreen(), RadarScreen(), SecurityScreen(), SavedScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: _destinations,
      ),
    );
  }
}
