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
import 'story_reader.dart';

/// Haber ayrıntısı: başlık, "30 saniyede oku", sade veya teknik anlatım, kavramlar, kaynak ve ilgili haberler.
class NewsDetailScreen extends ConsumerWidget {
  const NewsDetailScreen({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final settings = ref.watch(settingsProvider);
    final scale = settings.readingSize.scale;
    final story = item.story;
    final related = _related(ref.watch(visibleNewsProvider));

    return StoryReader(
      kind: BookmarkKind.news,
      entry: item,
      title: item.displayTitle,
      story: story,
      glossaryTitle: 'Bu haberdeki kavramlar',
      excerptNote:
          '${item.sourceName} bu haberin yalnızca kısa bir bölümünü yayımlıyor; olaya ait bilgiler bu bölüme dayanıyor. '
          'Ayrıntılar için haberin aslına bakabilirsiniz.',
      header: [
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
            style: Tp.headline(context, size: 26 * scale.clamp(0.9, 1.15), weight: FontWeight.w700, height: 1.2),
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
          parts: [item.sourceName, Fmt.longDate(item.publishedAt)],
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
      ],
      fallback: [
        if (item.displaySummary case final summary?) ...[
          Text(summary, style: Tp.article(context, scale)),
          const SizedBox(height: 18),
        ],
        const ReaderNote(
          icon: Icons.hourglass_top_rounded,
          text:
              'Bu haberin ayrıntılı Türkçe anlatımı hazırlanıyor; genellikle bir saat içinde eklenir. '
              'O zamana kadar kısa özeti okuyabilir veya haberin aslını açabilirsiniz.',
        ),
      ],
      footer: [
        _SourceBox(item: item),
        const SizedBox(height: 14),
        if (item.aiWritten)
          Text(
            'Bu yazı, kaynak haberden yapay zekâ desteğiyle Türkçe olarak hazırlandı. Olaya ait bilgiler kaynaktan, '
            'kavram ve arka plan açıklamaları genel bilgiden gelir. Önemli kararlar vermeden önce haberin aslını kontrol edin.',
            style: context.text.labelSmall?.copyWith(height: 1.45),
          ),
      ],
      trailing: [
        if (related.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: Tp.section)),
          const SliverToBoxAdapter(child: SectionHeader(title: 'Bu konuda diğer haberler')),
          SliverList.separated(
            itemCount: related.length,
            itemBuilder: (context, i) => NewsRow(item: related[i]),
            separatorBuilder: (_, _) => const Divider(indent: Tp.page, endIndent: Tp.page),
          ),
        ],
      ],
    );
  }

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
