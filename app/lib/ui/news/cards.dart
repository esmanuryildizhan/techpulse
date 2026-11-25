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
import 'news_detail_screen.dart';

/// Kaynağın orijinal başlığı (Ayarlar'da açıksa Türkçe başlığın altında gösterilir).
class _OriginalTitle extends ConsumerWidget {
  const _OriginalTitle(this.item);

  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(settingsProvider.select((s) => s.showOriginalTitles));
    if (!show || !item.hasDifferentOriginal) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        item.titleOriginal,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

/// Ana sayfanın en dikkat çekici kartı: geniş görsel, görsel üzerinde konu etiketi ve kaydet düğmesi,
/// altında başlık, spot ve kaynak bilgisi.
class FeaturedNewsCard extends ConsumerWidget {
  const FeaturedNewsCard({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = item.displaySummary;
    return TpCard(
      onTap: () => openNews(context, ref, item),
      semanticLabel: item.displayTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NewsImage(url: item.imageUrl, seed: item.id, category: item.category, label: item.sourceName),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x330B0D17), Color(0x000B0D17), Color(0x660B0D17)],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
                Positioned(left: 12, top: 12, child: CategoryOverlayPill(item.category)),
                Positioned(right: 10, top: 10, child: BookmarkButton(kind: BookmarkKind.news, entry: item, onImage: true)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayTitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.titleLarge?.copyWith(fontSize: 20)),
                _OriginalTitle(item),
                if (summary != null) ...[
                  const SizedBox(height: 10),
                  Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                ],
                const SizedBox(height: 14),
                MetaLine(source: item.sourceName, time: Fmt.relative(item.publishedAt), minutes: item.readingMinutes),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// İki sütunlu küçük kart ("Öne Çıkanlar"): görsel, konu, kısa başlık, kaynak ve zaman.
class GridNewsCard extends ConsumerWidget {
  const GridNewsCard({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TpCard(
      onTap: () => openNews(context, ref, item),
      semanticLabel: item.displayTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: NewsImage(url: item.imageUrl, seed: item.id, category: item.category),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryKicker(item.category),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      item.displayTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.sourceName} · ${Fmt.relative(item.publishedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste kartı ("Son Gelişmeler"): solda görsel; sağda konu, başlık, kısa spot ve kaynak.
class ListNewsCard extends ConsumerWidget {
  const ListNewsCard({super.key, required this.item, this.showSummary = true, this.trailingNote});

  final NewsItem item;
  final bool showSummary;

  /// Kaynak satırının yerine gösterilecek not (ör. "Kaydedildi: dün").
  final String? trailingNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = item.displaySummary;
    final read = ref.watch(isReadProvider(BookmarkRecord.keyFor(BookmarkKind.news, item.id)));
    return Pressable(
      onTap: () => openNews(context, ref, item),
      borderRadius: Tp.radiusSmall,
      semanticLabel: item.displayTitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tp.page, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: NewsImage(
                url: item.imageUrl,
                seed: item.id,
                category: item.category,
                borderRadius: BorderRadius.circular(Tp.radiusSmall),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryKicker(item.category),
                  const SizedBox(height: 6),
                  Text(
                    item.displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium?.copyWith(
                      fontSize: 15.5,
                      color: read ? context.tp.textSecondary : context.tp.textPrimary,
                    ),
                  ),
                  if (showSummary && summary != null) ...[
                    const SizedBox(height: 6),
                    Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontSize: 13.5)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trailingNote ?? '${item.sourceName} · ${Fmt.relative(item.publishedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall,
                        ),
                      ),
                      BookmarkButton(kind: BookmarkKind.news, entry: item, size: 21),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
