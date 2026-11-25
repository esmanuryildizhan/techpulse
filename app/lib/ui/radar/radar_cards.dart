import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/news_image.dart';

/// Model türlerinin rengi.
Color modalityColor(Modality modality, Brightness brightness) => switch (modality) {
      Modality.text => TechCategory.dev.tone(brightness),
      Modality.vision => TechCategory.science.tone(brightness),
      Modality.audio => TechCategory.hardware.tone(brightness),
      Modality.multimodal => TechCategory.ai.tone(brightness),
      Modality.other => TechCategory.industry.tone(brightness),
    };

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.text, {this.tooltip});

  final IconData icon;
  final String text;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.tp.textMuted),
        const SizedBox(width: 4),
        Text(text, style: context.text.bodySmall?.copyWith(color: context.tp.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
    return tooltip == null ? row : Tooltip(message: tooltip, child: row);
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color, {this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modeller
// ---------------------------------------------------------------------------

class ModelCard extends StatelessWidget {
  const ModelCard({super.key, required this.model});

  final AiModel model;

  @override
  Widget build(BuildContext context) {
    final tone = modalityColor(model.modality, context.brightness);
    return TpCard(
      onTap: () => showModelSheet(context, model),
      semanticLabel: '${model.rank}. ${model.name}',
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tone.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
                child: Text('${model.rank}', style: context.text.titleMedium?.copyWith(color: tone, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(fontFamily: Tp.monoFont, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      [model.author, if (model.createdAt != null) Fmt.relative(model.createdAt!)].join(' · '),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              BookmarkButton(kind: BookmarkKind.model, entry: model, size: 21),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(model.task, tone, icon: model.modality.icon),
              if (model.isNew()) _Pill('Yeni', context.tp.success),
            ],
          ),
          if (model.summaryTr != null) ...[
            const SizedBox(height: 10),
            Text(model.summaryTr!, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Stat(Icons.favorite_border_rounded, Fmt.compact(model.likes), tooltip: 'Beğeni'),
              _Stat(Icons.download_rounded, Fmt.compact(model.downloads), tooltip: 'İndirme'),
              if (model.parameters != null) _Stat(Icons.memory_rounded, '${Fmt.parameters(model.parameters!)} parametre'),
            ],
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
    builder: (context) {
      final tone = modalityColor(model.modality, context.brightness);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 32),
          children: [
            Text(model.author, style: context.text.bodySmall),
            const SizedBox(height: 4),
            Text(model.name, style: context.text.headlineSmall?.copyWith(fontFamily: Tp.monoFont, fontSize: 22)),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [_Pill(model.task, tone, icon: model.modality.icon), _Pill('Trend sırası ${model.rank}', context.tp.primary)]),
            const SizedBox(height: 18),
            if (model.summaryTr != null) Text(model.summaryTr!, style: context.text.bodyLarge),
            if (model.highlights.isNotEmpty) ...[
              const SizedBox(height: 18),
              InfoBox(
                icon: Icons.star_outline_rounded,
                title: 'Öne çıkan özellikler',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final h in model.highlights)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_rounded, size: 16, color: context.tp.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(h, style: context.text.bodyMedium?.copyWith(color: context.tp.textPrimary))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            TpCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row(context, 'Beğeni', Fmt.decimal(model.likes)),
                  _row(context, 'İndirme (son 30 gün)', Fmt.decimal(model.downloads)),
                  if (model.parameters != null) _row(context, 'Parametre', Fmt.parameters(model.parameters!)),
                  if (model.license != null) _row(context, 'Lisans', model.license!),
                  if (model.library != null) _row(context, 'Kütüphane', model.library!),
                  if (model.createdAt != null) _row(context, 'Yayın', Fmt.date(model.createdAt!)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => openLink(context, model.url),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text("Hugging Face'te aç"),
            ),
            const SizedBox(height: 8),
            Text(
              model.summaryTr == null ? 'Model kartında açıklama bulunmuyor.' : 'Açıklama, model kartından yapay zekâ desteğiyle Türkçe hazırlandı.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ],
        ),
      );
    },
  );
}

Widget _row(BuildContext context, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: context.text.titleSmall)),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// Makaleler
// ---------------------------------------------------------------------------

void openPaper(BuildContext context, WidgetRef ref, Paper paper) {
  unawaited(ref.read(historyProvider.notifier).add(BookmarkKind.paper, paper));
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PaperDetailScreen(paper: paper)));
}

class PaperCard extends ConsumerWidget {
  const PaperCard({super.key, required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TpCard(
      onTap: () => openPaper(context, ref, paper),
      semanticLabel: paper.displayTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2.2,
            child: NewsImage(url: paper.imageUrl, seed: paper.id, category: TechCategory.ai, icon: Icons.article_outlined, label: 'arXiv ${paper.id}'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(trUpper('Günün makalesi · ${paper.upvotes} oy'), style: context.text.labelSmall?.copyWith(color: TechCategory.data.tone(context.brightness)))),
                    BookmarkButton(kind: BookmarkKind.paper, entry: paper, size: 21),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(paper.displayTitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                      if (paper.summaryTr != null) ...[
                        const SizedBox(height: 8),
                        Text(paper.summaryTr!, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        [if (paper.authorLine.isNotEmpty) paper.authorLine, Fmt.shortDate(paper.publishedAt)].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PaperDetailScreen extends StatelessWidget {
  const PaperDetailScreen({super.key, required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context) {
    final article = paper.article;
    final body = context.text.bodyLarge?.copyWith(fontSize: 16.5, height: 1.7);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Makale'),
        actions: [
          FavoriteButton(kind: BookmarkKind.paper, entry: paper),
          BookmarkButton(kind: BookmarkKind.paper, entry: paper),
          Builder(
            builder: (c) => IconButton(
              tooltip: 'Paylaş',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => shareLink(c, title: paper.displayTitle, url: paper.url),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tp.page, 4, Tp.page, 40),
        children: [
          SizedBox(
            height: 180,
            child: NewsImage(
              url: paper.imageUrl,
              seed: paper.id,
              category: TechCategory.ai,
              icon: Icons.article_outlined,
              borderRadius: BorderRadius.circular(Tp.radius),
            ),
          ),
          const SizedBox(height: 18),
          Text(trUpper('Günün makalesi · ${paper.upvotes} oy'), style: context.text.labelSmall?.copyWith(color: TechCategory.data.tone(context.brightness))),
          const SizedBox(height: 8),
          Text(paper.displayTitle, style: context.text.headlineSmall),
          if (paper.titleTr != null && paper.titleTr != paper.titleOriginal) ...[
            const SizedBox(height: 8),
            Text(paper.titleOriginal, style: context.text.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          Text([if (paper.authors.isNotEmpty) paper.authors.join(', '), Fmt.date(paper.publishedAt)].join(' · '), style: context.text.bodySmall),
          const SizedBox(height: 20),
          if (article != null) ...[
            Text(article.intro, style: body?.copyWith(fontWeight: FontWeight.w500, fontSize: 17)),
            if (article.primer.isNotEmpty) ...[
              const SizedBox(height: 20),
              InfoBox(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Önce bunu bil',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in article.primer) ...[
                      Text(p.term, style: context.text.titleSmall),
                      const SizedBox(height: 4),
                      Text(p.explanation, style: context.text.bodyMedium),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
            for (final section in article.sections) ...[
              const SizedBox(height: 24),
              Text(section.heading, style: context.text.titleLarge),
              for (final paragraph in section.paragraphs) ...[const SizedBox(height: 10), Text(paragraph, style: body)],
            ],
          ] else ...[
            if (paper.summaryTr != null) Text(paper.summaryTr!, style: body),
            const SizedBox(height: 16),
            Text('Özet (İngilizce)', style: context.text.titleSmall),
            const SizedBox(height: 8),
            Text(paper.abstractOriginal, style: context.text.bodyMedium),
          ],
          const SizedBox(height: 24),
          Text(
            'Türkçe anlatım, makalenin özetinden yapay zekâ desteğiyle hazırlanmıştır. Ayrıntılar için makalenin kendisine başvurun.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openLink(context, paper.arxivUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text("Makaleyi arXiv'de oku"),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => openLink(context, paper.url),
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: const Text("Hugging Face'teki tartışma"),
          ),
          if (paper.githubUrl != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => openLink(context, paper.githubUrl!),
              icon: const Icon(Icons.code_rounded, size: 18),
              label: const Text('Kod deposu'),
            ),
          ],
        ],
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
    return TpCard(
      onTap: () => openLink(context, repo.url),
      semanticLabel: repo.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2,
            child: NewsImage(url: repo.imageUrl, seed: repo.id, category: TechCategory.dev, icon: Icons.code_rounded, label: repo.id),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(repo.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontFamily: Tp.monoFont)),
                    ),
                    BookmarkButton(kind: BookmarkKind.repo, entry: repo, size: 21),
                  ],
                ),
                if (repo.description != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(repo.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _Stat(Icons.star_border_rounded, Fmt.compact(repo.stars), tooltip: 'Yıldız'),
                    _Stat(Icons.call_split_rounded, Fmt.compact(repo.forks), tooltip: 'Çatal'),
                    if (repo.language != null) _Stat(Icons.code_rounded, repo.language!),
                    _Stat(Icons.schedule_rounded, Fmt.relative(repo.createdAt), tooltip: 'Oluşturulma'),
                    if (repo.isAi) _Pill('Yapay zekâ', TechCategory.ai.tone(context.brightness)),
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
