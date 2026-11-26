import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/news_image.dart';

extension BookmarkKindLabel on BookmarkKind {
  String get label => switch (this) {
    BookmarkKind.news => 'Haber',
    BookmarkKind.paper => 'Makale',
    BookmarkKind.model => 'Model',
    BookmarkKind.repo => 'Proje',
    BookmarkKind.vuln => 'Siber tehdit',
  };

  String get pluralLabel => switch (this) {
    BookmarkKind.news => 'Haberler',
    BookmarkKind.paper => 'Makaleler',
    BookmarkKind.model => 'Modeller',
    BookmarkKind.repo => 'Projeler',
    BookmarkKind.vuln => 'Tehditler',
  };

  IconData get icon => switch (this) {
    BookmarkKind.news => Icons.article_outlined,
    BookmarkKind.paper => Icons.description_outlined,
    BookmarkKind.model => Icons.auto_awesome_outlined,
    BookmarkKind.repo => Icons.code_rounded,
    BookmarkKind.vuln => Icons.gpp_maybe_outlined,
  };
}

/// Kaydedilenler ve okuma geçmişindeki satır. [timeLabel]: "kaydedildi" veya "okundu".
class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.record, required this.timeLabel});

  final BookmarkRecord record;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final entry = entryFromRecord(record);
    final title = entry?.displayTitle ?? 'Okunamayan kayıt';
    final source = switch (entry) {
      NewsItem(:final sourceName) => sourceName,
      Paper() => 'Hugging Face',
      AiModel(:final author) => author,
      Repo() => 'GitHub',
      Vulnerability(:final cveId) => cveId,
      _ => '',
    };
    final thumb = switch (entry) {
      final NewsItem n => NewsImage(
        url: n.imageUrl,
        seed: n.id,
        category: n.category,
        borderRadius: BorderRadius.circular(8),
      ),
      _ => Container(
        decoration: BoxDecoration(color: tp.surfaceAlt, borderRadius: BorderRadius.circular(8)),
        child: Icon(record.kind.icon, color: record.kind == BookmarkKind.vuln ? tp.danger : tp.textSecondary),
      ),
    };
    return InkWell(
      onTap: entry == null
          ? null
          : () {
              if (!openRecord(context, record)) showMessage(context, 'Bu kayıt açılamadı.');
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tp.page, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(dimension: 56, child: thumb),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Tp.headline(context, size: 15.5, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  MetaLine(parts: [record.kind.label, source, '$timeLabel ${Fmt.relative(record.savedAt)}']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
