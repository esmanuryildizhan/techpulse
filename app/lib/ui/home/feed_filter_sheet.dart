import 'package:flutter/material.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

/// Ana sayfa filtreleri: konu, zaman aralığı ve sıralama. Değişiklikler "Uygula"ya basınca geçerli olur.
Future<FeedFilter?> showFeedFilterSheet(BuildContext context, FeedFilter current) {
  return showModalBottomSheet<FeedFilter>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FeedFilterSheet(initial: current),
  );
}

class _FeedFilterSheet extends StatefulWidget {
  const _FeedFilterSheet({required this.initial});

  final FeedFilter initial;

  @override
  State<_FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends State<_FeedFilterSheet> {
  late Set<TechCategory> _categories = {...widget.initial.categories};
  late TimeRange _range = widget.initial.range;
  late FeedSort _sort = widget.initial.sort;

  FeedFilter get _filter => FeedFilter(categories: _categories, range: _range, sort: _sort);

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(text, style: context.text.labelMedium),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Tp.page, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Filtrele', style: context.text.titleLarge)),
                  TextButton(
                    onPressed: _filter.isActive
                        ? () => setState(() {
                            _categories = {};
                            _range = TimeRange.any;
                            _sort = FeedSort.recommended;
                          })
                        : null,
                    child: const Text('Sıfırla'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Tp.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title('KONULAR'),
                    Text(
                      _categories.isEmpty
                          ? 'Konu seçmezseniz akışın kendi konuları gösterilir.'
                          : 'Yalnızca seçtiğiniz ${_categories.length} konunun haberleri gösterilir.',
                      style: context.text.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in TechCategory.values)
                          FilterChip(
                            avatar: Icon(
                              c.icon,
                              size: 16,
                              color: _categories.contains(c) ? tp.onAccent : c.tone(context.brightness),
                            ),
                            label: Text(c.shortLabel),
                            selected: _categories.contains(c),
                            onSelected: (on) => setState(() => on ? _categories.add(c) : _categories.remove(c)),
                          ),
                      ],
                    ),
                    title('ZAMAN'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in TimeRange.values)
                          ChoiceChip(
                            label: Text(r.label),
                            selected: _range == r,
                            onSelected: (_) => setState(() => _range = r),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Haberler 30 gün saklanır.', style: context.text.labelSmall),
                    title('SIRALAMA'),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<FeedSort>(
                        showSelectedIcon: false,
                        segments: [for (final s in FeedSort.values) ButtonSegment(value: s, label: Text(s.label))],
                        selected: {_sort},
                        onSelectionChanged: (s) => setState(() => _sort = s.first),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(switch (_sort) {
                      FeedSort.recommended => 'Önem, ilgi alanlarınız ve tazeliğe göre.',
                      FeedSort.newest => 'Yeniden eskiye.',
                      FeedSort.oldest => 'Eskiden yeniye.',
                    }, style: context.text.labelSmall),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.of(context).pop(_filter), child: const Text('Uygula')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
