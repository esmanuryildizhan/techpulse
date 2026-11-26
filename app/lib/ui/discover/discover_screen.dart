import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/ranking.dart';
import '../navigation.dart';
import '../news/news_cards.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';

/// Keşfet: arama, şu an popüler olan haberler, gündemdeki konular ve bütün konular (kaydırmadan görünen ızgara).
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopProvider, (_, next) {
      if (next.tab == AppTab.discover && _scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
    final value = ref.watch(newsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FeedView<NewsItem>(
          value: value,
          onRetry: () => ref.invalidate(newsProvider),
          header: const ScreenHeader(title: 'Keşfet'),
          loading: const FeedSkeleton(headline: false),
          builder: (context, snapshot) {
            final now = ref.watch(clockProvider)();
            final all = ref.watch(visibleNewsProvider);
            final popular = popularNews(all, now);
            final trends = trendingTopics(all, now, limit: 6);
            return RefreshIndicator(
              onRefresh: () async {
                final error = await refreshNews(ref);
                if (error != null && context.mounted) showMessage(context, error.message);
              },
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: ScreenHeader(title: 'Keşfet')),
                  const SliverToBoxAdapter(child: _SearchField()),
                  SliverToBoxAdapter(
                    child: StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt),
                  ),
                  if (popular.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: SectionHeader(
                        title: 'Şu an popüler',
                        subtitle: 'Son 48 saatin en çok öne çıkan haberleri',
                      ),
                    ),
                    SliverList.separated(
                      itemCount: popular.length,
                      itemBuilder: (context, i) => RankedNewsRow(rank: i + 1, item: popular[i]),
                      separatorBuilder: (_, _) => const Divider(indent: Tp.page + 34, endIndent: Tp.page),
                    ),
                  ],
                  if (trends.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: Tp.section)),
                    const SliverToBoxAdapter(
                      child: SectionHeader(title: 'Gündemdeki konular', subtitle: 'Son 3 günde en çok konuşulanlar'),
                    ),
                    SliverToBoxAdapter(child: _TrendList(trends: trends)),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: Tp.section)),
                  const SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Konular',
                      subtitle: 'Sağ üstteki sayı, o konudaki güncel haber sayısıdır',
                    ),
                  ),
                  SliverToBoxAdapter(child: _CategoryGrid(news: all)),
                  SliverToBoxAdapter(child: SizedBox(height: 28 + MediaQuery.paddingOf(context).bottom)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 20),
      child: Material(
        color: tp.surfaceAlt,
        borderRadius: BorderRadius.circular(Tp.radiusSmall),
        child: InkWell(
          onTap: () => openSearch(context),
          borderRadius: BorderRadius.circular(Tp.radiusSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: tp.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Haber, konu, proje veya model ara',
                    style: context.text.bodyLarge?.copyWith(color: tp.textTertiary, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Twitter'daki "Gündem" listesi gibi: sıra, konu, kaç haberde geçtiği.
class _TrendList extends StatelessWidget {
  const _TrendList({required this.trends});

  final List<TrendTopic> trends;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tp.page),
      child: TpCard(
        child: Column(
          children: [
            for (final (i, trend) in trends.indexed) ...[
              if (i > 0) const Divider(indent: 16, endIndent: 16),
              InkWell(
                onTap: () => openTopic(context, trend.label),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${i + 1} · ${trend.category.shortLabel}', style: context.text.labelSmall),
                            const SizedBox(height: 3),
                            Text(
                              trend.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text('${trend.count} haber', style: context.text.labelSmall),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: tp.textTertiary),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dokuz konu, 3×3 ızgara: hepsi kaydırmadan görünür.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.news});

  final List<NewsItem> news;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final counts = <TechCategory, int>{};
    for (final n in news) {
      counts[n.category] = (counts[n.category] ?? 0) + 1;
    }
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tp.page),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05 / scaler.scale(1).clamp(1.0, 1.5),
        padding: EdgeInsets.zero,
        children: [
          for (final c in TechCategory.values)
            Material(
              color: tp.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Tp.radius),
                side: BorderSide(color: tp.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => openCategory(context, c),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c.tone(context.brightness).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(c.icon, size: 17, color: c.tone(context.brightness)),
                          ),
                          const Spacer(),
                          Text(
                            '${counts[c] ?? 0}',
                            semanticsLabel: '${counts[c] ?? 0} haber',
                            style: context.text.labelSmall,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        c.shortLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelLarge?.copyWith(fontSize: 13, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
