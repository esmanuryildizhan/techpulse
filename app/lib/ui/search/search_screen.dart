import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../news/news_card.dart';
import '../radar/radar_cards.dart';
import '../security/security_screen.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';

/// Telefondaki (önbellekteki) bütün içerikte Türkçe karakterlere duyarsız arama.
/// İnternet gerektirmez; "guvenlik" yazınca "Güvenlik" geçen kayıtlar da bulunur.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    // Her harfte değil, kullanıcı 250 ms yazmayı bırakınca ara.
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terms = foldForSearch(_query).split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();

    bool matches(List<String?> fields) {
      if (terms.isEmpty) return false;
      final haystack = foldForSearch(fields.whereType<String>().join(' '));
      return terms.every(haystack.contains);
    }

    final news = (ref.watch(newsProvider).value?.data.items ?? const <NewsItem>[])
        .where((n) => matches([n.titleTr, n.titleOriginal, n.summaryTr, n.sourceName, ...n.tags]))
        .take(30)
        .toList();
    final papers = (ref.watch(papersProvider).value?.data.items ?? const <Paper>[])
        .where((p) => matches([p.titleTr, p.titleOriginal, p.summaryTr, ...p.tags, ...p.authors]))
        .take(20)
        .toList();
    final models = (ref.watch(modelsProvider).value?.data.items ?? const <AiModel>[])
        .where((m) => matches([m.id, m.task, m.summaryTr, m.pipelineTag]))
        .take(20)
        .toList();
    final repos = (ref.watch(reposProvider).value?.data.items ?? const <Repo>[])
        .where((r) => matches([r.id, r.descriptionTr, r.descriptionOriginal, r.language, ...r.topics]))
        .take(20)
        .toList();
    final vulns = (ref.watch(securityProvider).value?.data.items ?? const <Vulnerability>[])
        .where((v) => matches([v.cveId, v.vendor, v.product, v.nameTr, v.nameOriginal]))
        .take(20)
        .toList();

    final total = news.length + papers.length + models.length + repos.length + vulns.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: 'Haber, model, makale, CVE ara…',
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Temizle',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
          style: theme.textTheme.titleMedium,
        ),
      ),
      body: terms.isEmpty
          ? const MessageView(
              icon: Icons.search,
              title: 'Ne aramak istersiniz?',
              message: 'Örnek: "Gemini", "görüntü bölütleme", "Windows", "CVE-2026". '
                  'Arama, telefondaki güncel verilerde yapılır.',
            )
          : total == 0
              ? MessageView(icon: Icons.search_off, title: 'Sonuç bulunamadı', message: '"$_query" için kayıt yok.')
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (news.isNotEmpty) ...[
                      SectionLabel('Haberler · ${news.length}'),
                      for (final n in news) NewsCard(item: n),
                    ],
                    if (papers.isNotEmpty) ...[
                      SectionLabel('Makaleler · ${papers.length}'),
                      for (final p in papers) PaperCard(paper: p),
                    ],
                    if (models.isNotEmpty) ...[
                      SectionLabel('Modeller · ${models.length}'),
                      for (final m in models) ModelCard(model: m),
                    ],
                    if (repos.isNotEmpty) ...[
                      SectionLabel('Projeler · ${repos.length}'),
                      for (final r in repos) RepoCard(repo: r),
                    ],
                    if (vulns.isNotEmpty) ...[
                      SectionLabel('Güvenlik · ${vulns.length}'),
                      for (final v in vulns) VulnerabilityCard(vuln: v),
                    ],
                  ],
                ),
    );
  }
}
