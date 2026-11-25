import 'dart:async';

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
import 'news_list_screen.dart';

/// Haberi açar ve okuma geçmişine ekler.
void openNews(BuildContext context, WidgetRef ref, NewsItem item) {
  unawaited(ref.read(historyProvider.notifier).add(BookmarkKind.news, item));
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NewsDetailScreen(item: item)));
}

/// Haber ayrıntısı: büyük görsel, başlık, kaynak bilgileri, giriş, "Önce bunu bil", bölümlü anlatım
/// ve kaynağa yönlendirme. Metin, kaynak haberden yapay zekâ editörünce özgün olarak yazılmıştır.
class NewsDetailScreen extends ConsumerWidget {
  const NewsDetailScreen({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final article = item.article;
    final showOriginal = ref.watch(settingsProvider.select((s) => s.showOriginalTitles));
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: tp.background,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            toolbarHeight: 64,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  OverlayIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Geri', onPressed: () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  FavoriteButton(kind: BookmarkKind.news, entry: item, onImage: true),
                  const SizedBox(width: 8),
                  BookmarkButton(kind: BookmarkKind.news, entry: item, onImage: true),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (buttonContext) => OverlayIconButton(
                      icon: Icons.ios_share_rounded,
                      tooltip: 'Paylaş',
                      onPressed: () => shareLink(buttonContext, title: item.displayTitle, url: item.url),
                    ),
                  ),
                ],
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  NewsImage(url: item.imageUrl, seed: item.id, category: item.category, label: item.sourceName),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [const Color(0x660B0D17), const Color(0x000B0D17), tp.background.withValues(alpha: 0.85)],
                        stops: const [0, 0.5, 1],
                      ),
                    ),
                  ),
                  SizedBox(height: topPadding),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 40),
            sliver: SliverList.list(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CategoryBadge(
                    item.category,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => NewsListScreen.category(item.category)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(header: true, child: Text(item.displayTitle, style: context.text.headlineSmall?.copyWith(fontSize: 24))),
                if (showOriginal && item.hasDifferentOriginal) ...[
                  const SizedBox(height: 8),
                  Text(item.titleOriginal, style: context.text.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 16),
                _Meta(item: item),
                const SizedBox(height: 20),
                Divider(color: tp.border),
                const SizedBox(height: 20),
                if (article != null) ..._articleBody(context, article) else ..._fallbackBody(context),
                if (item.topics.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Konular', style: context.text.labelMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final topic in item.topics)
                        ActionChip(
                          label: Text(topic),
                          avatar: Icon(Icons.tag_rounded, size: 16, color: tp.textMuted),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => NewsListScreen.topic(topic)),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                _SourceBox(item: item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _articleBody(BuildContext context, Article article) {
    final body = context.text.bodyLarge?.copyWith(fontSize: 16.5, height: 1.7);
    return [
      Text(article.intro, style: body?.copyWith(fontSize: 17.5, fontWeight: FontWeight.w500, height: 1.6)),
      if (article.primer.isNotEmpty) ...[
        const SizedBox(height: 24),
        InfoBox(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Önce bunu bil',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, primer) in article.primer.indexed) ...[
                if (index > 0) const SizedBox(height: 12),
                Text(primer.term, style: context.text.titleSmall),
                const SizedBox(height: 4),
                Text(primer.explanation, style: context.text.bodyMedium?.copyWith(color: context.tp.textPrimary.withValues(alpha: 0.86))),
              ],
            ],
          ),
        ),
      ],
      for (final section in article.sections) ...[
        const SizedBox(height: 28),
        Semantics(header: true, child: Text(section.heading, style: context.text.titleLarge)),
        for (final paragraph in section.paragraphs) ...[
          const SizedBox(height: 12),
          Text(paragraph, style: body),
        ],
      ],
    ];
  }

  /// Yapay zekâ editörünün henüz yazmadığı haber: kaynağın kısa açıklaması ve dürüst bir not.
  List<Widget> _fallbackBody(BuildContext context) {
    final summary = item.displaySummary;
    return [
      if (summary != null) Text(summary, style: context.text.bodyLarge?.copyWith(fontSize: 17, height: 1.65)),
      const SizedBox(height: 20),
      InfoBox(
        icon: Icons.hourglass_top_rounded,
        title: 'Ayrıntılı anlatım hazırlanıyor',
        tone: context.tp.secondary,
        child: Text(
          item.translated
              ? 'Bu haberin başlığı ve özeti makine çevirisidir. Ayrıntılı Türkçe anlatımı editörümüz bir sonraki güncellemede ekleyecek.'
              : 'Bu haber kaynağa yeni eklendi; Türkçe anlatımı bir sonraki güncellemede hazır olacak. O zamana kadar kaynağın kendi açıklaması gösteriliyor.',
          style: context.text.bodyMedium,
        ),
      ),
    ];
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodySmall;
    return Row(
      children: [
        SourceAvatar(name: item.sourceName, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.sourceName, style: context.text.titleSmall),
              const SizedBox(height: 2),
              Text(
                [
                  Fmt.longDate(item.publishedAt),
                  if (item.readingMinutes != null) '${item.readingMinutes} dk okuma',
                  item.category.shortLabel,
                ].join('  ·  '),
                style: style,
              ),
            ],
          ),
        ),
        if (item.points != null)
          Tooltip(
            message: 'Hacker News puanı ve yorum sayısı',
            child: Row(
              children: [
                Icon(Icons.arrow_upward_rounded, size: 16, color: context.tp.textMuted),
                Text(' ${Fmt.compact(item.points!)}', style: style),
                const SizedBox(width: 8),
                Icon(Icons.mode_comment_outlined, size: 15, color: context.tp.textMuted),
                Text(' ${Fmt.compact(item.comments ?? 0)}', style: style),
              ],
            ),
          ),
      ],
    );
  }
}

/// Kaynak bilgisi ve orijinal habere yönlendirme.
class _SourceBox extends StatelessWidget {
  const _SourceBox({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final how = item.aiWritten
        ? 'Bu haber, ${item.sourceName} tarafından ${Fmt.date(item.publishedAt)} tarihinde yayımlanan içerik temel alınarak TechPulse editörü tarafından yapay zekâ desteğiyle Türkçe hazırlanmıştır.'
        : 'Bu haberin kaynağı ${item.sourceName} (${Fmt.date(item.publishedAt)}). Türkçe metin makine çevirisidir ve hata içerebilir.';
    return TpCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SourceAvatar(name: item.sourceName, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text('Kaynak: ${item.sourceName}', style: context.text.titleSmall)),
            ],
          ),
          const SizedBox(height: 12),
          Text(how, style: context.text.bodyMedium),
          const SizedBox(height: 6),
          Text('Haberin tüm hakları kaynağına aittir.', style: context.text.bodySmall),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => openLink(context, item.url),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Orijinal haberi kaynağından incele'),
            ),
          ),
          if (item.discussionUrl != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => openLink(context, item.discussionUrl!),
                icon: Icon(Icons.forum_outlined, size: 18, color: tp.textSecondary),
                label: const Text('Hacker News tartışmasını aç'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
