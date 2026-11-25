import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'profile_pages.dart';

/// Avatar renkleri.
const avatarColors = [
  Color(0xFF7047F5),
  Color(0xFF3988FF),
  Color(0xFF0EA5A4),
  Color(0xFFDB2777),
  Color(0xFFEA580C),
  Color(0xFF16A34A),
];

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final color = avatarColors[profile.colorIndex % avatarColors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Text(
        profile.initials,
        style: TextStyle(fontFamily: 'Inter', fontSize: size * 0.36, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// Profil: kullanıcının uygulamadaki kişisel merkezi. Bilgiler yalnızca bu telefonda saklanır.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final saved = ref.watch(bookmarksProvider).value?.length ?? 0;
    final read = ref.watch(historyProvider).value?.length ?? 0;
    final favorites = ref.watch(favoritesProvider).value?.length ?? 0;
    final tp = context.tp;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const ScreenTitle('Profil'),
          Padding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 12, Tp.page, 0),
            child: TpCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const ProfileAvatar(size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.displayName, style: context.text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_android_rounded, size: 14, color: tp.textMuted),
                            const SizedBox(width: 4),
                            Expanded(child: Text('Bu telefonda saklanan profil', style: context.text.bodySmall)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
                          onPressed: () => showEditProfileSheet(context),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Profili düzenle'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 12, Tp.page, 0),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '$saved',
                    label: 'Kaydedilen',
                    icon: Icons.bookmark_outline_rounded,
                    onTap: () => ref.read(appTabProvider.notifier).select(AppTab.saved),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(value: '$read', label: 'Okunan', icon: Icons.menu_book_outlined, onTap: () => _push(context, const HistoryScreen())),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(value: '$favorites', label: 'Favori', icon: Icons.favorite_border_rounded, onTap: () => _push(context, const FavoritesScreen())),
                ),
              ],
            ),
          ),
          SectionHeader(
            'İlgi alanların',
            actionLabel: 'Düzenle',
            onAction: () => _push(context, const InterestsScreen()),
            padding: const EdgeInsets.fromLTRB(Tp.page, 24, Tp.page - 8, 10),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tp.page),
            child: profile.interests.isEmpty
                ? Text('Henüz ilgi alanı seçmedin. Seçtiğin konular ana sayfada önce gösterilir.', style: context.text.bodyMedium)
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final c in profile.interests) CategoryBadge(c)],
                  ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tp.page),
            child: TpCard(
              child: Column(
                children: [
                  _Tile(Icons.interests_outlined, 'İlgi Alanlarım', () => _push(context, const InterestsScreen())),
                  _Tile(Icons.history_rounded, 'Okuma Geçmişim', () => _push(context, const HistoryScreen())),
                  _Tile(Icons.notifications_none_rounded, 'Bildirim Ayarları', () => _push(context, const NotificationSettingsScreen())),
                  _Tile(Icons.palette_outlined, 'Görünüm', () => _push(context, const AppearanceScreen())),
                  _Tile(Icons.translate_rounded, 'Dil ve Çeviri', () => _push(context, const LanguageScreen())),
                  _Tile(Icons.dns_outlined, 'Kaynaklar ve Veri', () => _push(context, const SourcesScreen())),
                  _Tile(Icons.privacy_tip_outlined, 'Gizlilik ve Kullanım Koşulları', () => _push(context, const PrivacyScreen())),
                  _Tile(Icons.info_outline_rounded, 'Uygulama Hakkında', () => _push(context, const AboutScreen()), last: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tp.page),
            child: TpCard(
              child: _Tile(
                Icons.restart_alt_rounded,
                'Bu telefondaki verilerimi sıfırla',
                () => confirmReset(context, ref),
                last: true,
                color: tp.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.title, this.onTap, {this.last = false, this.color});

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool last;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Column(
      children: [
        ListTile(
          minTileHeight: 54,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: (color ?? tp.primary).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: color ?? tp.primary),
          ),
          title: Text(title, style: context.text.titleSmall?.copyWith(color: color)),
          trailing: Icon(Icons.chevron_right_rounded, color: tp.textMuted),
          onTap: onTap,
        ),
        if (!last) Divider(indent: 66, height: 1, color: tp.border),
      ],
    );
  }
}
