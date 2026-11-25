import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/ranking.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import 'cards.dart';

enum _ListKind { category, topic, source, popular }

/// Filtrelenmiş haber listesi: bir konu, bir etiket, bir kaynak veya popüler haberler.
/// Uzun listeler kaydırdıkça 20'şer haber olarak yüklenir.
class NewsListScreen extends ConsumerStatefulWidget {
  const NewsListScreen.category(TechCategory this.category, {super.key})
      : _kind = _ListKind.category,
        topic = null,
        sourceId = null,
        sourceName = null;

  const NewsListScreen.topic(String this.topic, {super.key})
      : _kind = _ListKind.topic,
        category = null,
        sourceId = null,
        sourceName = null;

  const NewsListScreen.source({super.key, required String this.sourceId, required String this.sourceName})
      : _kind = _ListKind.source,
        category = null,
        topic = null;

  const NewsListScreen.popular({super.key})
      : _kind = _ListKind.popular,
        category = null,
        topic = null,
        sourceId = null,
        sourceName = null;

  final _ListKind _kind;
  final TechCategory? category;
  final String? topic;
  final String? sourceId;
  final String? sourceName;

  @override
  ConsumerState<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends ConsumerState<NewsListScreen> {
  static const _page = 20;
  int _visible = _page;

  String get _title => switch (widget._kind) {
        _ListKind.category => widget.category!.label,
        _ListKind.topic => widget.topic!,
        _ListKind.source => widget.sourceName!,
        _ListKind.popular => 'Öne Çıkanlar',
      };

  String get _subtitle => switch (widget._kind) {
        _ListKind.category => widget.category!.description,
        _ListKind.topic => 'Bu konuyu işleyen haberler',
        _ListKind.source => 'Bu kaynaktan gelen haberler',
        _ListKind.popular => 'Son üç günün en önemli gelişmeleri',
      };

  List<NewsItem> _filter(List<NewsItem> items, DateTime now) => switch (widget._kind) {
        _ListKind.category => items.where((n) => n.category == widget.category).toList(),
        _ListKind.topic => newsWithTopic(items, widget.topic!),
        _ListKind.source => items.where((n) => n.sourceId == widget.sourceId).toList(),
        _ListKind.popular => popularNews(items, now, limit: 30),
      };

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(newsProvider);
    final now = ref.watch(clockProvider)();
    final items = _filter(ref.watch(visibleNewsProvider), now);
    return Scaffold(
      appBar: AppBar(title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FeedView<NewsItem>(
        value: value,
        onRetry: () => ref.invalidate(newsProvider),
        loading: const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: FeedSkeleton(featured: false)),
        builder: (context, snapshot) {
          if (items.isEmpty) {
            return EmptyState(
              icon: widget.category?.icon ?? Icons.article_outlined,
              title: 'Henüz haber yok',
              message: 'Bu listede şu an gösterilecek haber bulunmuyor. Yeni haberler saatte bir eklenir.',
            );
          }
          final shown = items.take(_visible).toList();
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 600 && _visible < items.length) {
                setState(() => _visible += _page);
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: shown.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 8),
                    child: Text('$_subtitle · ${items.length} haber', style: context.text.bodySmall),
                  );
                }
                return ListNewsCard(item: shown[index - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}
