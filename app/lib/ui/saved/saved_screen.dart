import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import 'record_tile.dart';

/// Kaydedilenler: daha sonra okumak için ayrılan haberler, makaleler, projeler, modeller ve tehditler.
/// İçeriğin tamamı telefonda saklandığı için internetsiz de açılır.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  final _scroll = ScrollController();
  BookmarkKind? _kind;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _clearAll() async {
    final ok = await confirmAction(
      context,
      title: 'Kaydedilenler silinsin mi?',
      message: 'Kaydettiğiniz bütün içerikler bu telefondan silinir. Bu işlem geri alınamaz.',
      confirmLabel: 'Hepsini sil',
    );
    if (!ok || !mounted) return;
    await ref.read(bookmarksProvider.notifier).clear();
    if (mounted) showMessage(context, 'Kaydedilenler silindi.');
  }

  Future<void> _remove(BookmarkRecord record) async {
    await ref.read(bookmarksProvider.notifier).remove(record);
    if (!mounted) return;
    showMessage(
      context,
      'Kaydedilenlerden çıkarıldı.',
      action: SnackBarAction(label: 'Geri al', onPressed: () => ref.read(bookmarksProvider.notifier).restore(record)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopProvider, (_, next) {
      if (next.tab == AppTab.saved && _scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
    final tp = context.tp;
    final value = ref.watch(bookmarksProvider);
    final all = value.value ?? const <BookmarkRecord>[];
    final kinds = [
      for (final k in BookmarkKind.values)
        if (all.any((r) => r.kind == k)) k,
    ];
    final kind = kinds.contains(_kind) ? _kind : null;
    final records = kind == null ? all : all.where((r) => r.kind == kind).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Kaydedilenler',
              subtitle: all.isEmpty ? null : 'İnternet olmadan da okunabilir',
              trailing: all.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hepsini sil',
                      onPressed: _clearAll,
                      icon: Icon(Icons.delete_sweep_outlined, color: tp.textSecondary),
                    ),
            ),
            if (kinds.length > 1)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Tp.page),
                  children: [
                    for (final k in [null, ...kinds])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(k?.pluralLabel ?? 'Tümü'),
                          selected: kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: !value.hasValue
                  ? (value.hasError
                        ? ErrorView(error: value.error!, onRetry: () => ref.invalidate(bookmarksProvider))
                        : const Center(child: CircularProgressIndicator()))
                  : records.isEmpty
                  ? _empty(context)
                  : ListView.separated(
                      controller: _scroll,
                      padding: EdgeInsets.only(top: 8, bottom: 24 + MediaQuery.paddingOf(context).bottom),
                      itemCount: records.length + 1,
                      separatorBuilder: (_, i) =>
                          i == 0 ? const SizedBox.shrink() : const Divider(indent: Tp.page, endIndent: Tp.page),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 4),
                            child: Text('Silmek için sola kaydırın.', style: context.text.labelSmall),
                          );
                        }
                        final record = records[i - 1];
                        return Dismissible(
                          key: ValueKey(record.key),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: tp.danger,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          onDismissed: (_) => _remove(record),
                          child: RecordTile(record: record, timeLabel: 'kaydedildi'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => SingleChildScrollView(
    child: EmptyState(
      icon: Icons.bookmark_border_rounded,
      title: 'Henüz bir şey kaydetmediniz',
      message:
          'Haberlerdeki kaydet simgesine dokunarak daha sonra okumak istediklerinizi burada toplayın. '
          'Kaydedilenler internet olmadan da açılır.',
      action: 'Akışa dön',
      onAction: () => ref.read(appTabProvider.notifier).select(AppTab.home),
    ),
  );
}
