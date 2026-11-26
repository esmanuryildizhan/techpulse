import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../navigation.dart';
import '../widgets/common.dart';

/// Programlama dili için bilinen bir renk; bilinmiyorsa nötr gri.
Color languageColor(String? language, TpColors tp) => switch (language?.toLowerCase()) {
  'python' => const Color(0xFF3B78B0),
  'typescript' => const Color(0xFF3178C6),
  'javascript' => const Color(0xFFD4B21E),
  'rust' => const Color(0xFFB7410E),
  'go' => const Color(0xFF00ADD8),
  'c++' => const Color(0xFFF34B7D),
  'c' => const Color(0xFF6E7681),
  'java' => const Color(0xFFB07219),
  'kotlin' => const Color(0xFFA97BFF),
  'swift' => const Color(0xFFF05138),
  'dart' => const Color(0xFF00B4AB),
  'ruby' => const Color(0xFFCC342D),
  'shell' => const Color(0xFF4EAA25),
  _ => tp.textTertiary,
};

class ModelCard extends StatelessWidget {
  const ModelCard({super.key, required this.model});

  final AiModel model;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return TpCard(
      onTap: () => openModel(context, model),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: tp.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                child: Icon(model.modality.icon, size: 20, color: tp.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${model.author} · ${model.task}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall,
                    ),
                  ],
                ),
              ),
              Text(
                '#${model.rank}',
                style: TextStyle(fontFamily: Tp.serif, fontSize: 18, fontWeight: FontWeight.w700, color: tp.accent),
              ),
            ],
          ),
          if (model.summaryTr case final summary?) ...[
            const SizedBox(height: 12),
            Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
          ],
          const SizedBox(height: 12),
          MetaLine(
            parts: [
              '${Fmt.compact(model.likes)} beğeni',
              '${Fmt.compact(model.downloads)} indirme',
              if (model.parameters != null) '${Fmt.parameters(model.parameters!)} parametre',
            ],
          ),
        ],
      ),
    );
  }
}

class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context) {
    return TpCard(
      onTap: () => openPaper(context, paper),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(paper.displayTitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: Tp.headline(context, size: 17)),
          if (paper.authorLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(paper.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall),
          ],
          if (paper.summaryTr case final summary?) ...[
            const SizedBox(height: 10),
            Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
          ],
          const SizedBox(height: 12),
          MetaLine(
            parts: [
              '${paper.upvotes} oy (Hugging Face)',
              Fmt.relative(paper.publishedAt),
              if (paper.readingMinutes != null) '${paper.readingMinutes} dk okuma',
            ],
          ),
        ],
      ),
    );
  }
}

class RepoCard extends StatelessWidget {
  const RepoCard({super.key, required this.repo});

  final Repo repo;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return TpCard(
      onTap: () => openRepo(context, repo),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${repo.owner} / ',
                  style: TextStyle(color: tp.textSecondary, fontWeight: FontWeight.w400),
                ),
                TextSpan(text: repo.name),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Tp.monoFont,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tp.text,
              height: 1.35,
            ),
          ),
          if (repo.description case final description?) ...[
            const SizedBox(height: 8),
            Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (repo.language != null) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: languageColor(repo.language, tp), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(repo.language!, style: context.text.labelSmall),
                const SizedBox(width: 14),
              ],
              Icon(Icons.star_rounded, size: 15, color: tp.warning),
              const SizedBox(width: 3),
              Text('${Fmt.compact(repo.stars)} yıldız', style: context.text.labelSmall),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  '${Fmt.relative(repo.createdAt)} açıldı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VulnerabilityCard extends StatelessWidget {
  const VulnerabilityCard({super.key, required this.vuln});

  final Vulnerability vuln;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return TpCard(
      onTap: () => openVulnerability(context, vuln),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_maybe_outlined, size: 17, color: tp.danger),
              const SizedBox(width: 6),
              Text(
                vuln.cveId,
                style: TextStyle(
                  fontFamily: Tp.monoFont,
                  fontSize: 12.5,
                  color: tp.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (vuln.ransomware) Pill('Fidye yazılımı', color: tp.danger),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            vuln.displayTitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Tp.headline(context, size: 16.5),
          ),
          const SizedBox(height: 6),
          Text(
            '${vuln.vendor} · ${vuln.product}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium,
          ),
          const SizedBox(height: 10),
          MetaLine(
            parts: [
              '${Fmt.shortDate(vuln.dateAdded)} listeye eklendi',
              if (vuln.dueDate != null) 'Son tarih ${Fmt.shortDate(vuln.dueDate!)}',
            ],
          ),
        ],
      ),
    );
  }
}
