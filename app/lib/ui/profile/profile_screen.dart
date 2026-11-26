import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../news/story_reader.dart' show showReadingSizeSheet;
import '../widgets/common.dart';
import 'history_screen.dart';
import 'info_pages.dart';
import 'interests_screen.dart';

/// Profil ve ayarlar. Her ayar tek bir yerde bulunur.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _resetAll() async {
    final ok = await confirmAction(
      context,
      title: 'Bütün verileriniz silinsin mi?',
      message:
          'Adınız, ilgi alanlarınız, ayarlarınız, kaydettikleriniz ve okuma geçmişiniz bu telefondan silinir; '
          'uygulama ilk açılış ekranına döner. Bu işlem geri alınamaz.',
      confirmLabel: 'Hepsini sil',
    );
    if (!ok || !mounted) return;
    await resetAllUserData(ref);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopProvider, (_, next) {
      if (next.tab == AppTab.profile && _scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
    final tp = context.tp;
    final profile = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final saved = ref.watch(bookmarksProvider).value?.length ?? 0;
    final read = ref.watch(historyProvider).value?.length ?? 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            const ScreenHeader(title: 'Profil'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tp.page),
              child: TpCard(
                onTap: () => showEditNameSheet(context),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ProfileAvatar(initials: profile.initials, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.displayName, style: context.text.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            profile.name.isEmpty
                                ? 'Adınızı ekleyin; sizi ana sayfada adınızla selamlayalım.'
                                : 'Hesap yok · her şey bu telefonda',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, size: 20, color: tp.textTertiary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tp.page),
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      value: saved,
                      label: 'Kaydedilen',
                      icon: Icons.bookmark_border_rounded,
                      onTap: () => ref.read(appTabProvider.notifier).select(AppTab.saved),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      value: read,
                      label: 'Okuma geçmişi',
                      icon: Icons.history_rounded,
                      onTap: () => _push(const HistoryScreen()),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'İlgi alanları',
              action: 'Düzenle',
              onAction: () => _push(const InterestsScreen()),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: profile.interests.isEmpty
                    ? Text('Seçilmedi · "Sizin İçin" bütün konuları gösteriyor.', style: context.text.bodyMedium)
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in profile.interests)
                            Pill(c.shortLabel, icon: c.icon, color: c.tone(context.brightness)),
                        ],
                      ),
              ),
            ),
            _Section(
              title: 'Görünüm',
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tema', style: context.text.labelMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Sistem'),
                            icon: Icon(Icons.brightness_auto_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Açık'),
                            icon: Icon(Icons.light_mode_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Koyu'),
                            icon: Icon(Icons.dark_mode_outlined, size: 18),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (s) => controller.setThemeMode(s.first),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      settings.themeMode == ThemeMode.system ? 'Telefonunuzun açık/koyu ayarına uyar.' : ' ',
                      style: context.text.labelSmall,
                    ),
                    const SizedBox(height: 14),
                    Text('Uygulama rengi', style: context.text.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Düğmeler, seçili sekme, logo ve profil simgeniz bu renge bürünür.',
                      style: context.text.labelSmall,
                    ),
                    const SizedBox(height: 12),
                    _AccentPicker(selected: settings.accent, onSelected: controller.setAccent),
                  ],
                ),
              ),
            ),
            _Section(
              title: 'Okuma',
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.format_size_rounded),
                    title: const Text('Yazı boyutu'),
                    subtitle: Text(settings.readingSize.label),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showReadingSizeSheet(context),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haberler önce hangi anlatımla açılsın?',
                          style: context.text.bodyLarge?.copyWith(fontSize: 15.5),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ReadingLevel>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: ReadingLevel.simple,
                                label: Text('Sade'),
                                icon: Icon(Icons.spa_outlined, size: 18),
                              ),
                              ButtonSegment(
                                value: ReadingLevel.technical,
                                label: Text('Teknik'),
                                icon: Icon(Icons.bolt_rounded, size: 18),
                              ),
                            ],
                            selected: {settings.readingLevel},
                            onSelectionChanged: (s) => controller.setReadingLevel(s.first),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(settings.readingLevel.description, style: context.text.labelSmall),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: const Text('Orijinal başlığı da göster'),
                    subtitle: const Text('Haber sayfasında Türkçe başlığın altında'),
                    value: settings.showOriginalTitles,
                    onChanged: controller.setShowOriginalTitles,
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: const Text('Okuma geçmişini tut'),
                    subtitle: const Text('Son 90 gün, en fazla 200 kayıt; yalnızca bu telefonda'),
                    value: settings.recordHistory,
                    onChanged: controller.setRecordHistory,
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Veri ve gizlilik',
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.rss_feed_rounded),
                    title: const Text('Kaynaklar'),
                    subtitle: const Text('Haberlerin geldiği yerler ve son güncelleme'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _push(const SourcesScreen()),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Gizlilik'),
                    subtitle: const Text('Hangi veri nerede saklanır?'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _push(const PrivacyScreen()),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: tp.danger),
                    title: Text('Tüm verilerimi sil', style: TextStyle(color: tp.danger)),
                    subtitle: const Text('Profil, ayarlar, kaydedilenler ve geçmiş'),
                    onTap: _resetAll,
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Hakkında',
              child: ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text(AppConfig.appName),
                subtitle: const Text('Sürüm ${AppConfig.appVersion}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _push(const AboutScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profil simgesi: baş harfler, uygulama renginde.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.initials, this.size = 40});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tp.accent, shape: BoxShape.circle),
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, color: tp.onAccent, size: size * 0.55)
          : Text(
              initials,
              style: TextStyle(
                fontFamily: Tp.sans,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w700,
                color: tp.onAccent,
              ),
            ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, required this.icon, required this.onTap});

  final int value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return TpCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: Tp.headline(context, size: 22, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
              ],
            ),
          ),
          Icon(icon, size: 20, color: tp.textTertiary),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action, this.onAction});

  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: title,
            action: action,
            onAction: onAction,
            padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page - 8, 8),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tp.page),
            child: SizedBox(
              width: double.infinity,
              child: TpCard(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.onSelected});

  final AccentColor selected;
  final ValueChanged<AccentColor> onSelected;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in AccentColor.values)
          Semantics(
            label: c.label,
            selected: c == selected,
            button: true,
            child: Tooltip(
              message: c.label,
              child: InkResponse(
                onTap: () => onSelected(c),
                radius: 26,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c == selected ? c.tone(context.brightness) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(color: c.tone(context.brightness), shape: BoxShape.circle),
                    child: c == selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: c.tone(context.brightness).computeLuminance() > 0.45 ? tp.text : Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ad düzenleme. Ad, ana sayfadaki selamda ve profil simgesindeki baş harflerde kullanılır.
Future<void> showEditNameSheet(BuildContext context) {
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _EditNameSheet());
}

class _EditNameSheet extends ConsumerStatefulWidget {
  const _EditNameSheet();

  @override
  ConsumerState<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<_EditNameSheet> {
  late final TextEditingController _name = TextEditingController(text: ref.read(profileProvider).name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(profileProvider.notifier).setName(_name.text);
    showMessage(context, _name.text.trim().isEmpty ? 'Ad kaldırıldı.' : 'Adınız kaydedildi.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Size nasıl seslenelim?', style: context.text.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Ana sayfada sizi bu adla selamlarız. Yalnızca bu telefonda saklanır.',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(hintText: 'Adınız (isteğe bağlı)'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Kaydet')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
