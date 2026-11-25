import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../state/providers.dart';
import '../saved/record_views.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

// ---------------------------------------------------------------------------
// Profili düzenle
// ---------------------------------------------------------------------------

Future<void> showEditProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _EditProfileSheet(),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _name = TextEditingController(text: ref.read(profileProvider).name);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final value = _name.text.trim();
    if (value.length > 40) {
      setState(() => _error = 'Ad en fazla 40 karakter olabilir.');
      return;
    }
    ref.read(profileProvider.notifier).setName(value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profili düzenle', style: context.text.titleLarge),
          const SizedBox(height: 18),
          const Center(child: ProfileAvatar(size: 72)),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              spacing: 10,
              children: [
                for (final (index, color) in avatarColors.indexed)
                  Semantics(
                    button: true,
                    selected: profile.colorIndex == index,
                    label: 'Avatar rengi ${index + 1}',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => ref.read(profileProvider.notifier).setColor(index),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: profile.colorIndex == index ? context.tp.textPrimary : Colors.transparent, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(labelText: 'Adın', hintText: 'Esma Nur', errorText: _error),
          ),
          const SizedBox(height: 8),
          Text('Adın yalnızca bu telefonda saklanır ve kimseyle paylaşılmaz.', style: context.text.bodySmall),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('Kaydet'))),
        ],
      ),
    );
  }
}

/// Telefondaki kişisel verileri sıfırlar (hesap olmadığı için "oturumu kapat" yerine geçer).
Future<void> confirmReset(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Verilerin sıfırlansın mı?'),
      content: const Text(
        'Kaydedilenler, favoriler, okuma geçmişi, ilgi alanları ve profil bilgilerin bu telefondan silinir. '
        'Haberler etkilenmez. Bu işlem geri alınamaz.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.tp.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sıfırla'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(bookmarksProvider.notifier).clear();
  await ref.read(favoritesProvider.notifier).clear();
  await ref.read(historyProvider.notifier).clear();
  await ref.read(profileProvider.notifier).reset();
  ref.read(appTabProvider.notifier).select(AppTab.home);
}

// ---------------------------------------------------------------------------
// İlgi alanlarım
// ---------------------------------------------------------------------------

/// Konu seçim ızgarası; ilk açılış ekranı ve İlgi Alanlarım sayfası ortak kullanır.
class InterestPicker extends StatelessWidget {
  const InterestPicker({super.key, required this.selected, required this.onToggle});

  final List<TechCategory> selected;
  final ValueChanged<TechCategory> onToggle;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 96),
      itemCount: TechCategory.values.length,
      itemBuilder: (context, index) {
        final category = TechCategory.values[index];
        final order = selected.indexOf(category);
        final active = order >= 0;
        final tone = category.tone(context.brightness);
        return Semantics(
          selected: active,
          button: true,
          label: category.label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: active ? tone.withValues(alpha: 0.12) : tp.card,
              borderRadius: BorderRadius.circular(Tp.radius),
              border: Border.all(color: active ? tone : tp.border, width: active ? 1.5 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(Tp.radius),
              onTap: () => onToggle(category),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(category.icon, color: tone, size: 22),
                        const Spacer(),
                        if (active)
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                            child: Text('${order + 1}', style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(category.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(height: 1.2)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class InterestsScreen extends ConsumerWidget {
  const InterestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('İlgi Alanlarım')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tp.page, 4, Tp.page, 32),
        children: [
          Text(
            'Takip etmek istediğin konuları seç. Seçtiğin sıra önemlidir: ana sayfadaki konu filtreleri bu sırayla '
            'gösterilir ve bu konulardaki haberler öne çıkarılır.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 18),
          InterestPicker(selected: profile.interests, onToggle: (c) => ref.read(profileProvider.notifier).toggleInterest(c)),
          if (profile.interests.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref.read(profileProvider.notifier).setInterests(const []),
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Seçimleri temizle'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Okuma geçmişi ve favoriler
// ---------------------------------------------------------------------------

class _RecordListScreen extends ConsumerWidget {
  const _RecordListScreen({required this.title, required this.provider, required this.emptyTitle, required this.emptyMessage, required this.icon, required this.notePrefix});

  final String title;
  final AsyncNotifierProvider<UserListController, List<BookmarkRecord>> provider;
  final String emptyTitle;
  final String emptyMessage;
  final IconData icon;
  final String notePrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(provider).value ?? const <BookmarkRecord>[];
    final decoded = [
      for (final r in records)
        if (decodeRecord(r) case final entry?) (record: r, entry: entry),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (decoded.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('$title temizlensin mi?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Temizle')),
                    ],
                  ),
                );
                if (ok == true) await ref.read(provider.notifier).clear();
              },
              child: const Text('Temizle'),
            ),
        ],
      ),
      body: decoded.isEmpty
          ? EmptyState(icon: icon, title: emptyTitle, message: emptyMessage)
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: decoded.length,
              separatorBuilder: (context, index) => Divider(indent: Tp.page, endIndent: Tp.page, color: context.tp.border),
              itemBuilder: (context, index) => RecordRow(
                record: decoded[index].record,
                entry: decoded[index].entry,
                note: '$notePrefix ${Fmt.relative(decoded[index].record.savedAt)}',
              ),
            ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => _RecordListScreen(
        title: 'Okuma Geçmişim',
        provider: historyProvider,
        icon: Icons.history_rounded,
        emptyTitle: 'Henüz haber okumadın',
        emptyMessage: 'Açtığın haberler ve makaleler burada listelenir. Geçmiş yalnızca bu telefonda saklanır.',
        notePrefix: 'Okundu',
      );
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) => _RecordListScreen(
        title: 'Favorilerim',
        provider: favoritesProvider,
        icon: Icons.favorite_border_rounded,
        emptyTitle: 'Henüz favorin yok',
        emptyMessage: 'Haber ve makale sayfalarındaki kalp simgesiyle beğendiğin içerikleri burada toplayabilirsin.',
        notePrefix: 'Beğenildi',
      );
}

// ---------------------------------------------------------------------------
// Bildirim ayarları
// ---------------------------------------------------------------------------

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final notifier = ref.read(profileProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Ayarları')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tp.page, 4, Tp.page, 32),
        children: [
          Text(
            'Seçtiğin gelişmeler ana sayfadaki zil simgesinde "Yenilikler" olarak toplanır ve okunmamış sayısı gösterilir.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 16),
          TpCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: profile.notifyInterests,
                  onChanged: (v) => notifier.setNotify(interests: v),
                  title: const Text('İlgi alanlarımdaki yeni haberler'),
                  subtitle: Text(profile.interests.isEmpty ? 'Önce ilgi alanı seçmelisin' : profile.interests.map((c) => c.label).join(', ')),
                ),
                Divider(height: 1, color: context.tp.border),
                SwitchListTile(
                  value: profile.notifyImportant,
                  onChanged: (v) => notifier.setNotify(important: v),
                  title: const Text('Önemli gelişmeler'),
                  subtitle: const Text('Editörün yüksek önem verdiği haberler'),
                ),
                Divider(height: 1, color: context.tp.border),
                SwitchListTile(
                  value: profile.notifyThreats,
                  onChanged: (v) => notifier.setNotify(threats: v),
                  title: const Text('Yeni aktif siber tehditler'),
                  subtitle: const Text('CISA kataloğuna eklenen açıklar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoBox(
            icon: Icons.info_outline_rounded,
            title: 'Telefon bildirimleri',
            tone: context.tp.secondary,
            child: Text(
              'Bu sürümde bildirimler uygulama içinde gösterilir; uygulama kapalıyken telefona bildirim gönderilmez.',
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Görünüm, dil ve çeviri
// ---------------------------------------------------------------------------

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Görünüm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tp.page, 4, Tp.page, 32),
        children: [
          Text('Tema', style: context.text.titleSmall),
          const SizedBox(height: 10),
          for (final (mode, title, subtitle, icon) in [
            (ThemeMode.dark, 'Koyu', 'Varsayılan; gece okumak için göz yormaz', Icons.dark_mode_outlined),
            (ThemeMode.light, 'Açık', 'Gün ışığında daha okunaklı', Icons.light_mode_outlined),
            (ThemeMode.system, 'Sistem', 'Telefonun ayarını izler', Icons.brightness_auto_outlined),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TpCard(
                onTap: () => notifier.setThemeMode(mode),
                color: settings.themeMode == mode ? context.tp.primarySoft : null,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, color: settings.themeMode == mode ? context.tp.primary : context.tp.textSecondary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(title, style: context.text.titleSmall), Text(subtitle, style: context.text.bodySmall)],
                      ),
                    ),
                    if (settings.themeMode == mode) Icon(Icons.check_circle_rounded, color: context.tp.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final meta = ref.watch(metaProvider).value?.data;
    return Scaffold(
      appBar: AppBar(title: const Text('Dil ve Çeviri')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tp.page, 4, Tp.page, 32),
        children: [
          TpCard(
            child: Column(
              children: [
                const ListTile(leading: Icon(Icons.language_rounded), title: Text('Uygulama dili'), trailing: Text('Türkçe')),
                Divider(height: 1, color: context.tp.border),
                SwitchListTile(
                  value: settings.showOriginalTitles,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setShowOriginalTitles(v),
                  title: const Text('Orijinal başlıkları da göster'),
                  subtitle: const Text('Türkçe başlığın altında kaynağın kendi başlığı görünür'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoBox(
            icon: Icons.auto_awesome_outlined,
            title: 'Haberler nasıl Türkçeleşiyor?',
            child: Text(
              'TechPulse editörü her haberin kaynağını okur ve yapay zekâ desteğiyle ${meta?.editorModel != null ? '(${meta!.editorModel}) ' : ''}'
              'özgün bir Türkçe başlık, kısa özet ve ayrıntılı anlatım yazar. Kaynaktaki olgulara bağlı kalınır; haberin tamamı '
              'kopyalanmaz ve her haberde orijinal kaynağa bağlantı verilir. Yapay zekâ yine de hata yapabilir; önemli kararlar için '
              'kaynağa başvurun.',
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kaynaklar ve veri
// ---------------------------------------------------------------------------

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(metaProvider).value?.data;
    final sources = [...?meta?.sources]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final ok = sources.where((s) => s.ok).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Kaynaklar ve Veri')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tp.page, 4, Tp.page, 32),
        children: [
          Text(
            'Haberler, yayıncıların kendi RSS/Atom akışlarından ve herkese açık veri servislerinden saatte bir toplanır.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (meta != null)
            TpCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Son güncelleme: ${meta.generatedAt == null ? '-' : Fmt.longDate(meta.generatedAt!)}', style: context.text.titleSmall),
                  const SizedBox(height: 4),
                  Text('$ok / ${sources.length} kaynak son çalışmada başarıyla okundu.', style: context.text.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TpCard(
            child: Column(
              children: [
                for (final (index, source) in sources.indexed) ...[
                  if (index > 0) Divider(height: 1, indent: 64, color: context.tp.border),
                  ListTile(
                    leading: SourceAvatar(name: source.name, size: 32),
                    title: Text(source.name),
                    subtitle: Text(source.ok ? '${source.count} kayıt' : 'Okunamadı: ${source.error ?? 'bilinmeyen hata'}', maxLines: 2),
                    trailing: Icon(
                      source.ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                      color: source.ok ? context.tp.success : context.tp.warning,
                      size: 20,
                    ),
                    onTap: source.homepage == null ? null : () => openLink(context, source.homepage!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(localStoreProvider).clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önbellek temizlendi; veriler yeniden indirilecek.')));
              }
            },
            icon: const Icon(Icons.cleaning_services_outlined, size: 18),
            label: const Text('Önbelleği temizle'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gizlilik ve hakkında
// ---------------------------------------------------------------------------

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget block(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(title, style: context.text.titleSmall), const SizedBox(height: 6), Text(body, style: context.text.bodyMedium)],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik ve Kullanım')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tp.page, 4, Tp.page, 32),
        children: [
          block('Kişisel veri', 'TechPulse hesap istemez ve kişisel veri toplamaz. Adın, ilgi alanların, kaydettiklerin, favorilerin ve okuma geçmişin yalnızca bu telefonda saklanır; hiçbir sunucuya gönderilmez.'),
          block('İzinler', 'Uygulama yalnızca internet erişimi ister. Konum, kamera, rehber gibi izinler kullanılmaz; reklam veya analiz aracı yoktur.'),
          block('İçerik ve telif', 'Haberler, kaynağın yayımladığı içerik temel alınarak özgün Türkçe anlatımla sunulur; haberin tamamı kopyalanmaz. Görseller ve haberin tüm hakları kaynağına aittir; her haberde orijinal kaynağa bağlantı verilir.'),
          block('Yapay zekâ', 'Türkçe metinler yapay zekâ desteğiyle yazılır ve hata içerebilir. Önemli kararlar vermeden önce orijinal kaynağı okumanı öneririz.'),
          block('Verilerin silinmesi', 'Profil → "Bu telefondaki verilerimi sıfırla" ile tüm kişisel verilerini silebilirsin. Uygulamayı kaldırmak da bu verileri siler.'),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uygulama Hakkında')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 32),
        children: [
          const Center(child: BrandMark(size: 72)),
          const SizedBox(height: 14),
          Center(child: Text(AppConfig.appName, style: context.text.headlineSmall)),
          Center(child: Text(AppConfig.slogan, style: context.text.bodyMedium)),
          Center(child: Text('Sürüm ${AppConfig.appVersion}', style: context.text.bodySmall)),
          const SizedBox(height: 22),
          TpCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppConfig.university, style: context.text.titleSmall),
                const SizedBox(height: 4),
                Text('${AppConfig.course} dersi dönem projesi', style: context.text.bodyMedium),
                const SizedBox(height: 4),
                Text('Ders sorumlusu: ${AppConfig.instructor}', style: context.text.bodyMedium),
                const SizedBox(height: 12),
                Text('Hazırlayanlar', style: context.text.labelMedium),
                const SizedBox(height: 4),
                for (final author in AppConfig.authors) Text(author, style: context.text.bodyMedium?.copyWith(color: context.tp.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => openLink(context, AppConfig.repositoryUrl),
            icon: const Icon(Icons.code_rounded, size: 18),
            label: const Text('Kaynak kodu (GitHub)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(context: context, applicationName: AppConfig.appName, applicationVersion: AppConfig.appVersion),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Açık kaynak lisansları'),
          ),
        ],
      ),
    );
  }
}
