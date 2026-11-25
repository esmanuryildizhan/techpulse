import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../news/cards.dart';
import '../radar/radar_cards.dart';
import '../threats/threats_screen.dart';
import '../widgets/actions.dart';
import '../widgets/news_image.dart';

/// Telefonda saklanan kaydı içerik nesnesine çevirir; bozuk kayıtta null döner.
Entry? decodeRecord(BookmarkRecord record) {
  try {
    final json = jsonDecode(record.payload) as Map<String, dynamic>;
    return switch (record.kind) {
      BookmarkKind.news => NewsItem.fromJson(json),
      BookmarkKind.paper => Paper.fromJson(json),
      BookmarkKind.model => AiModel.fromJson(json),
      BookmarkKind.repo => Repo.fromJson(json),
      BookmarkKind.vuln => Vulnerability.fromJson(json),
    };
  } catch (_) {
    return null;
  }
}

extension BookmarkKindLabel on BookmarkKind {
  String get label => switch (this) {
        BookmarkKind.news => 'Haberler',
        BookmarkKind.paper => 'Makaleler',
        BookmarkKind.model => 'Modeller',
        BookmarkKind.repo => 'Projeler',
        BookmarkKind.vuln => 'Siber tehditler',
      };

  IconData get icon => switch (this) {
        BookmarkKind.news => Icons.article_outlined,
        BookmarkKind.paper => Icons.description_outlined,
        BookmarkKind.model => Icons.hub_outlined,
        BookmarkKind.repo => Icons.code_rounded,
        BookmarkKind.vuln => Icons.gpp_maybe_outlined,
      };
}

/// Kaydedilenler ve okuma geçmişindeki bir satır. Haberler liste kartıyla, diğer içerikler küçük
/// görselli satırla gösterilir.
class RecordRow extends ConsumerWidget {
  const RecordRow({super.key, required this.record, required this.entry, required this.note});

  final BookmarkRecord record;
  final Entry entry;

  /// "Kaydedildi: 2 gün önce" gibi zaman notu.
  final String note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = this.entry;
    if (entry is NewsItem) {
      return ListNewsCard(item: entry, showSummary: false, trailingNote: '${entry.sourceName} · $note');
    }
    final (category, subtitle, icon) = switch (entry) {
      Paper p => (TechCategory.ai, 'Makale · ${p.upvotes} oy', Icons.description_outlined),
      AiModel m => (TechCategory.ai, 'Model · ${m.task}', Icons.hub_outlined),
      Repo r => (TechCategory.dev, 'Proje · ${Fmt.compact(r.stars)} yıldız', Icons.code_rounded),
      Vulnerability v => (TechCategory.security, 'Siber tehdit · ${v.cveId}', Icons.gpp_maybe_outlined),
      _ => (TechCategory.industry, '', Icons.bookmark_outline_rounded),
    };
    void open() {
      switch (entry) {
        case final Paper p:
          openPaper(context, ref, p);
        case final AiModel m:
          showModelSheet(context, m);
        case final Repo r:
          openLink(context, r.url);
        case final Vulnerability v:
          showVulnerabilitySheet(context, v);
        default:
          break;
      }
    }
    return InkWell(
      onTap: open,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tp.page, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: NewsImage(
                url: entry.imageUrl,
                seed: entry.id,
                category: category,
                icon: icon,
                borderRadius: BorderRadius.circular(Tp.radiusSmall),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  const SizedBox(height: 4),
                  Text('$subtitle · $note', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
