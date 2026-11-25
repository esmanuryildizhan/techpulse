import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/ranking.dart';
import '../news/news_detail_screen.dart';
import '../news/news_list_screen.dart';
import '../radar/radar_screen.dart';
import '../search/search_screen.dart';
import '../threats/threats_screen.dart';
import '../widgets/common.dart';
import '../widgets/news_image.dart';

/// Keşfet: konu kartları, trend konular, yapay zekâ radarı, aktif siber tehditler ve popüler haberler.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(visibleNewsProvider);
    final now = ref.watch(clockProvider)();
    final order = ref.watch(profileProvider.select((p) => p.categoryOrder));
    final topics = trendingTopics(news, now);
    final popular = popularNews(news, now, limit: 5);
    final counts = <TechCategory, int>{};
    for (final item in news) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: ScreenTitle('Keşfet', subtitle: 'Konuları, trendleri ve yapay zekâ dünyasını keşfet.'),
          ),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 12), child: SearchLauncher())),
          const SliverToBoxAdapter(child: SectionHeader('Kategoriler')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Tp.page),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 154,
              ),
              itemCount: order.length,
              itemBuilder: (context, index) => _CategoryCard(category: order[index], count: counts[order[index]] ?? 0),
            ),
          ),
          if (topics.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionHeader('Trend Konular', subtitle: 'Son üç günde en çok konuşulanlar'),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Tp.page),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (index, topic) in topics.indexed)
                      _TopicChip(topic: topic, hot: index < 3),
                  ],
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SectionHeader('Yapay Zekâ Radarı', subtitle: 'Hugging Face ve GitHub\'dan güncel veriler')),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: Tp.page),
            sliver: SliverToBoxAdapter(child: _RadarTiles()),
          ),
          const SliverToBoxAdapter(child: SectionHeader('Siber Tehditler')),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: Tp.page),
            sliver: SliverToBoxAdapter(child: _ThreatsTile()),
          ),
          if (popular.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                'Popüler Haberler',
                actionLabel: 'Tümünü gör',
                onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NewsListScreen.popular())),
              ),
            ),
            SliverList.builder(
              itemCount: popular.length,
              itemBuilder: (context, index) => _RankedNews(rank: index + 1, item: popular[index]),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.count});

  final TechCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tone = category.tone(context.brightness);
    return TpCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NewsListScreen.category(category))),
      semanticLabel: '${category.label}, $count haber',
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: tone.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(11)),
                child: Icon(category.icon, color: tone, size: 21),
              ),
              const Spacer(),
              Text('$count haber', style: context.text.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          Text(category.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(height: 1.25)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(category.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.topic, required this.hot});

  final TrendTopic topic;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return ActionChip(
      avatar: Icon(hot ? Icons.local_fire_department_rounded : Icons.tag_rounded, size: 16, color: hot ? tp.warning : tp.textMuted),
      label: Text('${topic.label}  ${topic.count}'),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NewsListScreen.topic(topic.label))),
    );
  }
}

class _RadarTiles extends ConsumerWidget {
  const _RadarTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelsProvider).value?.data.items ?? const <AiModel>[];
    final papers = ref.watch(papersProvider).value?.data.items ?? const <Paper>[];
    final repos = ref.watch(reposProvider).value?.data.items ?? const <Repo>[];
    void open(RadarTab tab) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RadarScreen(initialTab: tab)));
    return Column(
      children: [
        _FeatureTile(
          icon: Icons.hub_outlined,
          color: TechCategory.ai.tone(context.brightness),
          title: 'Trend Modeller',
          subtitle: models.isEmpty ? 'Hugging Face\'te bu hafta öne çıkan modeller' : 'Zirvede: ${models.first.name}',
          trailing: models.isEmpty ? null : '${models.length}',
          onTap: () => open(RadarTab.models),
        ),
        const SizedBox(height: 10),
        _FeatureTile(
          icon: Icons.article_outlined,
          color: TechCategory.data.tone(context.brightness),
          title: 'Günün Makaleleri',
          subtitle: papers.isEmpty ? 'Araştırma topluluğunun öne çıkardığı makaleler' : papers.first.displayTitle,
          trailing: papers.isEmpty ? null : '${papers.length}',
          onTap: () => open(RadarTab.papers),
        ),
        const SizedBox(height: 10),
        _FeatureTile(
          icon: Icons.code_rounded,
          color: TechCategory.dev.tone(context.brightness),
          title: 'Yükselen Projeler',
          subtitle: repos.isEmpty ? 'GitHub\'da bu hafta hızla yıldız toplayanlar' : 'En hızlı yükselen: ${repos.first.id}',
          trailing: repos.isEmpty ? null : '${repos.length}',
          onTap: () => open(RadarTab.repos),
        ),
      ],
    );
  }
}

class _ThreatsTile extends ConsumerWidget {
  const _ThreatsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vulns = ref.watch(securityProvider).value?.data.items ?? const <Vulnerability>[];
    final recent = vulns.where((v) => DateTime.now().difference(v.dateAdded) < const Duration(days: 7)).length;
    return _FeatureTile(
      icon: Icons.gpp_maybe_outlined,
      color: context.tp.danger,
      title: 'Aktif Siber Tehditler',
      subtitle: vulns.isEmpty
          ? 'Saldırılarda kullanıldığı doğrulanan güvenlik açıkları'
          : 'Son 7 günde $recent yeni açık · CISA kataloğu',
      trailing: vulns.isEmpty ? null : '${vulns.length}',
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ThreatsScreen())),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TpCard(
      onTap: onTap,
      semanticLabel: title,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing!, style: context.text.labelLarge?.copyWith(color: context.tp.textSecondary)),
          ],
          Icon(Icons.chevron_right_rounded, color: context.tp.textMuted),
        ],
      ),
    );
  }
}

class _RankedNews extends ConsumerWidget {
  const _RankedNews({required this.rank, required this.item});

  final int rank;
  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Pressable(
      borderRadius: Tp.radiusSmall,
      onTap: () => openNews(context, ref, item),
      semanticLabel: '$rank. ${item.displayTitle}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tp.page, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: Text('$rank', style: context.text.headlineSmall?.copyWith(color: context.tp.primary, fontSize: 22)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryKicker(item.category),
                  const SizedBox(height: 5),
                  Text(item.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontSize: 14.5)),
                  const SizedBox(height: 5),
                  Text('${item.sourceName} · ${Fmt.relative(item.publishedAt)}', style: context.text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              height: 64,
              child: NewsImage(url: item.imageUrl, seed: item.id, category: item.category, borderRadius: BorderRadius.circular(10)),
            ),
          ],
        ),
      ),
    );
  }
}
