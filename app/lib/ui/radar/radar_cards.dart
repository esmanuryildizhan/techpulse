import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import 'paper_detail_screen.dart';

// ---------------------------------------------------------------------------
// Modeller
// ---------------------------------------------------------------------------

class ModelCard extends StatelessWidget {
  const ModelCard({super.key, required this.model});

  final AiModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = modalityColor(model.modality, theme.brightness);
    return SurfaceCard(
      onTap: () => showModelSheet(context, model),
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${model.rank}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: model.rank <= 3 ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SourceAvatar(id: model.author, name: model.author, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        model.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    if (model.isNew()) ...[
                      const SizedBox(width: 6),
                      Pill(label: 'Yeni', color: scheme.primary, filled: true),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  model.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontFamily: AppTheme.monoFont, fontSize: 15.5),
                ),
                const SizedBox(height: 8),
                Pill(label: model.task, icon: model.modality.icon, color: color),
                if (model.summaryTr != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    model.summaryTr!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Stat(
                            icon: Icons.favorite_border,
                            value: Fmt.compact(model.likes),
                            semanticsLabel: '${model.likes} beğeni',
                          ),
                          Stat(
                            icon: Icons.download_outlined,
                            value: Fmt.compact(model.downloads),
                            semanticsLabel: '${model.downloads} indirme',
                          ),
                          if (model.parameters != null)
                            Stat(icon: Icons.memory, value: Fmt.parameters(model.parameters!), semanticsLabel: 'parametre'),
                        ],
                      ),
                    ),
                    BookmarkButton(kind: BookmarkKind.model, entry: model, compact: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showModelSheet(BuildContext context, AiModel model) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _ModelSheet(model: model),
  );
}

class _ModelSheet extends StatelessWidget {
  const _ModelSheet({required this.model});

  final AiModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = modalityColor(model.modality, theme.brightness);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(model.author, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(model.name, style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppTheme.monoFont, fontSize: 22)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(label: model.task, icon: model.modality.icon, color: color),
              Pill(label: 'Trend #${model.rank}', icon: Icons.trending_up, color: scheme.primary),
              if (model.isNew()) Pill(label: 'Son 2 haftada yayımlandı', color: scheme.tertiary),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            model.summaryTr ?? 'Bu model için Türkçe özet henüz hazırlanmadı. Ayrıntılar Hugging Face sayfasındaki model kartında.',
            style: theme.textTheme.bodyLarge?.copyWith(color: model.summaryTr == null ? scheme.onSurfaceVariant : null),
          ),
          const SizedBox(height: 16),
          _FactGrid(
            facts: [
              ('Beğeni', Fmt.decimal(model.likes)),
              ('İndirme (30 gün)', Fmt.decimal(model.downloads)),
              if (model.parameters != null) ('Parametre', Fmt.parameters(model.parameters!)),
              if (model.createdAt != null) ('Yayımlanma', Fmt.date(model.createdAt!)),
              if (model.library != null) ('Kütüphane', model.library!),
              if (model.license != null) ('Lisans', model.license!),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: () => openLink(context, model.url),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Hugging Face'te aç"),
                ),
              ),
              const SizedBox(width: 8),
              BookmarkButton(kind: BookmarkKind.model, entry: model),
            ],
          ),
          const SizedBox(height: 12),
          if (model.summaryTr != null)
            const InfoNote(
              icon: Icons.translate,
              text: 'Açıklama, model kartının ilk cümlelerinin makine çevirisidir (açık kaynaklı OPUS-MT modeli).',
            ),
        ],
      ),
    );
  }
}

class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, value) in facts)
              Container(
                width: width,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Makaleler
// ---------------------------------------------------------------------------

class PaperCard extends ConsumerWidget {
  const PaperCard({super.key, required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showOriginal = ref.watch(settingsProvider.select((s) => s.showOriginalTitles));
    return SurfaceCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PaperDetailScreen(paper: paper))),
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UpvoteBox(count: paper.upvotes),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paper.displayTitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (showOriginal && paper.titleTr != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    paper.titleOriginal,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant),
                  ),
                ],
                if (paper.summaryTr != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    paper.summaryTr!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 8),
                if (paper.tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in paper.tags.take(3))
                        Pill(label: tag, color: categoryColor(NewsCategory.ai, theme.brightness)),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [Fmt.shortDate(paper.publishedAt), if (paper.authorLine.isNotEmpty) paper.authorLine].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    BookmarkButton(kind: BookmarkKind.paper, entry: paper, compact: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpvoteBox extends StatelessWidget {
  const _UpvoteBox({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$count oy',
      excludeSemantics: true,
      child: Container(
        width: 48,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(Icons.arrow_drop_up_rounded, size: 24, color: scheme.onPrimaryContainer),
            Text(
              Fmt.compact(count),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: scheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Projeler
// ---------------------------------------------------------------------------

class RepoCard extends StatelessWidget {
  const RepoCard({super.key, required this.repo});

  final Repo repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = repo.description;
    return SurfaceCard(
      onTap: () => openLink(context, repo.url),
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              children: [
                SourceAvatar(id: repo.owner, name: repo.owner, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${repo.owner} / ', style: TextStyle(color: scheme.onSurfaceVariant)),
                        TextSpan(text: repo.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontFamily: AppTheme.monoFont),
                  ),
                ),
                if (repo.isAi) Pill(label: 'YZ', icon: Icons.auto_awesome, color: categoryColor(NewsCategory.ai, theme.brightness)),
              ],
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              if (repo.language != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: sourceColor(repo.language!, theme.brightness), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(repo.language!, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(width: 12),
              ],
              Stat(icon: Icons.star_border_rounded, value: Fmt.compact(repo.stars), semanticsLabel: '${repo.stars} yıldız'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${Fmt.relative(repo.createdAt)} açıldı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              BookmarkButton(kind: BookmarkKind.repo, entry: repo, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}
