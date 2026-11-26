import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import 'radar_cards.dart';

/// Radar: yapay zekâ modelleri, makaleler, yeni açık kaynak projeler ve aktif siber tehditler.
class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: RadarSection.values.length,
    vsync: this,
    initialIndex: ref.read(radarSectionProvider).index,
  );

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final section = RadarSection.values[_tabs.index];
      if (ref.read(radarSectionProvider) != section) ref.read(radarSectionProvider.notifier).select(section);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(radarSectionProvider, (_, section) {
      if (_tabs.index != section.index) _tabs.animateTo(section.index);
    });
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(title: 'Radar', subtitle: 'Yapay zekâ ve güvenlik dünyasında öne çıkanlar'),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: Tp.page - 12),
              tabs: [for (final s in RadarSection.values) Tab(text: s.label)],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                // Sekmelerin sırası RadarSection ile aynıdır: Makaleler, Tehditler, Projeler, Modeller.
                children: [
                  _RadarList<Paper>(
                    section: RadarSection.papers,
                    provider: papersProvider,
                    endpoint: Endpoint.papers,
                    parse: parsePapers,
                    intro:
                        'Hugging Face Daily Papers\'ta araştırmacıların öne çıkardığı yeni makaleler, '
                        'Türkçe özetleriyle. Oylar Hugging Face topluluğundan gelir.',
                    sort: (items) => items..sort((a, b) => b.publishedAt.compareTo(a.publishedAt)),
                    card: (p) => PaperCard(paper: p),
                  ),
                  _RadarList<Vulnerability>(
                    section: RadarSection.threats,
                    provider: securityProvider,
                    endpoint: Endpoint.security,
                    parse: parseSecurity,
                    intro:
                        'ABD Siber Güvenlik Ajansı (CISA), saldırganların gerçekten kullandığını doğruladığı '
                        'açıkları bu listeye ekler. Kullandığınız bir ürün listedeyse güncellemeyi geciktirmeyin.',
                    sort: (items) => items..sort((a, b) => b.dateAdded.compareTo(a.dateAdded)),
                    card: (v) => VulnerabilityCard(vuln: v),
                  ),
                  _RadarList<Repo>(
                    section: RadarSection.repos,
                    provider: reposProvider,
                    endpoint: Endpoint.repos,
                    parse: parseRepos,
                    intro:
                        'GitHub\'da son günlerde açılıp en hızlı yıldız toplayan projeler. Her projenin ne işe '
                        'yaradığını ve neden ilgi gördüğünü kısaca anlatıyoruz.',
                    sort: (items) => items..sort((a, b) => b.stars.compareTo(a.stars)),
                    card: (r) => RepoCard(repo: r),
                  ),
                  _RadarList<AiModel>(
                    section: RadarSection.models,
                    provider: modelsProvider,
                    endpoint: Endpoint.models,
                    parse: parseModels,
                    intro:
                        'Hugging Face\'te bu hafta en çok beğeni ve indirme alan yapay zekâ modelleri. '
                        'Beğeni ve indirme sayıları Hugging Face kullanıcılarına aittir.',
                    sort: (items) => items..sort((a, b) => a.rank.compareTo(b.rank)),
                    card: (m) => ModelCard(model: m),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarList<T> extends ConsumerStatefulWidget {
  const _RadarList({
    required this.section,
    required this.provider,
    required this.endpoint,
    required this.parse,
    required this.intro,
    required this.sort,
    required this.card,
  });

  final RadarSection section;
  final StreamProvider<Snapshot<Feed<T>>> provider;
  final Endpoint endpoint;
  final Feed<T> Function(String body) parse;
  final String intro;
  final List<T> Function(List<T> items) sort;
  final Widget Function(T item) card;

  @override
  ConsumerState<_RadarList<T>> createState() => _RadarListState<T>();
}

class _RadarListState<T> extends ConsumerState<_RadarList<T>> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(scrollToTopProvider, (_, next) {
      if (next.tab == AppTab.radar && ref.read(radarSectionProvider) == widget.section && _scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
    final value = ref.watch(widget.provider);
    return FeedView<T>(
      value: value,
      onRetry: () => ref.invalidate(widget.provider),
      builder: (context, snapshot) {
        final items = widget.sort([...snapshot.data.items]);
        return RefreshIndicator(
          onRefresh: () async {
            final error = await refreshFeed(ref, widget.endpoint, widget.parse, () => ref.invalidate(widget.provider));
            if (error != null && context.mounted) showMessage(context, error.message);
          },
          child: ListView.separated(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(Tp.page, 16, Tp.page, 24 + MediaQuery.paddingOf(context).bottom),
            itemCount: items.isEmpty ? 2 : items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBanner(
                      snapshot: snapshot,
                      generatedAt: snapshot.data.generatedAt,
                      margin: const EdgeInsets.only(bottom: 14),
                    ),
                    Text(widget.intro, style: context.text.bodySmall),
                  ],
                );
              }
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Şu an gösterilecek kayıt yok',
                  message: 'Liste her saat güncellenir. Biraz sonra aşağı çekip yenileyin.',
                  compact: true,
                );
              }
              return widget.card(items[i - 1]);
            },
          ),
        );
      },
    );
  }
}
