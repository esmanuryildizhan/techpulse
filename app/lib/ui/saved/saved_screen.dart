import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../news/news_card.dart';
import '../news/news_screen.dart';
import '../radar/radar_cards.dart';
import '../security/security_screen.dart';
import '../widgets/state_views.dart';

const _kindLabels = {
  BookmarkKind.news: 'Haberler',
  BookmarkKind.paper: 'Makaleler',
  BookmarkKind.model: 'Modeller',
  BookmarkKind.repo: 'Projeler',
  BookmarkKind.vuln: 'Güvenlik',
};

/// Kaydedilenler: telefonda (SQLite) saklanır, internet olmadan da açılır.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  BookmarkKind? _kind;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(bookmarksProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Kaydedilenler'),
        actions: const [SearchAction(), SettingsAction(), SizedBox(width: 4)],
      ),
      body: value.when(
        loading: () => const LoadingList(count: 3),
        error: (error, _) => MessageView(
          icon: Icons.error_outline,
          title: 'Kaydedilenler okunamadı',
          message: '$error',
          actionLabel: 'Tekrar dene',
          onAction: () => ref.invalidate(bookmarksProvider),
        ),
        data: (records) {
          if (records.isEmpty) {
            return const MessageView(
              icon: Icons.bookmarks_outlined,
              title: 'Henüz bir şey kaydetmediniz',
              message: 'Haber, makale veya modellerdeki yer imi düğmesine dokunun; '
                  'kaydettikleriniz internet olmadan da burada durur.',
            );
          }
          final counts = <BookmarkKind, int>{};
          for (final r in records) {
            counts[r.kind] = (counts[r.kind] ?? 0) + 1;
          }
          final visible = _kind == null ? records : records.where((r) => r.kind == _kind).toList();
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: visible.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    children: [
                      ChoiceChip(
                        showCheckmark: false,
                        label: Text('Tümü ${records.length}'),
                        selected: _kind == null,
                        onSelected: (_) => setState(() => _kind = null),
                      ),
                      for (final kind in BookmarkKind.values)
                        if ((counts[kind] ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: Text('${_kindLabels[kind]} ${counts[kind]}'),
                              selected: _kind == kind,
                              onSelected: (_) => setState(() => _kind = kind),
                            ),
                          ),
                    ],
                  ),
                );
              }
              final record = visible[index - 1];
              final card = _cardFor(record);
              if (card == null) return const SizedBox.shrink();
              return Dismissible(
                key: ValueKey(record.key),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 32),
                  child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                ),
                onDismissed: (_) => _remove(record),
                child: card,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _remove(BookmarkRecord record) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(bookmarksProvider.notifier);
    await notifier.remove(record);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Kaydedilenlerden çıkarıldı'),
          action: SnackBarAction(label: 'Geri al', onPressed: () => notifier.restore(record)),
        ),
      );
  }

  Widget? _cardFor(BookmarkRecord record) {
    try {
      final json = jsonDecode(record.payload) as Map<String, dynamic>;
      return switch (record.kind) {
        BookmarkKind.news => NewsCard(item: NewsItem.fromJson(json)),
        BookmarkKind.paper => PaperCard(paper: Paper.fromJson(json)),
        BookmarkKind.model => ModelCard(model: AiModel.fromJson(json)),
        BookmarkKind.repo => RepoCard(repo: Repo.fromJson(json)),
        BookmarkKind.vuln => VulnerabilityCard(vuln: Vulnerability.fromJson(json)),
      };
    } catch (_) {
      return null;
    }
  }
}
