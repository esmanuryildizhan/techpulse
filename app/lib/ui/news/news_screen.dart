import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import 'news_card.dart';

/// Gündem: resmî bloglar, haber siteleri ve Hacker News'ten Türkçeye çevrilmiş haberler.
class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  NewsCategory _category = NewsCategory.all;

  Future<void> _refresh() async {
    final error = await refreshFeed(ref, Endpoint.news, parseNews, () => ref.invalidate(newsProvider));
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(newsProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const BrandTitle(),
        actions: const [SearchAction(), SettingsAction(), SizedBox(width: 4)],
      ),
      body: FeedView<NewsItem>(
        value: value,
        onRetry: () => ref.invalidate(newsProvider),
        builder: (context, snapshot) {
          final all = snapshot.data.items;
          final counts = <NewsCategory, int>{NewsCategory.all: all.length};
          for (final item in all) {
            counts[item.category] = (counts[item.category] ?? 0) + 1;
          }
          final items = _category == NewsCategory.all ? all : all.where((n) => n.category == _category).toList();
          final showFeatured = _category == NewsCategory.all && items.isNotEmpty;

          return Column(
            children: [
              CategoryBar(
                selected: _category,
                counts: counts,
                onSelected: (category) => setState(() => _category = category),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    key: PageStorageKey('news-${_category.name}'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.isEmpty ? 2 : items.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) return StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt);
                      if (index == 1) {
                        return UpdatedLine(generatedAt: snapshot.data.generatedAt, count: items.length, noun: 'haber');
                      }
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: MessageView(
                            icon: Icons.inbox_outlined,
                            title: 'Bu konuda henüz haber yok',
                            message: 'Veriler saatte bir güncelleniyor.',
                          ),
                        );
                      }
                      final item = items[index - 2];
                      return NewsCard(item: item, featured: showFeatured && index == 2);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 30),
        const SizedBox(width: 10),
        Text(
          'TechPulse',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ],
    );
  }
}

class SearchAction extends StatelessWidget {
  const SearchAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ara',
      icon: const Icon(Icons.search),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SearchScreen())),
    );
  }
}

class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ayarlar',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
    );
  }
}

/// Konu filtreleri: yatay kaydırılan seçim çipleri.
class CategoryBar extends StatelessWidget {
  const CategoryBar({super.key, required this.selected, required this.counts, required this.onSelected});

  final NewsCategory selected;
  final Map<NewsCategory, int> counts;
  final ValueChanged<NewsCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: NewsCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = NewsCategory.values[index];
          final isSelected = category == selected;
          final color = categoryColor(category, theme.brightness);
          final count = counts[category] ?? 0;
          return ChoiceChip(
            showCheckmark: false,
            selected: isSelected,
            onSelected: (_) => onSelected(category),
            avatar: Icon(category.icon, size: 16, color: color),
            label: Text(count > 0 ? '${category.label} $count' : category.label),
            selectedColor: color.withValues(alpha: 0.18),
            side: BorderSide(color: isSelected ? color.withValues(alpha: 0.6) : theme.colorScheme.outlineVariant),
          );
        },
      ),
    );
  }
}
