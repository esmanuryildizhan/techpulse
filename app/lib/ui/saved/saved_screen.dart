import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'record_views.dart';

/// Kaydedilenler: daha sonra okumak için kaydedilen içerikler. Kayıtlar telefondaki SQLite
/// veritabanında tutulur; uygulama kapatılıp açıldığında ve internet yokken de durur.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

/// Filtre: ya bir haber konusu ya da haber dışı bir içerik türü.
typedef _Filter = ({TechCategory? category, BookmarkKind? kind});

class _SavedScreenState extends ConsumerState<SavedScreen> {
  _Filter? _filter;

  bool _matches(_Filter? filter, BookmarkRecord record, Entry entry) {
    if (filter == null) return true;
    if (filter.category != null) return entry is NewsItem && entry.category == filter.category;
    return record.kind == filter.kind;
  }

  Future<void> _remove(BookmarkRecord record) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(bookmarksProvider.notifier).remove(record);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Kaydedilenlerden çıkarıldı'),
          action: SnackBarAction(label: 'Geri al', onPressed: () => ref.read(bookmarksProvider.notifier).restore(record)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(bookmarksProvider);
    final records = value.value ?? const <BookmarkRecord>[];
    final decoded = [
      for (final r in records)
        if (decodeRecord(r) case final entry?) (record: r, entry: entry),
    ];
    final filters = <(_Filter, String)>[
      for (final category in TechCategory.values)
        if (decoded.any((d) => d.entry is NewsItem && (d.entry as NewsItem).category == category))
          ((category: category, kind: null), category.label),
      for (final kind in BookmarkKind.values.where((k) => k != BookmarkKind.news))
        if (decoded.any((d) => d.record.kind == kind)) ((category: null, kind: kind), kind.label),
    ];
    final visible = decoded.where((d) => _matches(_filter, d.record, d.entry)).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ScreenTitle(
              'Kaydedilenler',
              subtitle: 'Daha sonra okumak için kaydettiğin haberler.',
              trailing: decoded.isEmpty
                  ? null
                  : Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: context.tp.primarySoft, borderRadius: BorderRadius.circular(999)),
                      child: Text('${decoded.length} kayıt', style: context.text.labelMedium?.copyWith(color: context.tp.primary)),
                    ),
            ),
          ),
          if (value.isLoading && records.isEmpty)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (decoded.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.bookmark_outline_rounded,
                title: 'Henüz haber kaydetmedin.',
                message: 'Daha sonra okumak istediğin haberleri buraya ekleyebilirsin. Kartlardaki kaydet simgesine dokunman yeterli.',
                actionLabel: 'Haberlere göz at',
                onAction: () => ref.read(appTabProvider.notifier).select(AppTab.home),
              ),
            )
          else ...[
            if (filters.length > 1)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(Tp.page, 12, Tp.page, 4),
                    children: [
                      ChoiceChip(label: const Text('Tümü'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                      for (final (filter, label) in filters)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(label: Text(label), selected: _filter == filter, onSelected: (_) => setState(() => _filter = filter)),
                        ),
                    ],
                  ),
                ),
              ),
            SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (context, index) => Divider(indent: Tp.page, endIndent: Tp.page, color: context.tp.border),
              itemBuilder: (context, index) {
                final item = visible[index];
                return Dismissible(
                  key: ValueKey(item.record.key),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: context.tp.danger.withValues(alpha: 0.16),
                    child: Icon(Icons.delete_outline_rounded, color: context.tp.danger),
                  ),
                  onDismissed: (_) => _remove(item.record),
                  child: RecordRow(record: item.record, entry: item.entry, note: 'Kaydedildi ${Fmt.relative(item.record.savedAt)}'),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Tp.page, 16, Tp.page, 32),
                child: Text(
                  'Kaydı silmek için sola kaydır veya kaydet simgesine yeniden dokun. Kayıtlar bu telefonda saklanır.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
