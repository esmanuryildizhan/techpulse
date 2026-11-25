import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final meta = ref.watch(metaProvider).value?.data;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionLabel('Görünüm'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Sistem'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text('Açık'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Koyu'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) => controller.setThemeMode(selection.first),
            ),
          ),
          SwitchListTile(
            title: const Text('Özgün başlıkları da göster'),
            subtitle: const Text('Türkçe başlığın altında kaynağın İngilizce başlığı görünür.'),
            value: settings.showOriginalTitles,
            onChanged: controller.setShowOriginalTitles,
          ),
          const SectionLabel('Veri'),
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('Son veri güncellemesi'),
            subtitle: Text(
              meta?.generatedAt == null
                  ? 'Bilinmiyor'
                  : '${Fmt.longDate(meta!.generatedAt!)} (${Fmt.relative(meta.generatedAt!)})',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Çeviri'),
            subtitle: Text(
              meta?.translatorModel == null
                  ? 'GitHub Models üzerinden yapay zekâ ile'
                  : 'GitHub Models · ${meta!.translatorModel}'
                      '${meta.pendingTranslations > 0 ? ' · ${meta.pendingTranslations} kayıt sırada' : ''}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.rss_feed),
            title: const Text('Kaynaklar ve durumları'),
            subtitle: Text(
              meta == null
                  ? 'Yükleniyor…'
                  : '${meta.sources.where((s) => s.ok).length}/${meta.sources.length} kaynak son çalışmada başarılı',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SourcesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Önbelleği temizle'),
            subtitle: const Text('Kaydedilenler silinmez; listeler internetten yeniden indirilir.'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(localStoreProvider).clearCache();
              ref
                ..invalidate(newsProvider)
                ..invalidate(modelsProvider)
                ..invalidate(papersProvider)
                ..invalidate(reposProvider)
                ..invalidate(securityProvider)
                ..invalidate(metaProvider);
              messenger.showSnackBar(const SnackBar(content: Text('Önbellek temizlendi')));
            },
          ),
          const SectionLabel('Hakkında'),
          AboutListTile(
            icon: const Icon(Icons.info_outline),
            applicationName: AppConfig.appName,
            applicationVersion: AppConfig.appVersion,
            applicationIcon: const BrandMark(size: 48),
            applicationLegalese: '${AppConfig.university}\n${AppConfig.course} dersi projesi\n'
                'Ders sorumlusu: ${AppConfig.instructor}\n'
                'Geliştirenler: ${AppConfig.authors.join(', ')}',
            aboutBoxChildren: const [
              SizedBox(height: 16),
              Text(
                'TechPulse, yazılım, yapay zekâ, donanım ve siber güvenlik gündemini kaynaklarından toplayıp '
                'Türkçe özetler. İçeriklerin tüm hakları kaynaklarına aittir; uygulama yalnızca başlık, kısa özet '
                've kaynağa bağlantı gösterir.',
              ),
            ],
            child: const Text('TechPulse hakkında'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              '${AppConfig.university} · ${AppConfig.course}\n${AppConfig.authors.join(' · ')}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Veri hattının son çalışmasında her kaynağın durumu (meta.json).
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meta = ref.watch(metaProvider).value?.data;
    final sources = meta?.sources ?? const <SourceStatus>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Kaynaklar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: InfoNote(
              icon: Icons.info_outline,
              text: 'Veriler saatte bir, aşağıdaki kaynakların herkese açık akışlarından (RSS, API) toplanır. '
                  'Bir kaynak geçici olarak okunamazsa önceki haberleri korunur.',
            ),
          ),
          for (final source in sources)
            ListTile(
              leading: SourceAvatar(id: source.id, name: source.name, size: 36),
              title: Text(source.name),
              subtitle: Text(
                source.ok
                    ? '${source.count} kayıt okundu · ${_kindLabel(source.kind)}'
                    : 'Okunamadı: ${source.error ?? 'bilinmeyen hata'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                source.ok ? Icons.check_circle : Icons.cancel_outlined,
                color: source.ok ? scheme.primary : scheme.error,
              ),
              onTap: source.homepage == null ? null : () => openLink(context, source.homepage!),
              onLongPress: () => Clipboard.setData(ClipboardData(text: source.homepage ?? source.name)),
            ),
        ],
      ),
    );
  }

  String _kindLabel(String kind) => switch (kind) {
        'official' => 'Resmî blog',
        'news' => 'Haber sitesi',
        'community' => 'Topluluk',
        _ => 'Veri servisi',
      };
}
