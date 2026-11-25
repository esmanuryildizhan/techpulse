import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../news/cards.dart';
import '../news/news_list_screen.dart';
import '../radar/radar_cards.dart';
import '../widgets/common.dart';

/// Aramaya götüren, arama kutusu görünümündeki alan (Ana Sayfa ve Keşfet).
class SearchLauncher extends StatelessWidget {
  const SearchLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tp.page),
      child: Semantics(
        button: true,
        label: 'Ara',
        child: Material(
          color: tp.card,
          borderRadius: BorderRadius.circular(Tp.radiusSmall),
          child: InkWell(
            borderRadius: BorderRadius.circular(Tp.radiusSmall),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SearchScreen())),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(Tp.radiusSmall), border: Border.all(color: tp.border)),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: tp.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Haber, teknoloji veya konu ara...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(color: tp.textMuted, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum SearchFilter {
  all('Tümü'),
  news('Haberler'),
  papers('Makaleler'),
  models('Modeller'),
  sources('Kaynaklar');

  const SearchFilter(this.label);

  final String label;
}

/// Bir kaynağın arama sonucu.
class _SourceHit {
  const _SourceHit(this.id, this.name, this.count);

  final String id;
  final String name;
  final int count;
}

/// Haberlerde, makalelerde, modellerde ve kaynaklarda arama. Türkçe karakterlere duyarsızdır
/// ("guvenlik" yazınca "Güvenlik" bulunur); başlıkta geçenler önce gelir.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  SearchFilter _filter = SearchFilter.all;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = foldForSearch(value.trim()));
    });
  }

  List<T> _rank<T>(Iterable<T> items, String Function(T) title, String Function(T) rest) {
    final scored = <(T, int)>[];
    for (final item in items) {
      final t = foldForSearch(title(item));
      if (t.contains(_query)) {
        scored.add((item, 0));
      } else if (foldForSearch(rest(item)).contains(_query)) {
        scored.add((item, 1));
      }
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final s in scored) s.$1];
  }

  @override
  Widget build(BuildContext context) {
    final news = ref.watch(visibleNewsProvider);
    final papers = ref.watch(papersProvider).value?.data.items ?? const <Paper>[];
    final models = ref.watch(modelsProvider).value?.data.items ?? const <AiModel>[];

    final active = _query.length >= 2;
    final newsHits = !active
        ? const <NewsItem>[]
        : _rank<NewsItem>(
            news,
            (n) => '${n.displayTitle} ${n.titleOriginal}',
            (n) => '${n.displaySummary ?? ''} ${n.sourceName} ${n.category.label} ${n.topics.join(' ')} ${n.article?.intro ?? ''}',
          );
    final paperHits = !active
        ? const <Paper>[]
        : _rank<Paper>(papers, (p) => '${p.displayTitle} ${p.titleOriginal}', (p) => '${p.summaryTr ?? ''} ${p.authors.join(' ')} ${p.topics.join(' ')}');
    final modelHits = !active
        ? const <AiModel>[]
        : _rank<AiModel>(models, (m) => m.id, (m) => '${m.task} ${m.summaryTr ?? ''} ${m.library ?? ''}');
    final sourceCounts = <String, _SourceHit>{};
    for (final n in news) {
      final hit = sourceCounts[n.sourceId];
      sourceCounts[n.sourceId] = _SourceHit(n.sourceId, n.sourceName, (hit?.count ?? 0) + 1);
    }
    final sourceHits = !active ? const <_SourceHit>[] : sourceCounts.values.where((s) => foldForSearch(s.name).contains(_query)).toList();

    bool show(SearchFilter f) => _filter == SearchFilter.all || _filter == f;
    final total = newsHits.length + paperHits.length + modelHits.length + sourceHits.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (value) => setState(() => _query = foldForSearch(value.trim())),
            decoration: InputDecoration(
              hintText: 'Haber, şirket, model veya konu ara',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Temizle',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(Tp.page, 6, Tp.page, 8),
              children: [
                for (final f in SearchFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(f.label), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !active
                ? const EmptyState(
                    icon: Icons.manage_search_rounded,
                    title: 'Ne aramak istersin?',
                    message: 'Haber başlığı, şirket, teknoloji, programlama dili, yapay zekâ modeli ya da kaynak adı yazabilirsin.',
                  )
                : total == 0
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Sonuç bulunamadı',
                        message: '"${_controller.text.trim()}" için bir şey bulamadık. Farklı bir kelime ya da daha kısa bir ifade dene.',
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 32),
                        children: [
                          if (show(SearchFilter.news) && newsHits.isNotEmpty) ...[
                            _Header('Haberler', newsHits.length),
                            for (final item in newsHits.take(_filter == SearchFilter.all ? 8 : 60)) ListNewsCard(item: item),
                          ],
                          if (show(SearchFilter.papers) && paperHits.isNotEmpty) ...[
                            _Header('Makaleler', paperHits.length),
                            for (final paper in paperHits.take(_filter == SearchFilter.all ? 4 : 40))
                              Padding(padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 12), child: PaperCard(paper: paper)),
                          ],
                          if (show(SearchFilter.models) && modelHits.isNotEmpty) ...[
                            _Header('Modeller', modelHits.length),
                            for (final model in modelHits.take(_filter == SearchFilter.all ? 4 : 40))
                              Padding(padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 12), child: ModelCard(model: model)),
                          ],
                          if (show(SearchFilter.sources) && sourceHits.isNotEmpty) ...[
                            _Header('Kaynaklar', sourceHits.length),
                            for (final source in sourceHits)
                              ListTile(
                                leading: SourceAvatar(name: source.name, size: 34),
                                title: Text(source.name),
                                subtitle: Text('${source.count} haber'),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(builder: (_) => NewsListScreen.source(sourceId: source.id, sourceName: source.name)),
                                ),
                              ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.count);

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Tp.page, 16, Tp.page, 6),
        child: Text('$title · $count', style: context.text.labelMedium),
      );
}
