import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../navigation.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/news_image.dart';

List<String> _meta(NewsItem item) => [item.sourceName, Fmt.relative(item.publishedAt), '${item.minutes} dk okuma'];

/// Günün manşeti: büyük görsel, başlık ve kısa özet.
class HeadlineCard extends ConsumerWidget {
  const HeadlineCard({super.key, required this.item, this.label = 'Günün manşeti'});

  final NewsItem item;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final read = ref.watch(isReadProvider(BookmarkRecord.keyFor(BookmarkKind.news, item.id)));
    return Pressable(
      onTap: () => openNews(context, item),
      onLongPress: () => showNewsActions(context, item),
      semanticLabel: '$label: ${item.displayTitle}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tp.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NewsImage(
                    url: item.imageUrl,
                    seed: item.id,
                    category: item.category,
                    label: item.sourceName,
                    borderRadius: BorderRadius.circular(Tp.radius),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: tp.accent, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        label,
                        style: context.text.labelSmall?.copyWith(
                          color: tp.onAccent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: BookmarkButton(kind: BookmarkKind.news, entry: item, onImage: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CategoryLabel(item.category),
            const SizedBox(height: 8),
            Text(
              item.displayTitle,
              style: Tp.headline(
                context,
                size: 23,
                weight: FontWeight.w700,
                height: 1.22,
              ).copyWith(color: read ? tp.textSecondary : tp.text),
            ),
            if (item.displaySummary case final summary?) ...[
              const SizedBox(height: 8),
              Text(
                summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(fontSize: 15),
              ),
            ],
            const SizedBox(height: 10),
            MetaLine(
              parts: _meta(item),
              leading: SourceAvatar(name: item.sourceName),
            ),
          ],
        ),
      ),
    );
  }
}

/// Akıştaki standart haber satırı: solda konu, başlık ve bilgi; sağda küçük görsel.
class NewsRow extends ConsumerWidget {
  const NewsRow({super.key, required this.item, this.showImage = true});

  final NewsItem item;
  final bool showImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final read = ref.watch(isReadProvider(BookmarkRecord.keyFor(BookmarkKind.news, item.id)));
    return InkWell(
      onTap: () => openNews(context, item),
      onLongPress: () => showNewsActions(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tp.page, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryLabel(item.category),
                  const SizedBox(height: 7),
                  Text(
                    item.displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Tp.headline(
                      context,
                      size: 16.5,
                      height: 1.3,
                    ).copyWith(color: read ? tp.textSecondary : tp.text),
                  ),
                  const SizedBox(height: 8),
                  MetaLine(parts: [item.sourceName, Fmt.relative(item.publishedAt), '${item.minutes} dk']),
                ],
              ),
            ),
            if (showImage) ...[
              const SizedBox(width: 14),
              SizedBox.square(
                dimension: 88,
                child: NewsImage(
                  url: item.imageUrl,
                  seed: item.id,
                  category: item.category,
                  borderRadius: BorderRadius.circular(Tp.radiusSmall),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yatay "Kısaca" şeridindeki kart.
class BriefCard extends StatelessWidget {
  const BriefCard({super.key, required this.item, this.width = 248});

  final NewsItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TpCard(
        onTap: () => openNews(context, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: NewsImage(url: item.imageUrl, seed: item.id, category: item.category, label: item.sourceName),
            ),
            // Kart, şeridin yüksekliğini doldurur; uzun başlık taşmak yerine kısalır.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryLabel(item.category),
                    const SizedBox(height: 7),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          item.displayTitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Tp.headline(context, size: 15.5, height: 1.3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    MetaLine(parts: [item.sourceName, Fmt.relative(item.publishedAt)]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sıra numaralı haber satırı (Keşfet → Popüler).
class RankedNewsRow extends StatelessWidget {
  const RankedNewsRow({super.key, required this.rank, required this.item});

  final int rank;
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final community = item.communityLabel;
    return InkWell(
      onTap: () => openNews(context, item),
      onLongPress: () => showNewsActions(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tp.page, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontFamily: Tp.serif,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: tp.accent,
                  height: 1.05,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Tp.headline(context, size: 16, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  MetaLine(parts: [item.category.shortLabel, item.sourceName, Fmt.relative(item.publishedAt)]),
                  if (community != null) ...[
                    const SizedBox(height: 4),
                    Text(community, style: context.text.labelSmall?.copyWith(color: tp.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox.square(
              dimension: 60,
              child: NewsImage(
                url: item.imageUrl,
                seed: item.id,
                category: item.category,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uzun basınca açılan haber eylemleri.
Future<void> showNewsActions(BuildContext context, NewsItem item) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) {
        final key = BookmarkRecord.keyFor(BookmarkKind.news, item.id);
        final saved = ref.watch(isBookmarkedProvider(key));
        void close() => Navigator.of(sheetContext).pop();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 8),
                child: Text(
                  item.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Tp.headline(sheetContext, size: 16),
                ),
              ),
              ListTile(
                leading: Icon(saved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
                title: Text(saved ? 'Kaydedilenlerden çıkar' : 'Kaydet'),
                onTap: () {
                  close();
                  ref.read(bookmarksProvider.notifier).toggle(BookmarkKind.news, item);
                  showMessage(context, saved ? 'Kaydedilenlerden çıkarıldı.' : 'Kaydedilenlere eklendi.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Paylaş'),
                onTap: () {
                  close();
                  shareLink(context, title: item.displayTitle, url: item.url);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Haberin bağlantısını kopyala'),
                subtitle: Text(Fmt.prettyUrl(item.url, max: 48), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  close();
                  copyLink(context, item.url);
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: Text('${item.sourceName} sitesinde aç'),
                onTap: () {
                  close();
                  openLink(context, item.url);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}
