import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import 'news_detail_screen.dart';

void openNews(BuildContext context, NewsItem item) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NewsDetailScreen(item: item)));
}

/// Kaynak satırı: rozet, kaynak adı, türü ve yayın zamanı.
class SourceLine extends StatelessWidget {
  const SourceLine({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        SourceAvatar(id: item.sourceId, name: item.sourceName, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            item.sourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
          ),
        ),
        if (item.sourceKind == SourceKind.official) ...[
          const SizedBox(width: 4),
          Tooltip(message: 'Resmî kaynak', child: Icon(Icons.verified, size: 14, color: theme.colorScheme.primary)),
        ],
        const SizedBox(width: 6),
        Text('· ${Fmt.relative(item.publishedAt)}', style: theme.textTheme.labelMedium?.copyWith(color: muted)),
      ],
    );
  }
}

class NewsCard extends ConsumerWidget {
  const NewsCard({super.key, required this.item, this.featured = false});

  final NewsItem item;
  final bool featured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showOriginal = ref.watch(settingsProvider.select((s) => s.showOriginalTitles));
    final accent = categoryColor(item.category, theme.brightness);
    final summary = item.displaySummary;

    return SurfaceCard(
      onTap: () => openNews(context, item),
      gradient: featured
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withValues(alpha: 0.16), scheme.surfaceContainerLow],
            )
          : null,
      padding: EdgeInsets.fromLTRB(16, featured ? 18 : 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (featured) ...[
                  Pill(label: 'Öne çıkan', icon: Icons.trending_up, color: accent, filled: true),
                  const SizedBox(height: 12),
                ],
                SourceLine(item: item),
                const SizedBox(height: 10),
                Text(
                  item.displayTitle,
                  maxLines: featured ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: (featured ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)?.copyWith(height: 1.3),
                ),
                if (showOriginal && item.hasDifferentOriginal) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.titleOriginal,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant),
                  ),
                ],
                if (summary != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    maxLines: featured ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CategoryPill(category: item.category),
              if (item.points != null) ...[
                const SizedBox(width: 12),
                Stat(icon: Icons.arrow_upward_rounded, value: Fmt.compact(item.points!), semanticsLabel: '${item.points} puan'),
              ],
              if (item.comments != null) ...[
                const SizedBox(width: 10),
                Stat(icon: Icons.chat_bubble_outline, value: Fmt.compact(item.comments!), semanticsLabel: '${item.comments} yorum'),
              ],
              const Spacer(),
              BookmarkButton(kind: BookmarkKind.news, entry: item, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}
