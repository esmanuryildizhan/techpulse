import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../state/providers.dart';
import '../saved/record_tile.dart';
import '../widgets/common.dart';

/// Okuma geçmişi: son 90 günde açılan en fazla 200 haber ve makale. Yalnızca bu telefonda saklanır.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final records = ref.watch(historyProvider).value ?? const <BookmarkRecord>[];
    final enabled = ref.watch(settingsProvider.select((s) => s.recordHistory));

    Future<void> clear() async {
      final ok = await confirmAction(
        context,
        title: 'Okuma geçmişi silinsin mi?',
        message:
            'Okuduğunuz içeriklerin listesi bu telefondan silinir. "Sizin İçin" sıralaması da '
            'okuma alışkanlığınızı unutur. Bu işlem geri alınamaz.',
        confirmLabel: 'Geçmişi sil',
      );
      if (!ok) return;
      await ref.read(historyProvider.notifier).clear();
      if (context.mounted) showMessage(context, 'Okuma geçmişi silindi.');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Okuma geçmişi'),
        actions: [
          if (records.isNotEmpty)
            IconButton(tooltip: 'Geçmişi sil', onPressed: clear, icon: const Icon(Icons.delete_sweep_outlined)),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 8),
            child: Text(
              'Son $_days günde okuduğunuz en fazla $historyLimit içerik tutulur; daha eskileri kendiliğinden silinir. '
              'Liste yalnızca bu telefonda saklanır ve "Sizin İçin" sıralamasını size göre ayarlamak için kullanılır.',
              style: context.text.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tp.page - 4),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Okuma geçmişini tut'),
              subtitle: Text(enabled ? 'Açık' : 'Kapalı · yeni okudukları kaydedilmiyor'),
              value: enabled,
              onChanged: (v) => ref.read(settingsProvider.notifier).setRecordHistory(v),
            ),
          ),
          const Divider(),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'Okuma geçmişi boş',
                message: enabled ? 'Açtığınız haberler burada listelenir.' : 'Okuma geçmişi kapalı.',
                compact: true,
              ),
            )
          else
            for (final (i, record) in records.indexed) ...[
              if (i > 0) Divider(indent: Tp.page, endIndent: Tp.page, color: tp.border),
              RecordTile(record: record, timeLabel: 'okundu'),
            ],
        ],
      ),
    );
  }
}

final int _days = historyRetention.inDays;
