import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../navigation.dart';
import '../widgets/common.dart';

/// Akışın arasındaki "Yapay Zekâ Radarı" kartı: bu hafta öne çıkan üç model.
class RadarTeaser extends ConsumerWidget {
  const RadarTeaser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final models = [...?ref.watch(modelsProvider).value?.data.items]..sort((a, b) => a.rank.compareTo(b.rank));
    if (models.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tp.page),
      child: TpCard(
        color: tp.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.radar_rounded, size: 20, color: tp.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Yapay Zekâ Radarı', style: context.text.titleSmall)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Hugging Face\'te bu hafta en çok ilgi gören modeller', style: context.text.bodySmall),
            ),
            const SizedBox(height: 8),
            for (final (i, model) in models.take(3).indexed)
              InkWell(
                onTap: () => openModel(context, model),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontFamily: Tp.serif,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: tp.accent,
                          ),
                        ),
                      ),
                      Icon(model.modality.icon, size: 18, color: tp.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${model.author} · ${model.task}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(),
            InkWell(
              onTap: () => openRadar(ref, RadarSection.models),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Modeller, makaleler ve projeler',
                        style: context.text.labelLarge?.copyWith(color: tp.accent, fontSize: 14),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: tp.accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Akışın arasındaki siber tehdit kartı: CISA'nın son eklediği, aktif olarak istismar edilen açık.
class ThreatTeaser extends ConsumerWidget {
  const ThreatTeaser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final items = [...?ref.watch(securityProvider).value?.data.items]
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    if (items.isEmpty) return const SizedBox.shrink();
    final Vulnerability vuln = items.first;
    final danger = tp.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tp.page),
      child: Material(
        color: danger.withValues(alpha: context.brightness == Brightness.dark ? 0.10 : 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tp.radius),
          side: BorderSide(color: danger.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openVulnerability(context, vuln),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gpp_maybe_outlined, size: 19, color: danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Siber tehdit · aktif saldırı altında',
                        style: context.text.labelMedium?.copyWith(color: danger, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (vuln.ransomware) Pill('Fidye yazılımı', color: danger),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  vuln.displayTitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Tp.headline(context, size: 17),
                ),
                const SizedBox(height: 6),
                Text(
                  '${vuln.vendor} ${vuln.product} · ${vuln.cveId} · ${Fmt.relative(vuln.dateAdded)} listeye eklendi',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => openVulnerability(context, vuln),
                      style: TextButton.styleFrom(
                        foregroundColor: danger,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Ne yapmalı?'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => openRadar(ref, RadarSection.threats),
                      style: TextButton.styleFrom(foregroundColor: tp.textSecondary, minimumSize: const Size(0, 40)),
                      child: Text('Tüm tehditler (${items.length})'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
