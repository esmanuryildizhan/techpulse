import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// Konu seçimi ızgarası (ilk açılış ve İlgi alanları ekranı).
class InterestGrid extends StatelessWidget {
  const InterestGrid({super.key, required this.selected, required this.onToggle});

  final Set<TechCategory> selected;
  final ValueChanged<TechCategory> onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in TechCategory.values)
              SizedBox(
                width: width,
                child: _InterestTile(category: c, selected: selected.contains(c), onTap: () => onToggle(c)),
              ),
          ],
        );
      },
    );
  }
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({required this.category, required this.selected, required this.onTap});

  final TechCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final tone = category.tone(context.brightness);
    return Semantics(
      selected: selected,
      button: true,
      label: category.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? tp.accentSoft : tp.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tp.radius),
          side: BorderSide(color: selected ? tp.accent : tp.border, width: selected ? 1.6 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(category.icon, size: 19, color: tone),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                        key: ValueKey(selected),
                        size: 22,
                        color: selected ? tp.accent : tp.border,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  category.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  category.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İlgi alanlarını düzenleme. Değişiklikler yalnızca "Kaydet"e basınca uygulanır; kaydetmeden çıkılırsa sorulur.
class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  late final Set<TechCategory> _initial = ref.read(profileProvider).interests.toSet();
  late final Set<TechCategory> _selected = {..._initial};

  bool _leaving = false;

  bool get _dirty => !setEquals(_initial, _selected);

  void _save() {
    ref.read(profileProvider.notifier).setInterests([
      for (final c in TechCategory.values)
        if (_selected.contains(c)) c,
    ]);
    showMessage(
      context,
      _selected.isEmpty
          ? 'Kaydedildi. "Sizin İçin" bütün konuları gösterecek.'
          : 'İlgi alanlarınız kaydedildi; akışınız güncellendi.',
    );
    setState(() => _leaving = true);
    Navigator.of(context).pop();
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmAction(
      context,
      title: 'Değişiklikler kaydedilmedi',
      message: 'Kaydetmeden çıkarsanız yaptığınız seçimler uygulanmaz.',
      confirmLabel: 'Kaydetmeden çık',
    );
    if (leave && mounted) {
      setState(() => _leaving = true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == TechCategory.values.length;
    return PopScope(
      canPop: _leaving || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_leaving) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('İlgi alanları'),
          actions: [
            TextButton(
              onPressed: () => setState(() {
                if (allSelected) {
                  _selected.clear();
                } else {
                  _selected.addAll(TechCategory.values);
                }
              }),
              child: Text(allSelected ? 'Temizle' : 'Tümünü seç'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Tp.page, 4, Tp.page, 24),
          children: [
            Text(
              'Seçtiğiniz konular ana sayfadaki "Sizin İçin" akışını oluşturur. Hiç seçmezseniz bütün konular, '
              'okuma alışkanlığınıza göre sıralanarak gösterilir.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: 18),
            InterestGrid(
              selected: _selected,
              onToggle: (c) => setState(() => _selected.contains(c) ? _selected.remove(c) : _selected.add(c)),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 12),
            child: FilledButton(
              onPressed: _dirty ? _save : null,
              child: Text(_dirty ? 'Kaydet (${_selected.length} konu)' : 'Değişiklik yok'),
            ),
          ),
        ),
      ),
    );
  }
}
