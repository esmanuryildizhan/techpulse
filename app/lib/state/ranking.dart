import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/categories.dart';
import '../core/formatting.dart';
import '../data/models.dart';
import 'providers.dart';

/// Bir haberin "öne çıkma" puanı. Editörün önem puanı (1-5) temel alınır; Hacker News ilgisi, görselin
/// varlığı ve kullanıcının ilgi alanı puanı artırır; haber eskidikçe puan düşer.
double newsScore(NewsItem item, DateTime now, {Set<TechCategory> interests = const {}}) {
  final importance = (item.importance ?? 3).clamp(1, 5);
  final hours = now.difference(item.publishedAt).inMinutes / 60;
  final community = item.points == null ? 0.0 : math.min(12.0, math.log(item.points! + 1) / math.ln2 * 1.4);
  return importance * 10 +
      community +
      (item.imageUrl != null ? 3 : 0) +
      (item.aiWritten ? 2 : 0) +
      (interests.contains(item.category) ? 4 : 0) -
      math.max(0, hours) * 0.4;
}

/// Ana sayfa düzeni: bir öne çıkan haber, dört "Öne Çıkanlar" haberi ve kalanlar (en yeniden eskiye).
class HomeLayout {
  const HomeLayout({required this.featured, required this.highlights, required this.latest});

  final NewsItem? featured;
  final List<NewsItem> highlights;
  final List<NewsItem> latest;

  bool get isEmpty => featured == null;

  static HomeLayout build(List<NewsItem> items, DateTime now, {Set<TechCategory> interests = const {}}) {
    if (items.isEmpty) return const HomeLayout(featured: null, highlights: [], latest: []);
    final recent = items.where((n) => now.difference(n.publishedAt) < const Duration(hours: 72)).toList();
    final pool = recent.length >= 5 ? recent : items;
    final ranked = [...pool]..sort((a, b) => newsScore(b, now, interests: interests).compareTo(newsScore(a, now, interests: interests)));
    final featured = ranked.firstWhere((n) => n.imageUrl != null, orElse: () => ranked.first);
    final highlights = ranked.where((n) => n.id != featured.id).take(4).toList();
    final shown = {featured.id, ...highlights.map((n) => n.id)};
    return HomeLayout(
      featured: featured,
      highlights: highlights,
      latest: items.where((n) => !shown.contains(n.id)).toList(),
    );
  }
}

/// Son 72 saatin en popüler haberleri (ilgi alanından bağımsız).
List<NewsItem> popularNews(List<NewsItem> items, DateTime now, {int limit = 10}) {
  final recent = items.where((n) => now.difference(n.publishedAt) < const Duration(hours: 72)).toList();
  final pool = recent.length >= limit ? recent : items;
  return ([...pool]..sort((a, b) => newsScore(b, now).compareTo(newsScore(a, now)))).take(limit).toList();
}

/// Trend konular: son 72 saatte en çok geçen konu etiketleri (önemli haberler daha çok sayılır).
class TrendTopic {
  const TrendTopic(this.label, this.count);

  final String label;
  final int count;
}

List<TrendTopic> trendingTopics(List<NewsItem> items, DateTime now, {int limit = 12}) {
  final weights = <String, double>{};
  final labels = <String, String>{};
  final counts = <String, int>{};
  for (final item in items) {
    if (now.difference(item.publishedAt) > const Duration(hours: 72)) continue;
    for (final topic in item.topics) {
      final key = foldForSearch(topic);
      labels.putIfAbsent(key, () => topic);
      counts[key] = (counts[key] ?? 0) + 1;
      weights[key] = (weights[key] ?? 0) + (item.importance ?? 3);
    }
  }
  final keys = weights.keys.toList()..sort((a, b) => weights[b]!.compareTo(weights[a]!));
  return [for (final key in keys.take(limit)) TrendTopic(labels[key]!, counts[key]!)];
}

/// Bir konu etiketini taşıyan haberler.
List<NewsItem> newsWithTopic(List<NewsItem> items, String topic) {
  final key = foldForSearch(topic);
  return items.where((n) => n.topics.any((t) => foldForSearch(t) == key)).toList();
}

// ---------------------------------------------------------------------------
// Yenilikler (zil simgesi): son bakıştan bu yana kullanıcıyı ilgilendiren gelişmeler
// ---------------------------------------------------------------------------

sealed class UpdateEntry {
  const UpdateEntry(this.time);

  final DateTime time;
}

class NewsUpdate extends UpdateEntry {
  NewsUpdate(this.item, this.reason) : super(item.publishedAt);

  final NewsItem item;

  /// "İlgi alanın: Yapay Zekâ" veya "Önemli gelişme"
  final String reason;
}

class ThreatUpdate extends UpdateEntry {
  ThreatUpdate(this.vulnerability) : super(vulnerability.dateAdded);

  final Vulnerability vulnerability;
}

/// Yenilikler listesi ve okunmamış sayısı. İlk açılışta son 24 saat gösterilir.
class Updates {
  const Updates(this.entries, this.unseen);

  final List<UpdateEntry> entries;
  final int unseen;
}

final updatesProvider = Provider<Updates>((ref) {
  final profile = ref.watch(profileProvider);
  final now = ref.watch(clockProvider)();
  final news = ref.watch(visibleNewsProvider);
  final vulns = ref.watch(securityProvider).value?.data.items ?? const <Vulnerability>[];
  final since = now.subtract(const Duration(days: 2));
  final seenAt = profile.updatesSeenAt ?? now.subtract(const Duration(hours: 24));
  final interests = profile.interests.toSet();

  final entries = <UpdateEntry>[];
  for (final item in news) {
    if (item.publishedAt.isBefore(since)) continue;
    if (profile.notifyImportant && (item.importance ?? 0) >= 4) {
      entries.add(NewsUpdate(item, 'Önemli gelişme'));
    } else if (profile.notifyInterests && interests.contains(item.category)) {
      entries.add(NewsUpdate(item, 'İlgi alanın: ${item.category.label}'));
    }
  }
  if (profile.notifyThreats) {
    for (final v in vulns) {
      if (!v.dateAdded.isBefore(DateTime(since.year, since.month, since.day))) entries.add(ThreatUpdate(v));
    }
  }
  entries.sort((a, b) => b.time.compareTo(a.time));
  final unseen = entries.where((e) => e is NewsUpdate ? e.item.publishedAt.isAfter(seenAt) : e.time.isAfter(seenAt)).length;
  return Updates(entries.take(60).toList(), unseen);
});
