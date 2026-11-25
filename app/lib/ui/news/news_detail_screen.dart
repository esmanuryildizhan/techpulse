import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = item.displaySummary;
    final translatedSummary = item.summaryTr != null;

    return Scaffold(
      appBar: AppBar(
        actions: [
          BookmarkButton(kind: BookmarkKind.news, entry: item),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Paylaş',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => shareLink(context, title: item.displayTitle, url: item.url),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CategoryPill(category: item.category),
                Pill(
                  label: item.sourceKind.label,
                  icon: item.sourceKind == SourceKind.official ? Icons.verified_outlined : Icons.public,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(item.displayTitle, style: theme.textTheme.headlineSmall),
            if (item.hasDifferentOriginal) ...[
              const SizedBox(height: 10),
              Text(
                item.titleOriginal,
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                SourceAvatar(id: item.sourceId, name: item.sourceName, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.sourceName, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        Fmt.longDate(item.publishedAt),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 36),
            if (summary != null)
              Text(summary, style: theme.textTheme.bodyLarge)
            else
              Text(
                item.points != null
                    ? 'Bu bağlantı Hacker News topluluğunda öne çıktı. Kaynak kısa açıklama yayımlamadığı için ayrıntılar kaynağında.'
                    : 'Kaynak bu haber için kısa açıklama yayımlamadı; ayrıntılar kaynağında.',
                style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in item.tags)
                    Pill(label: tag, color: categoryColor(item.category, theme.brightness)),
                ],
              ),
            ],
            if (item.points != null || item.comments != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (item.points != null)
                    Stat(icon: Icons.arrow_upward_rounded, value: '${Fmt.decimal(item.points!)} puan'),
                  const SizedBox(width: 16),
                  if (item.comments != null)
                    Stat(icon: Icons.chat_bubble_outline, value: '${Fmt.decimal(item.comments!)} yorum'),
                ],
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => openLink(context, item.url),
              icon: const Icon(Icons.open_in_new),
              label: Text('Kaynağında oku · ${item.sourceName}'),
            ),
            if (item.discussionUrl != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => openLink(context, item.discussionUrl!),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Hacker News tartışmasını aç'),
              ),
            ],
            const SizedBox(height: 24),
            InfoNote(
              icon: Icons.translate,
              text: translatedSummary
                  ? 'Türkçe başlık ve özet, ${item.sourceName} tarafından yayımlanan başlık ve kısa açıklamadan '
                      'yapay zekâ ile otomatik hazırlandı; küçük hatalar içerebilir. Haberin tamamı ve tüm hakları '
                      '${item.sourceName} kaynağına aittir.'
                  : item.translated
                      ? 'Türkçe başlık yapay zekâ ile otomatik çevrildi. Haberin tamamı ve tüm hakları ${item.sourceName} kaynağına aittir.'
                      : 'Bu haberin çevirisi henüz hazır değil; özgün başlık gösteriliyor. Haberin tüm hakları ${item.sourceName} kaynağına aittir.',
            ),
          ],
        ),
      ),
    );
  }
}
