import 'dart:convert';

import 'package:flutter/material.dart';

/// Veri hattının ürettiği JSON'un Dart karşılıkları (pipeline/src/types.ts ile aynı alan adları).
/// Ayrıştırma hoşgörülüdür: eksik veya hatalı bir alan uygulamayı çökertmez, varsayılan değer alır;
/// zorunlu alanı olmayan kayıt listeden atlanır.

enum NewsCategory {
  all('Tümü', Icons.dashboard_outlined),
  ai('Yapay Zekâ', Icons.auto_awesome_outlined),
  software('Yazılım', Icons.code),
  hardware('Donanım', Icons.memory),
  security('Güvenlik', Icons.shield_outlined),
  industry('Sektör', Icons.business_center_outlined);

  const NewsCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  static NewsCategory fromKey(Object? key) => switch (key) {
        'ai' => NewsCategory.ai,
        'software' => NewsCategory.software,
        'hardware' => NewsCategory.hardware,
        'security' => NewsCategory.security,
        _ => NewsCategory.industry,
      };
}

enum SourceKind {
  official('Resmî blog'),
  news('Haber sitesi'),
  community('Topluluk');

  const SourceKind(this.label);

  final String label;

  static SourceKind fromKey(Object? key) => switch (key) {
        'official' => SourceKind.official,
        'community' => SourceKind.community,
        _ => SourceKind.news,
      };
}

enum Modality {
  text('Dil', Icons.notes),
  vision('Görüntü', Icons.image_outlined),
  audio('Ses', Icons.graphic_eq),
  multimodal('Çok kipli', Icons.hub_outlined),
  other('Diğer', Icons.category_outlined);

  const Modality(this.label, this.icon);

  final String label;
  final IconData icon;

  static Modality fromKey(Object? key) => switch (key) {
        'text' => Modality.text,
        'vision' => Modality.vision,
        'audio' => Modality.audio,
        'multimodal' => Modality.multimodal,
        _ => Modality.other,
      };
}

// ---- Hoşgörülü okuma yardımcıları ----

String _str(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

String? _strOrNull(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_str(value)) ?? 0;
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(_str(value));
}

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;

List<String> _strings(Object? value) =>
    value is List<dynamic> ? value.whereType<String>().where((s) => s.trim().isNotEmpty).toList() : const [];

String _required(Map<String, dynamic> json, String key) {
  final value = _strOrNull(json[key]);
  if (value == null) throw FormatException('Eksik alan: $key');
  return value;
}

String _https(Map<String, dynamic> json, String key) {
  final value = _required(json, key);
  if (!value.startsWith('https://')) throw FormatException('Güvenli olmayan bağlantı: $key');
  return value;
}

String? _httpsOrNull(Object? value) {
  final text = _strOrNull(value);
  return text != null && text.startsWith('https://') ? text : null;
}

/// Her kaydın ortak arayüzü: kayıt etme, arama ve paylaşma bunu kullanır.
abstract interface class Entry {
  String get id;
  String get displayTitle;
  String get url;
  Map<String, dynamic> get raw;
}

class NewsItem implements Entry {
  NewsItem({
    required this.id,
    required this.url,
    required this.sourceId,
    required this.sourceName,
    required this.sourceKind,
    required this.publishedAt,
    required this.titleOriginal,
    required this.excerptOriginal,
    required this.titleTr,
    required this.summaryTr,
    required this.category,
    required this.tags,
    required this.translated,
    required this.points,
    required this.comments,
    required this.discussionUrl,
    required this.raw,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        id: _required(json, 'id'),
        url: _https(json, 'url'),
        sourceId: _required(json, 'sourceId'),
        sourceName: _required(json, 'sourceName'),
        sourceKind: SourceKind.fromKey(json['sourceKind']),
        publishedAt: _date(json['publishedAt']) ?? _date(json['firstSeenAt']) ?? DateTime.now(),
        titleOriginal: _required(json, 'titleOriginal'),
        excerptOriginal: _str(json['excerptOriginal']),
        titleTr: _strOrNull(json['titleTr']),
        summaryTr: _strOrNull(json['summaryTr']),
        category: NewsCategory.fromKey(json['category']),
        tags: _strings(json['tags']),
        translated: json['translated'] == true,
        points: _intOrNull(json['points']),
        comments: _intOrNull(json['comments']),
        discussionUrl: _httpsOrNull(json['discussionUrl']),
        raw: json,
      );

  @override
  final String id;
  @override
  final String url;
  final String sourceId;
  final String sourceName;
  final SourceKind sourceKind;
  final DateTime publishedAt;
  final String titleOriginal;
  final String excerptOriginal;
  final String? titleTr;
  final String? summaryTr;
  final NewsCategory category;
  final List<String> tags;
  final bool translated;
  final int? points;
  final int? comments;
  final String? discussionUrl;
  @override
  final Map<String, dynamic> raw;

  @override
  String get displayTitle => titleTr ?? titleOriginal;

  /// Türkçe özet; yoksa kaynağın İngilizce açıklaması; o da yoksa null.
  String? get displaySummary => summaryTr ?? (excerptOriginal.isEmpty ? null : excerptOriginal);

  bool get hasDifferentOriginal => titleTr != null && titleTr != titleOriginal;
}

class AiModel implements Entry {
  AiModel({
    required this.id,
    required this.author,
    required this.name,
    required this.url,
    required this.pipelineTag,
    required this.task,
    required this.modality,
    required this.likes,
    required this.downloads,
    required this.rank,
    required this.createdAt,
    required this.library,
    required this.license,
    required this.parameters,
    required this.summaryTr,
    required this.raw,
  });

  factory AiModel.fromJson(Map<String, dynamic> json) => AiModel(
        id: _required(json, 'id'),
        author: _required(json, 'author'),
        name: _required(json, 'name'),
        url: _https(json, 'url'),
        pipelineTag: _strOrNull(json['pipelineTag']),
        task: _strOrNull(json['task']) ?? 'Görev belirtilmemiş',
        modality: Modality.fromKey(json['modality']),
        likes: _int(json['likes']),
        downloads: _int(json['downloads']),
        rank: _int(json['rank']),
        createdAt: _date(json['createdAt']),
        library: _strOrNull(json['library']),
        license: _strOrNull(json['license']),
        parameters: _intOrNull(json['parameters']),
        summaryTr: _strOrNull(json['summaryTr']),
        raw: json,
      );

  @override
  final String id;
  final String author;
  final String name;
  @override
  final String url;
  final String? pipelineTag;
  final String task;
  final Modality modality;
  final int likes;
  final int downloads;
  final int rank;
  final DateTime? createdAt;
  final String? library;
  final String? license;
  final int? parameters;
  final String? summaryTr;
  @override
  final Map<String, dynamic> raw;

  @override
  String get displayTitle => name;

  bool isNew([DateTime? now]) =>
      createdAt != null && (now ?? DateTime.now()).difference(createdAt!) < const Duration(days: 14);
}

class Paper implements Entry {
  Paper({
    required this.id,
    required this.url,
    required this.arxivUrl,
    required this.titleOriginal,
    required this.abstractOriginal,
    required this.titleTr,
    required this.summaryTr,
    required this.upvotes,
    required this.comments,
    required this.publishedAt,
    required this.authors,
    required this.githubUrl,
    required this.tags,
    required this.raw,
  });

  factory Paper.fromJson(Map<String, dynamic> json) => Paper(
        id: _required(json, 'id'),
        url: _https(json, 'url'),
        arxivUrl: _httpsOrNull(json['arxivUrl']) ?? _https(json, 'url'),
        titleOriginal: _required(json, 'titleOriginal'),
        abstractOriginal: _str(json['abstractOriginal']),
        titleTr: _strOrNull(json['titleTr']),
        summaryTr: _strOrNull(json['summaryTr']),
        upvotes: _int(json['upvotes']),
        comments: _int(json['comments']),
        publishedAt: _date(json['publishedAt']) ?? DateTime.now(),
        authors: _strings(json['authors']),
        githubUrl: _httpsOrNull(json['githubUrl']),
        tags: _strings(json['tags']),
        raw: json,
      );

  @override
  final String id;
  @override
  final String url;
  final String arxivUrl;
  final String titleOriginal;
  final String abstractOriginal;
  final String? titleTr;
  final String? summaryTr;
  final int upvotes;
  final int comments;
  final DateTime publishedAt;
  final List<String> authors;
  final String? githubUrl;
  final List<String> tags;
  @override
  final Map<String, dynamic> raw;

  @override
  String get displayTitle => titleTr ?? titleOriginal;

  String get authorLine {
    if (authors.isEmpty) return '';
    if (authors.length <= 2) return authors.join(', ');
    return '${authors.first} ve ${authors.length - 1} yazar daha';
  }
}

class Repo implements Entry {
  Repo({
    required this.id,
    required this.owner,
    required this.name,
    required this.url,
    required this.descriptionOriginal,
    required this.descriptionTr,
    required this.language,
    required this.stars,
    required this.forks,
    required this.createdAt,
    required this.topics,
    required this.isAi,
    required this.raw,
  });

  factory Repo.fromJson(Map<String, dynamic> json) => Repo(
        id: _required(json, 'id'),
        owner: _required(json, 'owner'),
        name: _required(json, 'name'),
        url: _https(json, 'url'),
        descriptionOriginal: _str(json['descriptionOriginal']),
        descriptionTr: _strOrNull(json['descriptionTr']),
        language: _strOrNull(json['language']),
        stars: _int(json['stars']),
        forks: _int(json['forks']),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
        topics: _strings(json['topics']),
        isAi: json['isAi'] == true,
        raw: json,
      );

  @override
  final String id;
  final String owner;
  final String name;
  @override
  final String url;
  final String descriptionOriginal;
  final String? descriptionTr;
  final String? language;
  final int stars;
  final int forks;
  final DateTime createdAt;
  final List<String> topics;
  final bool isAi;
  @override
  final Map<String, dynamic> raw;

  @override
  String get displayTitle => id;

  String? get description => descriptionTr ?? (descriptionOriginal.isEmpty ? null : descriptionOriginal);
}

class Vulnerability implements Entry {
  Vulnerability({
    required this.id,
    required this.cveId,
    required this.vendor,
    required this.product,
    required this.nameOriginal,
    required this.descriptionOriginal,
    required this.actionOriginal,
    required this.nameTr,
    required this.descriptionTr,
    required this.actionTr,
    required this.dateAdded,
    required this.dueDate,
    required this.ransomware,
    required this.cwes,
    required this.url,
    required this.raw,
  });

  factory Vulnerability.fromJson(Map<String, dynamic> json) {
    final cve = _required(json, 'cveId');
    return Vulnerability(
      id: _strOrNull(json['id']) ?? cve,
      cveId: cve,
      vendor: _strOrNull(json['vendor']) ?? 'Bilinmiyor',
      product: _strOrNull(json['product']) ?? 'Bilinmiyor',
      nameOriginal: _str(json['nameOriginal']),
      descriptionOriginal: _str(json['descriptionOriginal']),
      actionOriginal: _str(json['actionOriginal']),
      nameTr: _strOrNull(json['nameTr']),
      descriptionTr: _strOrNull(json['descriptionTr']),
      actionTr: _strOrNull(json['actionTr']),
      dateAdded: _date(json['dateAdded']) ?? DateTime.now(),
      dueDate: _date(json['dueDate']),
      ransomware: json['ransomware'] == true,
      cwes: _strings(json['cwes']),
      url: _httpsOrNull(json['nvdUrl']) ?? 'https://nvd.nist.gov/vuln/detail/$cve',
      raw: json,
    );
  }

  @override
  final String id;
  final String cveId;
  final String vendor;
  final String product;
  final String nameOriginal;
  final String descriptionOriginal;
  final String actionOriginal;
  final String? nameTr;
  final String? descriptionTr;
  final String? actionTr;
  final DateTime dateAdded;
  final DateTime? dueDate;
  final bool ransomware;
  final List<String> cwes;
  @override
  final String url;
  @override
  final Map<String, dynamic> raw;

  @override
  String get displayTitle => nameTr ?? (nameOriginal.isEmpty ? cveId : nameOriginal);

  String get description => descriptionTr ?? descriptionOriginal;

  String get action => actionTr ?? actionOriginal;
}

class SourceStatus {
  SourceStatus({
    required this.id,
    required this.name,
    required this.kind,
    required this.homepage,
    required this.ok,
    required this.count,
    required this.error,
  });

  factory SourceStatus.fromJson(Map<String, dynamic> json) => SourceStatus(
        id: _required(json, 'id'),
        name: _required(json, 'name'),
        kind: _str(json['kind']),
        homepage: _httpsOrNull(json['homepage']),
        ok: json['ok'] == true,
        count: _int(json['count']),
        error: _strOrNull(json['error']),
      );

  final String id;
  final String name;
  final String kind;
  final String? homepage;
  final bool ok;
  final int count;
  final String? error;
}

class FeedMeta {
  FeedMeta({
    required this.generatedAt,
    required this.translatorModel,
    required this.pendingTranslations,
    required this.sources,
  });

  factory FeedMeta.fromJson(Map<String, dynamic> json) {
    final translator = json['translator'];
    final sources = json['sources'];
    return FeedMeta(
      generatedAt: _date(json['generatedAt']),
      translatorModel: translator is Map<String, dynamic> ? _strOrNull(translator['model']) : null,
      pendingTranslations: translator is Map<String, dynamic> ? _int(translator['pendingItems']) : 0,
      sources: sources is List<dynamic>
          ? [
              for (final s in sources)
                if (s is Map<String, dynamic>) ...?_tryParse(() => SourceStatus.fromJson(s)),
            ]
          : const [],
    );
  }

  final DateTime? generatedAt;
  final String? translatorModel;
  final int pendingTranslations;
  final List<SourceStatus> sources;
}

List<T>? _tryParse<T>(T Function() parse) {
  try {
    return [parse()];
  } catch (_) {
    return null;
  }
}

/// Bir uç noktanın içeriği: üretilme zamanı ve kayıtlar.
class Feed<T> {
  const Feed({required this.generatedAt, required this.items});

  final DateTime? generatedAt;
  final List<T> items;

  /// `{"schemaVersion":1,"generatedAt":"…","items":[…]}` biçimini ayrıştırır.
  /// Ayrıştırılamayan tek tek kayıtlar atlanır; zarfın kendisi bozuksa hata fırlatır.
  static Feed<T> parse<T>(String body, T Function(Map<String, dynamic>) fromJson) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Beklenmeyen veri biçimi');
    final items = decoded['items'];
    if (items is! List<dynamic>) throw const FormatException('Kayıt listesi bulunamadı');
    final parsed = <T>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      try {
        parsed.add(fromJson(item));
      } catch (_) {
        // Hatalı tek bir kayıt bütün listeyi bozmasın.
      }
    }
    return Feed(generatedAt: _date(decoded['generatedAt']), items: parsed);
  }
}

FeedMeta parseMeta(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) throw const FormatException('Beklenmeyen veri biçimi');
  return FeedMeta.fromJson(decoded);
}
