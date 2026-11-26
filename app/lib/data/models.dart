import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/categories.dart';

/// Veri hattının ürettiği JSON'un Dart karşılıkları (pipeline/src/types.ts ile aynı alan adları).
/// Ayrıştırma hoşgörülüdür: eksik veya hatalı bir alan uygulamayı çökertmez, varsayılan değer alır;
/// zorunlu alanı olmayan kayıt listeden atlanır.

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

  /// Kart ve ayrıntı ekranındaki görsel (yoksa konuya özel kapak çizilir).
  String? get imageUrl;
  Map<String, dynamic> get raw;
}

/// "Önce bunu bil" kutusundaki terim açıklaması.
class Primer {
  const Primer(this.term, this.explanation);

  final String term;
  final String explanation;
}

class ArticleSection {
  const ArticleSection(this.heading, this.body);

  final String heading;

  /// Paragraflar boş satırla ayrılmıştır.
  final String body;

  List<String> get paragraphs =>
      body.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
}

/// Yapay zekâ editörünün kaynak haberden yazdığı özgün Türkçe anlatım.
class Article {
  const Article({required this.intro, required this.primer, required this.sections});

  final String intro;
  final List<Primer> primer;
  final List<ArticleSection> sections;

  static Article? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final intro = _strOrNull(value['intro']);
    final sections = <ArticleSection>[
      if (value['sections'] case final List<dynamic> list)
        for (final s in list)
          if (s is Map<String, dynamic> && _strOrNull(s['heading']) != null && _strOrNull(s['body']) != null)
            ArticleSection(_strOrNull(s['heading'])!, _strOrNull(s['body'])!),
    ];
    if (intro == null || sections.isEmpty) return null;
    return Article(
      intro: intro,
      sections: sections,
      primer: [
        if (value['primer'] case final List<dynamic> list)
          for (final p in list)
            if (p is Map<String, dynamic> && _strOrNull(p['term']) != null && _strOrNull(p['explanation']) != null)
              Primer(_strOrNull(p['term'])!, _strOrNull(p['explanation'])!),
      ],
    );
  }
}

/// Metindeki altı çizili kavrama dokununca açılan sade açıklama. Boş alanlar gösterilmez.
class GlossaryEntry {
  const GlossaryEntry({
    required this.term,
    required this.definition,
    this.analogy = '',
    this.usage = '',
    this.origin = '',
  });

  final String term;

  /// Nedir?
  final String definition;

  /// Günlük hayattan benzetme.
  final String analogy;

  /// Nerede, ne için kullanılır?
  final String usage;

  /// Kim geliştirdi, nereden çıktı?
  final String origin;

  static GlossaryEntry? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final term = _strOrNull(value['term']);
    final definition = _strOrNull(value['definition']) ?? _strOrNull(value['explanation']);
    if (term == null || definition == null) return null;
    return GlossaryEntry(
      term: term,
      definition: definition,
      analogy: _str(value['analogy']).trim(),
      usage: _str(value['usage']).trim(),
      origin: _str(value['origin']).trim(),
    );
  }
}

/// Bir anlatım seviyesi: giriş ve bölümler.
class StoryVersion {
  const StoryVersion({required this.intro, required this.sections});

  final String intro;
  final List<ArticleSection> sections;

  int get wordCount => [
    intro,
    for (final s in sections) '${s.heading} ${s.body}',
  ].join(' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  static StoryVersion? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final intro = _strOrNull(value['intro']);
    final sections = _sections(value['sections']);
    if (intro == null || sections.isEmpty) return null;
    return StoryVersion(intro: intro, sections: sections);
  }
}

List<ArticleSection> _sections(Object? value) => [
  if (value is List<dynamic>)
    for (final s in value)
      if (s is Map<String, dynamic> && _strOrNull(s['heading']) != null && _strOrNull(s['body']) != null)
        ArticleSection(_strOrNull(s['heading'])!, _strOrNull(s['body'])!),
];

/// Haberin iki seviyeli anlatımı: "30 saniyede", "neden önemli", sade ve teknik anlatım, kavramlar.
class Story {
  const Story({
    required this.tldr,
    required this.why,
    required this.simple,
    required this.technical,
    required this.glossary,
    required this.fromExcerpt,
  });

  /// "30 saniyede" maddeleri (eski biçimdeki kayıtlarda boş).
  final List<String> tldr;

  /// "Bu gelişme neden önemli?" (eski biçimdeki kayıtlarda boş).
  final String why;
  final StoryVersion simple;

  /// Teknik derinlik; kaynak yeterli ayrıntı vermiyorsa null.
  final StoryVersion? technical;
  final List<GlossaryEntry> glossary;

  /// Anlatım haberin tam metnine değil, yalnızca kaynağın kısa açıklamasına dayanıyor.
  final bool fromExcerpt;

  static Story? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final simple = StoryVersion.fromJson(value['simple']);
    if (simple == null) return null;
    return Story(
      tldr: _strings(value['tldr']),
      why: _str(value['why']).trim(),
      simple: simple,
      technical: StoryVersion.fromJson(value['technical']),
      glossary: [
        if (value['glossary'] case final List<dynamic> list)
          for (final g in list) ?GlossaryEntry.fromJson(g),
      ],
      fromExcerpt: value['basis'] == 'excerpt',
    );
  }

  /// Önceki biçimde (article) yazılmış haberler aynı ekranda gösterilebilsin diye.
  static Story fromArticle(Article article) => Story(
    tldr: const [],
    why: '',
    simple: StoryVersion(intro: article.intro, sections: article.sections),
    technical: null,
    glossary: [for (final p in article.primer) GlossaryEntry(term: p.term, definition: p.explanation)],
    fromExcerpt: false,
  );
}

/// GitHub projesinin README'ye dayanan kısa tanıtımı.
class RepoStory {
  const RepoStory({
    required this.what,
    required this.why,
    required this.useCases,
    required this.audience,
    required this.caution,
    required this.fromReadme,
  });

  final String what;
  final String why;
  final List<String> useCases;
  final String audience;
  final String caution;
  final bool fromReadme;

  static RepoStory? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final what = _strOrNull(value['what']);
    final why = _strOrNull(value['why']);
    if (what == null || why == null) return null;
    return RepoStory(
      what: what,
      why: why,
      useCases: _strings(value['useCases']),
      audience: _str(value['audience']).trim(),
      caution: _str(value['caution']).trim(),
      fromReadme: value['basis'] == 'readme',
    );
  }
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
    required this.imageUrl,
    required this.story,
    required this.topics,
    required this.importance,
    required this.readingMinutes,
    required this.aiWritten,
    required this.hidden,
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
    category: TechCategory.fromKey(json['category']),
    tags: _strings(json['tags']),
    translated: json['translated'] == true,
    points: _intOrNull(json['points']),
    comments: _intOrNull(json['comments']),
    discussionUrl: _httpsOrNull(json['discussionUrl']),
    imageUrl: _httpsOrNull(json['imageUrl']),
    story: Story.fromJson(json['story']) ?? _storyFromArticle(json['article']),
    topics: _strings(json['topics']),
    importance: _intOrNull(json['importance']),
    readingMinutes: _intOrNull(json['readingMinutes']),
    aiWritten: json['writer'] == 'ai',
    hidden: json['hidden'] == true,
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
  final TechCategory category;
  final List<String> tags;
  final bool translated;
  final int? points;
  final int? comments;
  final String? discussionUrl;
  @override
  final String? imageUrl;

  /// Editörün anlatımı; makine çevirisinde ve henüz yazılmamış haberde null.
  final Story? story;
  final List<String> topics;
  final int? importance;
  final int? readingMinutes;

  /// Türkçe metni yapay zekâ editörü mü yazdı (yoksa makine çevirisi ya da henüz çevrilmemiş)?
  final bool aiWritten;

  /// Editör teknolojiyle ilgisiz bulduysa gösterilmez.
  final bool hidden;
  @override
  final Map<String, dynamic> raw;

  @override
  String get displayTitle => titleTr ?? titleOriginal;

  /// Okuma süresi: editörün verdiği değer, yoksa metin uzunluğundan tahmin.
  int get minutes => readingMinutes ?? 1;

  /// Türkçe özet; yoksa kaynağın İngilizce açıklaması; o da yoksa null.
  String? get displaySummary => summaryTr ?? (excerptOriginal.isEmpty ? null : excerptOriginal);

  bool get hasDifferentOriginal => titleTr != null && titleTr != titleOriginal;

  /// Kaynağın internet adresindeki alan adı (ör. "techcrunch.com").
  String get domain => hostOf(url);

  /// Hacker News puanları uygulamaya değil Hacker News topluluğuna aittir; bu yüzden kaynağıyla yazılır.
  String? get communityLabel {
    if (points == null) return null;
    final c = comments ?? 0;
    return "Hacker News'te $points puan · $c yorum";
  }
}

Story? _storyFromArticle(Object? value) {
  final article = Article.fromJson(value);
  return article == null ? null : Story.fromArticle(article);
}

/// "https://www.example.com/a/b" → "example.com"
String hostOf(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host.startsWith('www.') ? host.substring(4) : host;
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
    required this.highlights,
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
    highlights: _strings(json['highlights']),
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
  final List<String> highlights;
  @override
  final Map<String, dynamic> raw;

  @override
  String get displayTitle => name;

  @override
  String? get imageUrl => null;

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
    required this.imageUrl,
    required this.article,
    required this.topics,
    required this.readingMinutes,
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
    imageUrl: _httpsOrNull(json['imageUrl']),
    article: Article.fromJson(json['article']),
    topics: _strings(json['topics']),
    readingMinutes: _intOrNull(json['readingMinutes']),
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
  final String? imageUrl;
  final Article? article;
  final List<String> topics;
  final int? readingMinutes;
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
    required this.imageUrl,
    required this.story,
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
    imageUrl: _httpsOrNull(json['imageUrl']),
    story: RepoStory.fromJson(json['story']),
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
  final String? imageUrl;

  /// README'ye dayanan kısa tanıtım; henüz yazılmadıysa null.
  final RepoStory? story;
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
    required this.explanationTr,
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
      explanationTr: _strOrNull(json['explanationTr']),
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

  /// Açığın sade dille anlatımı (yapay zekâ editörü).
  final String? explanationTr;
  @override
  final Map<String, dynamic> raw;

  @override
  String get displayTitle => nameTr ?? (nameOriginal.isEmpty ? cveId : nameOriginal);

  @override
  String? get imageUrl => null;

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
    required this.editorModel,
    required this.pendingTranslations,
    required this.sources,
  });

  factory FeedMeta.fromJson(Map<String, dynamic> json) {
    final translator = json['translator'];
    final editor = json['editor'];
    final sources = json['sources'];
    return FeedMeta(
      generatedAt: _date(json['generatedAt']),
      translatorModel: translator is Map<String, dynamic> ? _strOrNull(translator['model']) : null,
      editorModel: editor is Map<String, dynamic> ? _strOrNull(editor['model']) : null,
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
  final String? editorModel;
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
