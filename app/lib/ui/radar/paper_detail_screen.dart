import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';

class PaperDetailScreen extends StatelessWidget {
  const PaperDetailScreen({super.key, required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final aiColor = categoryColor(NewsCategory.ai, theme.brightness);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Makale'),
        actions: [
          BookmarkButton(kind: BookmarkKind.paper, entry: paper),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Paylaş',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => shareLink(context, title: paper.displayTitle, url: paper.url),
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
                Pill(label: '${Fmt.decimal(paper.upvotes)} oy', icon: Icons.arrow_upward_rounded, color: scheme.primary, filled: true),
                Pill(label: Fmt.date(paper.publishedAt), icon: Icons.event_outlined, color: scheme.onSurfaceVariant),
                if (paper.comments > 0)
                  Pill(label: '${paper.comments} yorum', icon: Icons.chat_bubble_outline, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 16),
            Text(paper.displayTitle, style: theme.textTheme.headlineSmall),
            if (paper.titleTr != null) ...[
              const SizedBox(height: 10),
              Text(
                paper.titleOriginal,
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant),
              ),
            ],
            if (paper.authors.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.people_outline, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      paper.authors.join(', '),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 36),
            const SectionLabel('Türkçe özet', padding: EdgeInsets.zero),
            const SizedBox(height: 8),
            Text(
              paper.summaryTr ?? 'Bu makalenin Türkçe özeti henüz hazırlanmadı. Aşağıda özgün özeti okuyabilirsiniz.',
              style: theme.textTheme.bodyLarge?.copyWith(color: paper.summaryTr == null ? scheme.onSurfaceVariant : null),
            ),
            if (paper.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final t in paper.tags) Pill(label: t, color: aiColor)]),
            ],
            if (paper.abstractOriginal.isNotEmpty) ...[
              const SizedBox(height: 12),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text('Özgün özet (İngilizce)', style: theme.textTheme.titleSmall),
                  children: [
                    Text(
                      paper.abstractOriginal,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => openLink(context, paper.url),
              icon: const Icon(Icons.open_in_new),
              label: const Text("Hugging Face'te aç"),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => openLink(context, paper.arxivUrl),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('arXiv'),
                  ),
                ),
                if (paper.githubUrl != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => openLink(context, paper.githubUrl!),
                      icon: const Icon(Icons.code),
                      label: const Text('Kod'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            const InfoNote(
              icon: Icons.translate,
              text: 'Türkçe başlık ve özet, makalenin özgün başlığının ve özetinin ilk cümlelerinin makine çevirisidir '
                  '(açık kaynaklı OPUS-MT modeli). Makalenin tüm hakları yazarlarına aittir.',
            ),
          ],
        ),
      ),
    );
  }
}
