import 'dart:math' as math;

import '../core/categories.dart';
import '../core/formatting.dart';
import '../data/models.dart';
import 'providers.dart';

/// Bir haberin "öne çıkma" puanı. Editörün önem puanı (1-5) temel alınır; Hacker News ilgisi, görselin
/// varlığı, kullanıcının ilgi alanı ve okuma alışkanlığı puanı artırır; haber eskidikçe puan düşer.
double newsScore(
  NewsItem item,
  DateTime now, {
  Set<TechCategory> interests = const {},
  Map<TechCategory, double> affinity = const {},
}) {
  final importance = (item.importance ?? 3).clamp(1, 5);
  final hours = now.difference(item.publishedAt).inMinutes / 60;
  final community = item.points == null ? 0.0 : math.min(12.0, math.log(item.points! + 1) / math.ln2 * 1.4);
  return importance * 10 +
      community +
      (item.imageUrl != null ? 3 : 0) +
      (item.story != null ? 2 : 0) +
      (interests.contains(item.category) ? 4 : 0) +
      (affinity[item.category] ?? 0) * 6 -
      math.max(0, hours) * 0.4;
}

/// Görünüme ve filtrelere göre haber listesi.
///
/// * Sizin İçin: ilgi alanı seçildiyse yalnızca o konular; seçilmediyse hepsi, okuma alışkanlığına göre.
/// * Tüm Gündem: bütün konular.
/// Filtrede konu seçildiyse görünümün konuları yerine tam olarak o konular gösterilir (kullanıcı ne seçtiyse
/// onu görür); zaman aralığı ve sıralama iki görünüme de uygulanır.
List<NewsItem> feedItems(
  List<NewsItem> items,
  DateTime now, {
  required FeedMode mode,
  required FeedFilter filter,
  List<TechCategory> interests = const [],
  Map<TechCategory, double> affinity = const {},
}) {
  final interestSet = interests.toSet();
  Iterable<NewsItem> out = items;
  if (filter.categories.isNotEmpty) {
    out = out.where((n) => filter.categories.contains(n.category));
  } else if (mode == FeedMode.forYou && interestSet.isNotEmpty) {
    out = out.where((n) => interestSet.contains(n.category));
  }
  final range = filter.range.duration;
  if (range != null) out = out.where((n) => now.difference(n.publishedAt) <= range);
  final list = out.toList();
  switch (filter.sort) {
    case FeedSort.newest:
      list.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    case FeedSort.oldest:
      list.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
    case FeedSort.recommended:
      final personal = mode == FeedMode.forYou;
      double score(NewsItem n) =>
          newsScore(n, now, interests: personal ? interestSet : const {}, affinity: personal ? affinity : const {});
      list.sort((a, b) => score(b).compareTo(score(a)));
  }
  return list;
}

/// Ana sayfa düzeni: günün manşeti, "Kısaca" şeridi ve en yeniden eskiye "Son Gelişmeler".
class HomeLayout {
  const HomeLayout({required this.headline, required this.briefs, required this.latest});

  final NewsItem? headline;
  final List<NewsItem> briefs;
  final List<NewsItem> latest;

  bool get isEmpty => headline == null;

  /// [ranked]: önerilen sırada haberler (feedItems çıktısı).
  static HomeLayout build(List<NewsItem> ranked, DateTime now) {
    if (ranked.isEmpty) return const HomeLayout(headline: null, briefs: [], latest: []);
    // Manşet: son 36 saatin en yüksek puanlı, görselli haberi.
    final fresh = ranked.where((n) => now.difference(n.publishedAt) < const Duration(hours: 36)).toList();
    final pool = fresh.isNotEmpty ? fresh : ranked;
    final headline = pool.firstWhere((n) => n.imageUrl != null, orElse: () => pool.first);
    final briefs = ranked.where((n) => n.id != headline.id).take(5).toList();
    final shown = {headline.id, ...briefs.map((n) => n.id)};
    final latest = ranked.where((n) => !shown.contains(n.id)).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return HomeLayout(headline: headline, briefs: briefs, latest: latest);
  }
}

/// Zaman başlıkları: "Son 1 saat", "Bugün", "Dün", "Bu hafta", "Daha önce".
String timeGroup(DateTime time, DateTime now) {
  final local = time.toLocal();
  final current = now.toLocal();
  final diff = current.difference(local);
  if (diff.inMinutes < 60) return 'Son 1 saat';
  final today = DateTime(current.year, current.month, current.day);
  if (!local.isBefore(today)) return 'Bugün';
  if (!local.isBefore(today.subtract(const Duration(days: 1)))) return 'Dün';
  if (!local.isBefore(today.subtract(const Duration(days: 6)))) return 'Bu hafta';
  return 'Daha önce';
}

/// Popüler haberler: editörün önem puanı, topluluk ilgisi (Hacker News puanı) ve tazelik.
/// Kullanıcının ilgi alanından bağımsızdır.
List<NewsItem> popularNews(List<NewsItem> items, DateTime now, {int limit = 5}) {
  final recent = items.where((n) => now.difference(n.publishedAt) < const Duration(hours: 48)).toList();
  final pool = recent.length >= limit ? recent : items;
  return ([...pool]..sort((a, b) => newsScore(b, now).compareTo(newsScore(a, now)))).take(limit).toList();
}

/// Trend konular: son 72 saatte en çok geçen konu etiketleri (önemli haberler daha çok sayılır).
class TrendTopic {
  const TrendTopic(this.label, this.count, this.category);

  final String label;
  final int count;

  /// Bu etiketi taşıyan haberlerin en sık konusu.
  final TechCategory category;
}

List<TrendTopic> trendingTopics(List<NewsItem> items, DateTime now, {int limit = 8}) {
  final weights = <String, double>{};
  final labels = <String, String>{};
  final counts = <String, int>{};
  final categories = <String, Map<TechCategory, int>>{};
  for (final item in items) {
    if (now.difference(item.publishedAt) > const Duration(hours: 72)) continue;
    for (final topic in item.topics) {
      final key = foldForSearch(topic);
      labels.putIfAbsent(key, () => topic);
      counts[key] = (counts[key] ?? 0) + 1;
      weights[key] = (weights[key] ?? 0) + (item.importance ?? 3);
      final byCategory = categories.putIfAbsent(key, () => {});
      byCategory[item.category] = (byCategory[item.category] ?? 0) + 1;
    }
  }
  final keys = weights.keys.toList()..sort((a, b) => weights[b]!.compareTo(weights[a]!));
  return [
    for (final key in keys.take(limit))
      TrendTopic(
        labels[key]!,
        counts[key]!,
        (categories[key]!.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key,
      ),
  ];
}

/// Bir konu etiketini taşıyan haberler.
List<NewsItem> newsWithTopic(List<NewsItem> items, String topic) {
  final key = foldForSearch(topic);
  return items.where((n) => n.topics.any((t) => foldForSearch(t) == key)).toList();
}
