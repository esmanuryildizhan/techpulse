import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';

/// Aktif Siber Tehditler: CISA'nın "aktif olarak istismar edilen açıklar" kataloğu (KEV).
class ThreatsScreen extends ConsumerStatefulWidget {
  const ThreatsScreen({super.key});

  @override
  ConsumerState<ThreatsScreen> createState() => _ThreatsScreenState();
}

class _ThreatsScreenState extends ConsumerState<ThreatsScreen> {
  bool _ransomwareOnly = false;

  Future<void> _refresh() async {
    final error = await refreshFeed(ref, Endpoint.security, parseSecurity, () => ref.invalidate(securityProvider));
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final danger = context.tp.danger;
    return Scaffold(
      appBar: AppBar(title: const Text('Aktif Siber Tehditler')),
      body: FeedView<Vulnerability>(
        value: ref.watch(securityProvider),
        onRetry: () => ref.invalidate(securityProvider),
        builder: (context, snapshot) {
          final all = snapshot.data.items;
          final items = _ransomwareOnly ? all.where((v) => v.ransomware).toList() : all;
          final ransomwareCount = all.where((v) => v.ransomware).length;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: items.length + 3,
              separatorBuilder: (context, index) => SizedBox(height: index < 3 ? 0 : 12),
              itemBuilder: (context, index) {
                if (index == 0) return StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt);
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 4),
                    child: InfoBox(
                      icon: Icons.gpp_maybe_outlined,
                      title: 'Saldırganların şu an kullandığı açıklar',
                      tone: danger,
                      child: Text(
                        'ABD Siber Güvenlik ve Altyapı Güvenliği Ajansı (CISA), gerçek saldırılarda kullanıldığı doğrulanan '
                        'açıkları bu katalogda yayımlar. Listede kullandığın bir ürün varsa güncellemeyi ertelememelisin.',
                        style: context.text.bodyMedium,
                      ),
                    ),
                  );
                }
                if (index == 2) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilterChip(
                        avatar: Icon(Icons.lock_outline_rounded, size: 16, color: _ransomwareOnly ? Colors.white : danger),
                        label: Text('Fidye yazılımında kullanılanlar  $ransomwareCount'),
                        selected: _ransomwareOnly,
                        onSelected: (value) => setState(() => _ransomwareOnly = value),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Tp.page),
                  child: VulnerabilityCard(vuln: items[index - 3]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class VulnerabilityCard extends StatelessWidget {
  const VulnerabilityCard({super.key, required this.vuln});

  final Vulnerability vuln;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final due = vuln.dueDate;
    return TpCard(
      onTap: () => showVulnerabilitySheet(context, vuln),
      semanticLabel: '${vuln.cveId}, ${vuln.displayTitle}',
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(vuln.cveId, style: context.text.labelLarge?.copyWith(fontFamily: Tp.monoFont, color: tp.danger, fontSize: 13)),
              if (vuln.ransomware) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: tp.danger.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                  child: Text('Fidye yazılımı', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: tp.danger)),
                ),
              ],
              const Spacer(),
              BookmarkButton(kind: BookmarkKind.vuln, entry: vuln, size: 21),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vuln.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                const SizedBox(height: 6),
                Text(
                  vuln.explanationTr ?? vuln.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  [
                    '${vuln.vendor} · ${vuln.product}',
                    'Eklendi ${Fmt.shortDate(vuln.dateAdded)}',
                    if (due != null) 'Son tarih ${Fmt.shortDate(due)}',
                  ].join('  ·  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              ],
            ),
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
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.94,
      builder: (context, controller) {
        final tp = context.tp;
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 32),
          children: [
            Text(vuln.cveId, style: context.text.labelLarge?.copyWith(fontFamily: Tp.monoFont, color: tp.danger)),
            const SizedBox(height: 8),
            Text(vuln.displayTitle, style: context.text.headlineSmall),
            const SizedBox(height: 6),
            Text('${vuln.vendor} · ${vuln.product}', style: context.text.bodyMedium),
            if (vuln.explanationTr != null) ...[
              const SizedBox(height: 18),
              InfoBox(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Sade dille',
                child: Text(vuln.explanationTr!, style: context.text.bodyMedium?.copyWith(color: tp.textPrimary)),
              ),
            ],
            const SizedBox(height: 18),
            Text('Açıklama', style: context.text.titleSmall),
            const SizedBox(height: 6),
            Text(vuln.description, style: context.text.bodyLarge),
            if (vuln.action.isNotEmpty) ...[
              const SizedBox(height: 18),
              InfoBox(
                icon: Icons.build_circle_outlined,
                title: 'Yapılması gereken',
                tone: tp.warning,
                child: Text(vuln.action, style: context.text.bodyMedium?.copyWith(color: tp.textPrimary)),
              ),
            ],
            const SizedBox(height: 18),
            TpCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row(context, 'Kataloğa eklenme', Fmt.date(vuln.dateAdded)),
                  if (vuln.dueDate != null) _row(context, 'Kamu kurumları için son tarih', Fmt.date(vuln.dueDate!)),
                  _row(context, 'Fidye yazılımında kullanım', vuln.ransomware ? 'Biliniyor' : 'Bilinmiyor'),
                  if (vuln.cwes.isNotEmpty) _row(context, 'Zayıflık türü', vuln.cwes.join(', ')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => openLink(context, vuln.url),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('NVD kaydını aç'),
            ),
            const SizedBox(height: 8),
            Text('Kaynak: CISA Known Exploited Vulnerabilities kataloğu', textAlign: TextAlign.center, style: context.text.bodySmall),
          ],
        );
      },
    ),
  );
}

Widget _row(BuildContext context, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: context.text.titleSmall)),
        ],
      ),
    );
