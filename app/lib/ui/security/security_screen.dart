import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../news/news_screen.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';

/// Güvenlik Bülteni: CISA'nın "aktif olarak istismar edilen açıklar" kataloğu (KEV).
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _ransomwareOnly = false;

  Future<void> _refresh() async {
    final error = await refreshFeed(ref, Endpoint.security, parseSecurity, () => ref.invalidate(securityProvider));
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = categoryColor(NewsCategory.security, theme.brightness);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text('Güvenlik Bülteni'),
        actions: const [SearchAction(), SettingsAction(), SizedBox(width: 4)],
      ),
      body: FeedView<Vulnerability>(
        value: ref.watch(securityProvider),
        onRetry: () => ref.invalidate(securityProvider),
        builder: (context, snapshot) {
          final all = snapshot.data.items;
          final items = _ransomwareOnly ? all.where((v) => v.ransomware).toList() : all;
          final ransomwareCount = all.where((v) => v.ransomware).length;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length + 3,
              itemBuilder: (context, index) {
                if (index == 0) return StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt);
                if (index == 1) return const _KevIntro();
                if (index == 2) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Row(
                      children: [
                        FilterChip(
                          avatar: Icon(Icons.warning_amber_rounded, size: 16, color: danger),
                          label: Text('Fidye yazılımında kullanılanlar $ransomwareCount'),
                          selected: _ransomwareOnly,
                          showCheckmark: false,
                          selectedColor: danger.withValues(alpha: 0.16),
                          onSelected: (value) => setState(() => _ransomwareOnly = value),
                        ),
                      ],
                    ),
                  );
                }
                return VulnerabilityCard(vuln: items[index - 3]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _KevIntro extends StatelessWidget {
  const _KevIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final danger = categoryColor(NewsCategory.security, theme.brightness);
    return SurfaceCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [danger.withValues(alpha: 0.14), scheme.surfaceContainerLow],
      ),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldırganların şu an kullandığı açıklar', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'ABD Siber Güvenlik ve Altyapı Güvenliği Ajansı (CISA), gerçek saldırılarda kullanıldığı '
                  'doğrulanan açıkları bu katalogda yayımlar. Listede kullandığınız bir ürün varsa güncellemeyi '
                  'ertelemeyin.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VulnerabilityCard extends StatelessWidget {
  const VulnerabilityCard({super.key, required this.vuln});

  final Vulnerability vuln;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final danger = categoryColor(NewsCategory.security, theme.brightness);
    return SurfaceCard(
      onTap: () => showVulnerabilitySheet(context, vuln),
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              children: [
                Text(
                  vuln.cveId,
                  style: theme.textTheme.labelLarge?.copyWith(fontFamily: AppTheme.monoFont, color: danger),
                ),
                const Spacer(),
                if (vuln.ransomware) Pill(label: 'Fidye yazılımı', icon: Icons.warning_amber_rounded, color: danger, filled: true),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(vuln.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 4),
          Text(
            '${vuln.vendor} · ${vuln.product}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [
                    'Eklendi ${Fmt.shortDate(vuln.dateAdded)}',
                    if (vuln.dueDate != null) 'Son tarih ${Fmt.shortDate(vuln.dueDate!)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              BookmarkButton(kind: BookmarkKind.vuln, entry: vuln, compact: true),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showVulnerabilitySheet(BuildContext context, Vulnerability vuln) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _VulnerabilitySheet(vuln: vuln),
  );
}

class _VulnerabilitySheet extends StatelessWidget {
  const _VulnerabilitySheet({required this.vuln});

  final Vulnerability vuln;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final danger = categoryColor(NewsCategory.security, theme.brightness);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(vuln.cveId, style: theme.textTheme.titleMedium?.copyWith(fontFamily: AppTheme.monoFont, color: danger)),
              const Spacer(),
              if (vuln.ransomware) Pill(label: 'Fidye yazılımında kullanıldı', color: danger, filled: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(vuln.displayTitle, style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text('${vuln.vendor} · ${vuln.product}', style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (vuln.description.isNotEmpty) Text(vuln.description, style: theme.textTheme.bodyLarge),
          if (vuln.action.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: danger.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yapılması gereken', style: theme.textTheme.labelLarge?.copyWith(color: danger)),
                  const SizedBox(height: 4),
                  Text(vuln.action, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(label: 'Kataloğa eklendi: ${Fmt.date(vuln.dateAdded)}', icon: Icons.event_outlined, color: scheme.onSurfaceVariant),
              if (vuln.dueDate != null)
                Pill(label: 'Kapatma son tarihi: ${Fmt.date(vuln.dueDate!)}', icon: Icons.schedule, color: scheme.onSurfaceVariant),
              for (final cwe in vuln.cwes) Pill(label: cwe, color: scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: () => openLink(context, vuln.url),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("NVD'de ayrıntılar"),
                ),
              ),
              const SizedBox(width: 8),
              BookmarkButton(kind: BookmarkKind.vuln, entry: vuln),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => openLink(context, 'https://www.cisa.gov/known-exploited-vulnerabilities-catalog'),
            icon: const Icon(Icons.public),
            label: const Text('CISA KEV kataloğu'),
          ),
          const SizedBox(height: 14),
          InfoNote(
            icon: Icons.translate,
            text: vuln.nameTr != null
                ? 'Açıklamalar CISA kataloğundan makine çevirisiyle (açık kaynaklı OPUS-MT modeli) Türkçeye çevrildi. '
                    'Bilgi amaçlıdır; çözüm için üreticinin güvenlik duyurusunu esas alın.'
                : 'Bu kaydın çevirisi henüz hazır değil; CISA kataloğundaki özgün metin gösteriliyor.',
          ),
        ],
      ),
    );
  }
}
