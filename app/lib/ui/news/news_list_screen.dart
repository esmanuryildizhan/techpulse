import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/ranking.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import 'news_cards.dart';

/// Bir konunun (kategori) veya konu etiketinin haberleri, en yeniden eskiye, gün başlıklarıyla.
class NewsListScreen extends ConsumerWidget {
  const NewsListScreen.category(TechCategory this.category, {super.key}) : topic = null;

  const NewsListScreen.topic(String this.topic, {super.key}) : category = null;

  final TechCategory? category;
  final String? topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final value = ref.watch(newsProvider);
    final all = ref.watch(visibleNewsProvider);
    final now = ref.watch(clockProvider)();
    final items = category != null ? all.where((n) => n.category == category).toList() : newsWithTopic(all, topic!);
    final title = category?.label ?? topic!;
    final subtitle = category?.description ?? 'Bu konu etiketini taşıyan haberler';

    return Scaffold(
      appBar: AppBar(),
      body: FeedView<NewsItem>(
        value: value,
        onRetry: () => ref.invalidate(newsProvider),
        builder: (context, snapshot) => RefreshIndicator(
          onRefresh: () async {
            final error = await refreshNews(ref);
            if (error != null && context.mounted) showMessage(context, error.message);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 8),
                  child: Row(
                    children: [
                      if (category != null) ...[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: category!.tone(context.brightness).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(category!.icon, color: category!.tone(context.brightness)),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(header: true, child: Text(title, style: context.text.headlineSmall)),
                            const SizedBox(height: 2),
                            Text('$subtitle · ${items.length} haber', style: context.text.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Bu konuda yeni haber yok',
                    message: 'Haberler her saat güncellenir. Biraz sonra yeniden bakın.',
                  ),
                )
              else
                ..._grouped(context, items, now, tp),
              SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _grouped(BuildContext context, List<NewsItem> items, DateTime now, TpColors tp) {
    final slivers = <Widget>[];
    String? current;
    final buffer = <NewsItem>[];
    void flush() {
      if (buffer.isEmpty) return;
      final group = List<NewsItem>.of(buffer);
      slivers.add(SliverToBoxAdapter(child: TimeGroupHeader(current!)));
      slivers.add(
        SliverList.separated(
          itemCount: group.length,
          itemBuilder: (context, i) => NewsRow(item: group[i]),
          separatorBuilder: (_, _) => const Divider(indent: Tp.page, endIndent: Tp.page),
        ),
      );
      buffer.clear();
    }

    for (final item in items) {
      final group = timeGroup(item.publishedAt, now);
      if (group != current) {
        flush();
        current = group;
      }
      buffer.add(item);
    }
    flush();
    return slivers;
  }
}

/// "Bugün", "Dün" gibi zaman başlığı.
class TimeGroupHeader extends StatelessWidget {
  const TimeGroupHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tp.page, 20, Tp.page, 4),
      child: Row(
        children: [
          Text(
            trUpper(label),
            style: context.text.labelSmall?.copyWith(
              color: tp.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: tp.border)),
        ],
      ),
    );
  }
}
