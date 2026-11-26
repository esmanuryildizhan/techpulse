import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/news_image.dart';
import 'news_cards.dart';
import 'story_view.dart';

/// Haber ayrıntısı: başlık, "30 saniyede oku", sade veya teknik anlatım, kavramlar, kaynak ve ilgili haberler.
class NewsDetailScreen extends ConsumerStatefulWidget {
  const NewsDetailScreen({super.key, required this.item});

  final NewsItem item;

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  final _scroll = ScrollController();
  final _progress = ValueNotifier<double>(0);
  final _showTitle = ValueNotifier<bool>(false);
  late ReadingLevel _level = ref.read(settingsProvider).readingLevel;

  NewsItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(settingsProvider).recordHistory) {
        ref.read(historyProvider.notifier).add(BookmarkKind.news, item);
      }
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final max = position.maxScrollExtent;
    _progress.value = max <= 0 ? 1 : (position.pixels / max).clamp(0.0, 1.0);
    _showTitle.value = position.pixels > 140;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _progress.dispose();
    _showTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final settings = ref.watch(settingsProvider);
    final scale = settings.readingSize.scale;
    final story = item.story;
    final level = story?.technical == null ? ReadingLevel.simple : _level;
    final related = _related(ref.watch(visibleNewsProvider));

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            titleSpacing: 0,
            title: ValueListenableBuilder<bool>(
              valueListenable: _showTitle,
              builder: (context, show, _) => AnimatedOpacity(
                opacity: show ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Text(
                  item.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Yazı boyutu',
                onPressed: () => showReadingSizeSheet(context),
                icon: const Icon(Icons.format_size_rounded),
              ),
              BookmarkButton(kind: BookmarkKind.news, entry: item),
              IconButton(
                tooltip: 'Paylaş',
                onPressed: () => shareLink(context, title: item.displayTitle, url: item.url),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2.5),
              child: ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                  semanticsLabel: 'Okuma ilerlemesi',
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 12, Tp.page, 0),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Flexible(child: CategoryLabel(item.category, short: false)),
                    if (story?.fromExcerpt ?? false) ...[
                      const SizedBox(width: 10),
                      Pill('Kısa kaynak', color: tp.textTertiary),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    item.displayTitle,
                    style: Tp.headline(
                      context,
                      size: 26 * scale.clamp(0.9, 1.15),
                      weight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                if (settings.showOriginalTitles && item.hasDifferentOriginal) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.titleOriginal,
                    style: context.text.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: tp.textTertiary),
                  ),
                ],
                const SizedBox(height: 14),
                MetaLine(
                  leading: SourceAvatar(name: item.sourceName, size: 22),
                  parts: [item.sourceName, Fmt.longDate(item.publishedAt), '${item.minutes} dk okuma'],
                  color: tp.textSecondary,
                  maxLines: 2,
                ),
                if (item.imageUrl != null) ...[
                  const SizedBox(height: 18),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: NewsImage(
                      url: item.imageUrl,
                      seed: item.id,
                      category: item.category,
                      borderRadius: BorderRadius.circular(Tp.radius),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Görsel: ${item.domain}', style: context.text.labelSmall),
                ],
                const SizedBox(height: 22),
                if (story == null)
                  ..._fallback(context, scale)
                else ...[
                  if (story.technical != null) ...[
                    _LevelToggle(level: level, onChanged: (l) => setState(() => _level = l)),
                    const SizedBox(height: 20),
                  ],
                  if (story.tldr.isNotEmpty) ...[
                    TldrPanel(points: story.tldr, scale: scale),
                    const SizedBox(height: 24),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: StoryContent(key: ValueKey(level), story: story, level: level, scale: scale),
                  ),
                  if (story.fromExcerpt) ...[
                    const SizedBox(height: 4),
                    _Note(
                      icon: Icons.info_outline_rounded,
                      text:
                          '${item.sourceName} bu haberin yalnızca kısa bir bölümünü yayımlıyor; yazı bu bölüme '
                          'dayanıyor. Ayrıntılar için haberin aslına bakabilirsiniz.',
                    ),
                  ],
                  if (story.glossary.isNotEmpty) ...[
                    const SizedBox(height: Tp.section - 8),
                    const SectionHeader(
                      title: 'Bu haberdeki kavramlar',
                      subtitle: 'Metinde altı çizili kelimelere dokunarak da açabilirsiniz.',
                      padding: EdgeInsets.only(bottom: 12),
                    ),
                    GlossaryList(entries: story.glossary),
                  ],
                ],
                const SizedBox(height: Tp.section),
                _SourceBox(item: item),
                const SizedBox(height: 14),
                if (item.aiWritten)
                  Text(
                    'Bu yazı, kaynak haberden yapay zekâ desteğiyle Türkçe olarak hazırlandı. Önemli kararlar '
                    'vermeden önce haberin aslını kontrol edin.',
                    style: context.text.labelSmall?.copyWith(height: 1.45),
                  ),
                if (related.isNotEmpty) const SizedBox(height: Tp.section),
              ],
            ),
          ),
          if (related.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader(title: 'Bu konuda diğer haberler')),
            SliverList.separated(
              itemCount: related.length,
              itemBuilder: (context, i) => NewsRow(item: related[i]),
              separatorBuilder: (_, _) => const Divider(indent: Tp.page, endIndent: Tp.page),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }

  /// Ayrıntılı anlatımı henüz hazırlanmamış haber: kısa özet ve not.
  List<Widget> _fallback(BuildContext context, double scale) => [
    if (item.displaySummary case final summary?) ...[
      Text(summary, style: Tp.article(context, scale)),
      const SizedBox(height: 18),
    ],
    const _Note(
      icon: Icons.hourglass_top_rounded,
      text:
          'Bu haberin ayrıntılı Türkçe anlatımı hazırlanıyor; genellikle bir saat içinde eklenir. '
          'O zamana kadar kısa özeti okuyabilir veya haberin aslını açabilirsiniz.',
    ),
  ];

  /// Aynı konu etiketlerini taşıyan, yoksa aynı kategorideki son haberler.
  List<NewsItem> _related(List<NewsItem> all) {
    final topics = {for (final t in item.topics) foldForSearch(t)};
    final others = all.where((n) => n.id != item.id).toList();
    int shared(NewsItem n) => n.topics.where((t) => topics.contains(foldForSearch(t))).length;
    final byTopic = others.where((n) => shared(n) > 0).toList()..sort((a, b) => shared(b).compareTo(shared(a)));
    final picked = [...byTopic.take(3)];
    if (picked.length < 3) {
      picked.addAll(others.where((n) => n.category == item.category && !picked.contains(n)).take(3 - picked.length));
    }
    return picked;
  }
}

class _LevelToggle extends StatelessWidget {
  const _LevelToggle({required this.level, required this.onChanged});

  final ReadingLevel level;
  final ValueChanged<ReadingLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ReadingLevel>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ReadingLevel.simple,
                icon: Icon(Icons.spa_outlined, size: 18),
                label: Text('Sade anlatım'),
              ),
              ButtonSegment(
                value: ReadingLevel.technical,
                icon: Icon(Icons.bolt_rounded, size: 18),
                label: Text('Teknik derinlik'),
              ),
            ],
            selected: {level},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
        const SizedBox(height: 8),
        Text(level.description, style: context.text.labelSmall),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tp.surfaceAlt, borderRadius: BorderRadius.circular(Tp.radiusSmall)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tp.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: context.text.bodySmall?.copyWith(color: tp.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// Kaynak kutusu: haberin adresi (açmadan önce görülebilir), aç ve kopyala düğmeleri, varsa topluluk tartışması.
class _SourceBox extends StatelessWidget {
  const _SourceBox({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final discussion = item.discussionUrl;
    return TpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kaynak', style: context.text.labelMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              SourceAvatar(name: item.sourceName, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.sourceName, style: context.text.titleSmall),
                    Text(item.domain, style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinkPreviewLine(url: item.url),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => openLink(context, item.url),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Haberin aslını aç'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Bağlantıyı kopyala',
                onPressed: () => copyLink(context, item.url),
                style: IconButton.styleFrom(
                  side: BorderSide(color: tp.border),
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
            ],
          ),
          if (item.points != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.forum_outlined, size: 18, color: tp.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu haber, yazılımcıların bağlantı paylaşıp oyladığı Hacker News sitesinde '
                    '${item.points} puan${item.comments == null ? '' : ' ve ${item.comments} yorum'} aldı. '
                    'Puanlar TechPulse kullanıcılarından gelmez.',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
            if (discussion != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showLinkSheet(context, title: 'Hacker News tartışması', url: discussion),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text('Tartışmayı gör'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Yazı boyutu: A− / A / A+.
Future<void> showReadingSizeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final size = ref.watch(settingsProvider.select((s) => s.readingSize));
        final controller = ref.read(settingsProvider.notifier);
        final tp = context.tp;
        Widget button(String label, double fontSize, ReadingSize? target, String tooltip) => Expanded(
          child: Tooltip(
            message: tooltip,
            child: OutlinedButton(
              onPressed: target == null ? null : () => controller.setReadingSize(target),
              style: OutlinedButton.styleFrom(
                backgroundColor: target == size ? tp.accentSoft : null,
                side: BorderSide(color: target == size ? tp.accent : tp.border),
              ),
              child: Text(
                label,
                style: TextStyle(fontFamily: Tp.serif, fontSize: fontSize, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yazı boyutu', style: context.text.titleSmall),
                const SizedBox(height: 4),
                Text('${size.label} · bütün haberlerde geçerli', style: context.text.bodySmall),
                const SizedBox(height: 16),
                Row(
                  children: [
                    button('A−', 16, size == ReadingSize.small ? null : size.smaller, 'Küçült'),
                    const SizedBox(width: 10),
                    button('A', 20, ReadingSize.normal, 'Normal boyut'),
                    const SizedBox(width: 10),
                    button('A+', 24, size == ReadingSize.xlarge ? null : size.larger, 'Büyüt'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Örnek metin: Yeni sürüm, uygulamaların daha az bellekle daha hızlı açılmasını sağlıyor.',
                  style: Tp.article(context, size.scale),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
