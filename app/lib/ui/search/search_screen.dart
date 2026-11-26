import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/ranking.dart';
import '../navigation.dart';
import '../news/news_cards.dart';
import '../widgets/common.dart';

/// Arama: haberler, GitHub projeleri, makaleler ve modeller içinde (Türkçe karakter ve büyük/küçük harf
/// farkı gözetmeden). Veriler telefonda olduğu için internetsiz de çalışır.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _query = text);
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final terms = foldForSearch(_query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    bool matches(Iterable<String?> fields) {
      final haystack = foldForSearch(fields.whereType<String>().join(' '));
      return terms.every(haystack.contains);
    }

    final news = ref.watch(visibleNewsProvider);
    final repos = ref.watch(reposProvider).value?.data.items ?? const <Repo>[];
    final papers = ref.watch(papersProvider).value?.data.items ?? const <Paper>[];
    final models = ref.watch(modelsProvider).value?.data.items ?? const <AiModel>[];

    final newsHits = terms.isEmpty
        ? const <NewsItem>[]
        : news
              .where(
                (n) => matches([
                  n.displayTitle,
                  n.titleOriginal,
                  n.displaySummary,
                  n.sourceName,
                  n.category.label,
                  ...n.topics,
                ]),
              )
              .take(40)
              .toList();
    final repoHits = terms.isEmpty
        ? const <Repo>[]
        : repos.where((r) => matches([r.id, r.description, r.language, ...r.topics])).take(10).toList();
    final paperHits = terms.isEmpty
        ? const <Paper>[]
        : papers.where((p) => matches([p.displayTitle, p.titleOriginal, p.summaryTr, ...p.topics])).take(10).toList();
    final modelHits = terms.isEmpty
        ? const <AiModel>[]
        : models.where((m) => matches([m.id, m.name, m.author, m.task, m.summaryTr])).take(10).toList();
    final total = newsHits.length + repoHits.length + paperHits.length + modelHits.length;
    final suggestions = trendingTopics(news, ref.watch(clockProvider)(), limit: 8);

    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) => ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: tp.surfaceAlt, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: tp.textSecondary),
      ),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      contentPadding: const EdgeInsets.symmetric(horizontal: Tp.page),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Haber, konu, proje veya model',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(tooltip: 'Temizle', onPressed: () => _set(''), icon: const Icon(Icons.close_rounded)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        actions: const [SizedBox(width: 12)],
      ),
      body: terms.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(Tp.page, 16, Tp.page, 24),
              children: [
                if (suggestions.isNotEmpty) ...[
                  Text('Gündemdeki konular', style: context.text.labelMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in suggestions) ActionChip(label: Text(t.label), onPressed: () => _set(t.label)),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  'Son 30 günün haberleri, Radar\'daki projeler, makaleler ve modeller içinde arar. '
                  'Telefondaki verilerde aradığı için internet olmadan da çalışır.',
                  style: context.text.bodySmall,
                ),
              ],
            )
          : total == 0
          ? ListView(
              children: [
                EmptyState(
                  icon: Icons.search_off_rounded,
                  title: '"$_query" için sonuç yok',
                  message: 'Daha kısa veya farklı bir kelime deneyin. Ör. "yapay zekâ", "Android", "güvenlik açığı".',
                ),
              ],
            )
          : ListView(
              padding: EdgeInsets.only(top: 8, bottom: 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 4),
                  child: Text('$total sonuç', style: context.text.labelSmall),
                ),
                if (newsHits.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Haberler (${newsHits.length})',
                    padding: const EdgeInsets.fromLTRB(Tp.page, 12, Tp.page, 0),
                  ),
                  for (final (i, n) in newsHits.indexed) ...[
                    if (i > 0) const Divider(indent: Tp.page, endIndent: Tp.page),
                    NewsRow(item: n),
                  ],
                ],
                if (repoHits.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Projeler (${repoHits.length})',
                    padding: const EdgeInsets.fromLTRB(Tp.page, 20, Tp.page, 4),
                  ),
                  for (final r in repoHits)
                    tile(
                      icon: Icons.code_rounded,
                      title: r.id,
                      subtitle: '${Fmt.compact(r.stars)} yıldız · ${r.description ?? ''}',
                      onTap: () => openRepo(context, r),
                    ),
                ],
                if (paperHits.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Makaleler (${paperHits.length})',
                    padding: const EdgeInsets.fromLTRB(Tp.page, 20, Tp.page, 4),
                  ),
                  for (final p in paperHits)
                    tile(
                      icon: Icons.description_outlined,
                      title: p.displayTitle,
                      subtitle: p.authorLine,
                      onTap: () => openPaper(context, p),
                    ),
                ],
                if (modelHits.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Modeller (${modelHits.length})',
                    padding: const EdgeInsets.fromLTRB(Tp.page, 20, Tp.page, 4),
                  ),
                  for (final m in modelHits)
                    tile(
                      icon: m.modality.icon,
                      title: m.name,
                      subtitle: '${m.author} · ${m.task}',
                      onTap: () => openModel(context, m),
                    ),
                ],
              ],
            ),
    );
  }
}
