import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../state/ranking.dart';
import '../news/news_detail_screen.dart';
import '../profile/profile_pages.dart';
import '../threats/threats_screen.dart';
import '../widgets/common.dart';
import '../widgets/news_image.dart';

/// Yenilikler (zil simgesi): ilgi alanlarındaki yeni haberler, önemli gelişmeler ve yeni siber tehditler.
/// Ekran açıldığında son bakış zamanı güncellenir ve okunmamış sayısı sıfırlanır.
class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  late final DateTime? _previousSeen = ref.read(profileProvider).updatesSeenAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(profileProvider.notifier).markUpdatesSeen();
    });
  }

  bool _isNew(UpdateEntry entry) {
    final seen = _previousSeen;
    if (seen == null) return true;
    return entry.time.isAfter(seen);
  }

  @override
  Widget build(BuildContext context) {
    final updates = ref.watch(updatesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yenilikler'),
        actions: [
          IconButton(
            tooltip: 'Bildirim ayarları',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen())),
          ),
        ],
      ),
      body: updates.entries.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Şimdilik yenilik yok',
              message: 'İlgi alanlarındaki yeni haberler, önemli gelişmeler ve yeni siber tehditler burada toplanır.',
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 32, top: 4),
              itemCount: updates.entries.length,
              separatorBuilder: (context, index) => Divider(indent: Tp.page, endIndent: Tp.page, color: context.tp.border),
              itemBuilder: (context, index) {
                final entry = updates.entries[index];
                final fresh = _isNew(entry);
                return switch (entry) {
                  NewsUpdate(:final item, :final reason) => _Row(
                      fresh: fresh,
                      leading: NewsImage(url: item.imageUrl, seed: item.id, category: item.category, borderRadius: BorderRadius.circular(12)),
                      label: reason,
                      title: item.displayTitle,
                      meta: '${item.sourceName} · ${Fmt.relative(item.publishedAt)}',
                      onTap: () => openNews(context, ref, item),
                    ),
                  ThreatUpdate(:final vulnerability) => _Row(
                      fresh: fresh,
                      leading: Container(
                        decoration: BoxDecoration(color: context.tp.danger.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.gpp_maybe_outlined, color: context.tp.danger),
                      ),
                      label: 'Yeni siber tehdit · ${vulnerability.cveId}',
                      title: vulnerability.displayTitle,
                      meta: '${vulnerability.vendor} · ${Fmt.shortDate(vulnerability.dateAdded)}',
                      onTap: () => showVulnerabilitySheet(context, vulnerability),
                    ),
                };
              },
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.fresh, required this.leading, required this.label, required this.title, required this.meta, required this.onTap});

  final bool fresh;
  final Widget leading;
  final String label;
  final String title;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tp.page, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 56, height: 56, child: leading),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (fresh) ...[
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: tp.primary, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                      ],
                      Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(color: tp.primary))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  const SizedBox(height: 4),
                  Text(meta, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
