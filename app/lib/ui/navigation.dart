import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/categories.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import 'news/news_detail_screen.dart';
import 'news/news_list_screen.dart';
import 'radar/radar_details.dart';
import 'search/search_screen.dart';

/// Ekranlar arası geçişler tek yerde: her ekran hedefin kurucusunu bilmek zorunda kalmaz.

Future<void> _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

Future<void> openNews(BuildContext context, NewsItem item) => _push(context, NewsDetailScreen(item: item));

Future<void> openPaper(BuildContext context, Paper paper) => _push(context, PaperDetailScreen(paper: paper));

Future<void> openRepo(BuildContext context, Repo repo) => _push(context, RepoDetailScreen(repo: repo));

Future<void> openModel(BuildContext context, AiModel model) => _push(context, ModelDetailScreen(model: model));

Future<void> openVulnerability(BuildContext context, Vulnerability vuln) =>
    _push(context, VulnerabilityDetailScreen(vuln: vuln));

Future<void> openCategory(BuildContext context, TechCategory category) =>
    _push(context, NewsListScreen.category(category));

Future<void> openTopic(BuildContext context, String topic) => _push(context, NewsListScreen.topic(topic));

Future<void> openSearch(BuildContext context) => _push(context, const SearchScreen());

/// Kaydedilenler ve okuma geçmişindeki bir kaydı açar. Kayıt, çevrimdışı da açılabilsin diye içeriğin
/// tamamını taşır. Okunamazsa false döner.
bool openRecord(BuildContext context, BookmarkRecord record) {
  final entry = entryFromRecord(record);
  switch (entry) {
    case NewsItem():
      openNews(context, entry);
    case Paper():
      openPaper(context, entry);
    case Repo():
      openRepo(context, entry);
    case AiModel():
      openModel(context, entry);
    case Vulnerability():
      openVulnerability(context, entry);
    default:
      return false;
  }
  return true;
}

/// Kaydın JSON'unu ilgili modele çevirir; bozuksa null.
Entry? entryFromRecord(BookmarkRecord record) {
  try {
    final json = jsonDecode(record.payload);
    if (json is! Map<String, dynamic>) return null;
    return switch (record.kind) {
      BookmarkKind.news => NewsItem.fromJson(json),
      BookmarkKind.paper => Paper.fromJson(json),
      BookmarkKind.repo => Repo.fromJson(json),
      BookmarkKind.model => AiModel.fromJson(json),
      BookmarkKind.vuln => Vulnerability.fromJson(json),
    };
  } catch (_) {
    return null;
  }
}
