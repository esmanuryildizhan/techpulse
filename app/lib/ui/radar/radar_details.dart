import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../news/story_reader.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';

/// Radar ayrıntı ekranlarının ortak iskeleti: üst çubukta kaydet ve paylaş, altta bağlantı kutusu.
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.kind,
    required this.entry,
    required this.shareTitle,
    required this.children,
  });

  final BookmarkKind kind;
  final Entry entry;
  final String shareTitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          BookmarkButton(kind: kind, entry: entry),
          IconButton(
            tooltip: 'Paylaş',
            onPressed: () => shareLink(context, title: shareTitle, url: entry.url),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Tp.page, 4, Tp.page, 32 + MediaQuery.paddingOf(context).bottom),
        children: children,
      ),
    );
  }
}

/// Bağlantı kutusu: adres açılmadan önce görülür; aç ve kopyala.
class LinkBox extends StatelessWidget {
  const LinkBox({super.key, required this.title, required this.url, required this.openLabel, this.extra = const []});

  final String title;
  final String url;
  final String openLabel;

  /// Ek bağlantılar (ör. makalenin GitHub kodu): etiket ve adres.
  final List<(String, String)> extra;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return TpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.labelMedium),
          const SizedBox(height: 10),
          LinkPreviewLine(url: url),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => openLink(context, url),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(openLabel),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Bağlantıyı kopyala',
                onPressed: () => copyLink(context, url),
                style: IconButton.styleFrom(
                  side: BorderSide(color: tp.border),
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
            ],
          ),
          for (final (label, link) in extra)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton.icon(
                onPressed: () => showLinkSheet(context, title: label, url: link),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text(label),
              ),
            ),
        ],
      ),
    );
  }
}

/// Başlıklı metin bölümü.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Tp.headline(context, size: 19, weight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Tp.headline(context, size: 20, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: context.text.labelSmall),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats, this.note});

  final List<_Stat> stats;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return TpCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: stats),
          if (note != null) ...[const SizedBox(height: 10), Text(note!, style: context.text.labelSmall)],
        ],
      ),
    );
  }
}

Widget _bullets(BuildContext context, List<String> items) {
  final tp = context.tp;
  final style = Tp.article(context, 1).copyWith(fontSize: 16.5);
  return Column(
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: tp.accent, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(item, style: style)),
            ],
          ),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// GitHub projesi
// ---------------------------------------------------------------------------

class RepoDetailScreen extends StatelessWidget {
  const RepoDetailScreen({super.key, required this.repo});

  final Repo repo;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final story = repo.story;
    final body = Tp.article(context, 1).copyWith(fontSize: 16.5);
    return _DetailScaffold(
      kind: BookmarkKind.repo,
      entry: repo,
      shareTitle: repo.id,
      children: [
        Text('GitHub projesi', style: context.text.labelMedium?.copyWith(color: tp.accent)),
        const SizedBox(height: 8),
        Text(
          repo.owner,
          style: TextStyle(fontFamily: Tp.monoFont, fontSize: 14, color: tp.textSecondary),
        ),
        Text(
          repo.name,
          style: TextStyle(
            fontFamily: Tp.monoFont,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: tp.text,
            height: 1.25,
          ),
        ),
        if (repo.description case final description?) ...[
          const SizedBox(height: 10),
          Text(description, style: context.text.bodyLarge?.copyWith(color: tp.textSecondary)),
        ],
        const SizedBox(height: 18),
        _StatRow(
          stats: [
            _Stat(value: Fmt.compact(repo.stars), label: 'yıldız'),
            _Stat(value: Fmt.compact(repo.forks), label: 'çatallama'),
            _Stat(value: repo.language ?? '—', label: 'dil'),
          ],
          note:
              'GitHub verisi · proje ${Fmt.date(repo.createdAt)} tarihinde açıldı. Yıldız, GitHub kullanıcılarının '
              'projeyi beğenip takibe aldığını gösterir.',
        ),
        const SizedBox(height: 24),
        if (story != null) ...[
          _Block(
            title: 'Bu proje ne yapıyor?',
            child: Text(story.what, style: body),
          ),
          _Block(
            title: 'Neden ilgi görüyor?',
            child: Text(story.why, style: body),
          ),
          if (story.useCases.isNotEmpty) _Block(title: 'Neler yapılabilir?', child: _bullets(context, story.useCases)),
          if (story.audience.isNotEmpty)
            _Block(
              title: 'Kimler için?',
              child: Text(story.audience, style: body),
            ),
          if (story.caution.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: InfoPanel(
                title: 'Dikkat',
                icon: Icons.warning_amber_rounded,
                tone: tp.warning,
                child: Text(story.caution, style: context.text.bodyMedium?.copyWith(color: tp.text)),
              ),
            ),
          if (!story.fromReadme)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Bu tanıtım, projenin README dosyası okunamadığı için yalnızca kısa açıklamasına dayanıyor.',
                style: context.text.labelSmall,
              ),
            ),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              'Bu projenin Türkçe tanıtımı hazırlanıyor; genellikle bir saat içinde eklenir.',
              style: context.text.bodySmall,
            ),
          ),
        if (repo.topics.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [for (final t in repo.topics.take(8)) Pill(t)]),
          const SizedBox(height: 24),
        ],
        LinkBox(title: 'Proje sayfası', url: repo.url, openLabel: 'GitHub\'da aç'),
        const SizedBox(height: 12),
        Text(
          'Bir projeyi bilgisayarınıza kurmadan önce kaynağını, lisansını ve son güncellemelerini kontrol edin.',
          style: context.text.labelSmall?.copyWith(height: 1.45),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Makale
// ---------------------------------------------------------------------------

class PaperDetailScreen extends ConsumerWidget {
  const PaperDetailScreen({super.key, required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final settings = ref.watch(settingsProvider);
    final scale = settings.readingSize.scale;
    final extra = <(String, String)>[
      ('arXiv sayfası', paper.arxivUrl),
      if (paper.githubUrl case final github?) ('Makalenin kodu (GitHub)', github),
    ];
    return StoryReader(
      kind: BookmarkKind.paper,
      entry: paper,
      title: paper.displayTitle,
      story: paper.story,
      whyTitle: 'Bu araştırma neden önemli?',
      glossaryTitle: 'Bu makaledeki kavramlar',
      excerptNote: 'Makalenin tam metnine ulaşılamadı; bu yazı makalenin özetine dayanıyor.',
      header: [
        Text('Araştırma makalesi', style: context.text.labelMedium?.copyWith(color: tp.accent)),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            paper.displayTitle,
            style: Tp.headline(context, size: 25 * scale.clamp(0.9, 1.15), weight: FontWeight.w700, height: 1.22),
          ),
        ),
        if (settings.showOriginalTitles && paper.titleTr != null && paper.titleTr != paper.titleOriginal) ...[
          const SizedBox(height: 8),
          Text(
            paper.titleOriginal,
            style: context.text.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: tp.textTertiary),
          ),
        ],
        const SizedBox(height: 12),
        if (paper.authorLine.isNotEmpty) Text(paper.authorLine, style: context.text.bodySmall),
        const SizedBox(height: 4),
        MetaLine(parts: [Fmt.date(paper.publishedAt), 'Hugging Face\'te ${paper.upvotes} oy']),
        const SizedBox(height: 4),
        Text('Oylar, Hugging Face Daily Papers topluluğuna aittir.', style: context.text.labelSmall),
      ],
      fallback: [
        Text(paper.summaryTr ?? paper.abstractOriginal, style: Tp.article(context, scale)),
        const SizedBox(height: 12),
        const ReaderNote(
          icon: Icons.hourglass_top_rounded,
          text: 'Makalenin ayrıntılı Türkçe anlatımı hazırlanıyor; genellikle bir saat içinde eklenir.',
        ),
      ],
      footer: [
        LinkBox(title: 'Makale', url: paper.url, openLabel: 'Makale sayfasını aç', extra: extra),
        const SizedBox(height: 14),
        Text(
          'Bu yazı, makalenin kendisinden yapay zekâ desteğiyle Türkçe olarak hazırlandı. Sonuçlar ve rakamlar '
          'makaleden, kavram açıklamaları genel bilgiden gelir.',
          style: context.text.labelSmall?.copyWith(height: 1.45),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Yapay zekâ modeli
// ---------------------------------------------------------------------------

class ModelDetailScreen extends StatelessWidget {
  const ModelDetailScreen({super.key, required this.model});

  final AiModel model;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final facts = <(String, String)>[
      ('Görev', model.task),
      ('Tür', model.modality.label),
      if (model.parameters != null) ('Büyüklük', '${Fmt.parameters(model.parameters!)} parametre'),
      if (model.license != null) ('Lisans', model.license!),
      if (model.library != null) ('Kütüphane', model.library!),
      if (model.createdAt != null) ('Yayımlanma', Fmt.date(model.createdAt!)),
    ];
    return _DetailScaffold(
      kind: BookmarkKind.model,
      entry: model,
      shareTitle: model.id,
      children: [
        Text(
          'Yapay zekâ modeli · haftanın #${model.rank} modeli',
          style: context.text.labelMedium?.copyWith(color: tp.accent),
        ),
        const SizedBox(height: 10),
        Text(model.name, style: Tp.headline(context, size: 25, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(model.author, style: context.text.bodyMedium),
        const SizedBox(height: 18),
        _StatRow(
          stats: [
            _Stat(value: Fmt.compact(model.likes), label: 'beğeni'),
            _Stat(value: Fmt.compact(model.downloads), label: 'indirme'),
          ],
          note: 'Hugging Face verisi; beğeni ve indirmeler o platformun kullanıcılarına aittir.',
        ),
        const SizedBox(height: 24),
        if (model.summaryTr case final summary?)
          _Block(
            title: 'Bu model ne yapıyor?',
            child: Text(summary, style: Tp.article(context, 1).copyWith(fontSize: 16.5)),
          ),
        if (model.highlights.isNotEmpty) _Block(title: 'Öne çıkanlar', child: _bullets(context, model.highlights)),
        TpCard(
          child: Column(
            children: [
              for (final (i, (label, value)) in facts.indexed) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 110, child: Text(label, style: context.text.bodySmall)),
                      Expanded(
                        child: Text(value, style: context.text.bodyMedium?.copyWith(color: tp.text)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        LinkBox(title: 'Model sayfası', url: model.url, openLabel: 'Hugging Face\'te aç'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Siber tehdit
// ---------------------------------------------------------------------------

class VulnerabilityDetailScreen extends StatelessWidget {
  const VulnerabilityDetailScreen({super.key, required this.vuln});

  final Vulnerability vuln;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final body = Tp.article(context, 1).copyWith(fontSize: 16.5);
    return _DetailScaffold(
      kind: BookmarkKind.vuln,
      entry: vuln,
      shareTitle: '${vuln.cveId}: ${vuln.displayTitle}',
      children: [
        Row(
          children: [
            Icon(Icons.gpp_maybe_outlined, size: 18, color: tp.danger),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Aktif olarak istismar edilen açık',
                style: context.text.labelMedium?.copyWith(color: tp.danger, fontWeight: FontWeight.w700),
              ),
            ),
            if (vuln.ransomware) Pill('Fidye yazılımı', color: tp.danger),
          ],
        ),
        const SizedBox(height: 10),
        Text(vuln.displayTitle, style: Tp.headline(context, size: 24, weight: FontWeight.w700, height: 1.22)),
        const SizedBox(height: 8),
        Text(
          '${vuln.cveId} · ${vuln.vendor} ${vuln.product}',
          style: TextStyle(fontFamily: Tp.monoFont, fontSize: 13, color: tp.textSecondary),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: tp.surfaceAlt, borderRadius: BorderRadius.circular(Tp.radiusSmall)),
          child: Text(
            'ABD Siber Güvenlik Ajansı (CISA), bu açığın saldırganlarca gerçekten kullanıldığını '
            '${Fmt.date(vuln.dateAdded)} tarihinde doğruladı ve listesine ekledi.'
            '${vuln.dueDate == null ? '' : ' ABD kamu kurumlarının açığı en geç ${Fmt.date(vuln.dueDate!)} tarihine kadar kapatması gerekiyor.'}',
            style: context.text.bodySmall?.copyWith(color: tp.text),
          ),
        ),
        const SizedBox(height: 24),
        if (vuln.explanationTr case final explanation?)
          _Block(
            title: 'Basitçe ne oluyor?',
            child: Text(explanation, style: body),
          ),
        if (vuln.description.isNotEmpty)
          _Block(
            title: 'Teknik açıklama',
            child: Text(vuln.description, style: body),
          ),
        if (vuln.action.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: InfoPanel(
              title: 'Ne yapmalı?',
              icon: Icons.task_alt_rounded,
              tone: tp.success,
              child: Text(vuln.action, style: context.text.bodyMedium?.copyWith(color: tp.text)),
            ),
          ),
        if (vuln.cwes.isNotEmpty) ...[
          Text('Zayıflık türü', style: context.text.labelMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final c in vuln.cwes) Pill(c)]),
          const SizedBox(height: 24),
        ],
        LinkBox(title: 'Kaynak', url: vuln.url, openLabel: 'Açığın kaydını aç'),
      ],
    );
  }
}
