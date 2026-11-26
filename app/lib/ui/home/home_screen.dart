import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../../state/ranking.dart';
import '../navigation.dart';
import '../news/news_cards.dart';
import '../news/news_list_screen.dart';
import '../profile/interests_screen.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import 'feed_filter_sheet.dart';
import 'feed_inserts.dart';

/// Ana sayfa (Akış). Sırası, kullanıcıyı ilk haberde bırakmayacak biçimde kuruldu:
/// selam → görünüm ve filtre → günün manşeti → "Kısaca" şeridi → zamana göre "Son gelişmeler"
/// (aralara Radar ve siber tehdit kartları serpiştirilir) → akışın sonu.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  /// Logoya dokunmak: sayfa aşağıdaysa başa döner, zaten baştaysa haberleri yeniler.
  void _onLogoTap() {
    if (_scroll.hasClients && _scroll.offset > 8) {
      _toTop();
    } else if (_refreshKey.currentState != null) {
      _refreshKey.currentState!.show();
    } else {
      // Haberler henüz yüklenmediyse (ör. hata ekranında) yeniden dener.
      ref.invalidate(newsProvider);
    }
  }

  Future<void> _refresh() async {
    final error = await refreshNews(ref);
    if (error != null && mounted) showMessage(context, error.message);
  }

  Future<void> _openFilter() async {
    final current = ref.read(homeFeedProvider).filter;
    final next = await showFeedFilterSheet(context, current);
    if (next != null) {
      ref.read(homeFeedProvider.notifier).setFilter(next);
      _toTop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(scrollToTopProvider, (_, next) {
      if (next.tab == AppTab.home) _toTop();
    });
    final value = ref.watch(newsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FeedView<NewsItem>(
          value: value,
          onRetry: () => ref.invalidate(newsProvider),
          header: _TopBar(onLogoTap: _onLogoTap),
          loading: const FeedSkeleton(),
          builder: (context, snapshot) => RefreshIndicator(
            key: _refreshKey,
            onRefresh: _refresh,
            child: _Feed(controller: _scroll, snapshot: snapshot, onLogoTap: _onLogoTap, onOpenFilter: _openFilter),
          ),
        ),
      ),
    );
  }
}

/// Akıştaki bir satır: zaman başlığı, haber veya ara kart.
sealed class _Entry {
  const _Entry();
}

class _Header extends _Entry {
  const _Header(this.label);
  final String label;
}

class _News extends _Entry {
  const _News(this.item);
  final NewsItem item;
}

class _RadarInsert extends _Entry {
  const _RadarInsert();
}

class _ThreatInsert extends _Entry {
  const _ThreatInsert();
}

class _Feed extends ConsumerWidget {
  const _Feed({required this.controller, required this.snapshot, required this.onLogoTap, required this.onOpenFilter});

  final ScrollController controller;
  final Snapshot<Feed<NewsItem>> snapshot;
  final VoidCallback onLogoTap;
  final VoidCallback onOpenFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final now = ref.watch(clockProvider)();
    final profile = ref.watch(profileProvider);
    final affinity = ref.watch(readingAffinityProvider);
    final state = ref.watch(homeFeedProvider);
    final all = ref.watch(visibleNewsProvider);
    final feed = feedItems(
      all,
      now,
      mode: state.mode,
      filter: state.filter,
      interests: profile.interests,
      affinity: affinity,
    );
    final filtered = state.filter.isActive;
    final layout = filtered ? null : HomeLayout.build(feed, now);
    final headline = layout?.headline;
    final briefs = layout?.briefs ?? const <NewsItem>[];
    final freshCount = all.where((n) => now.difference(n.publishedAt) < const Duration(hours: 24)).length;
    final forYouWithoutInterests = state.mode == FeedMode.forYou && profile.interests.isEmpty;

    final entries = <_Entry>[];
    final list = layout?.latest ?? feed;
    final grouped = !filtered || state.filter.sort != FeedSort.recommended;
    String? group;
    for (final (i, item) in list.indexed) {
      if (grouped) {
        final label = timeGroup(item.publishedAt, now);
        if (label != group) {
          entries.add(_Header(label));
          group = label;
        }
      }
      entries.add(_News(item));
      if (!filtered && i == 3) entries.add(const _RadarInsert());
      if (!filtered && i == 9) entries.add(const _ThreatInsert());
    }

    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _TopBar(onLogoTap: onLogoTap)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 6, Tp.page, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.firstName.isEmpty ? Fmt.greeting(now) : '${Fmt.greeting(now)}, ${profile.firstName}',
                  style: context.text.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text('${Fmt.today(now)} · son 24 saatte $freshCount haber', style: context.text.bodyMedium),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 18, Tp.page, 14),
            child: Row(
              children: [
                Expanded(
                  child: _ModeSwitch(
                    mode: state.mode,
                    onChanged: (m) => ref.read(homeFeedProvider.notifier).setMode(m),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(active: filtered, onTap: onOpenFilter),
              ],
            ),
          ),
        ),
        if (filtered)
          SliverToBoxAdapter(
            child: _ActiveFilterBar(filter: state.filter, count: feed.length),
          ),
        SliverToBoxAdapter(
          child: StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt),
        ),
        if (forYouWithoutInterests && !filtered)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 18),
              child: _HintCard(
                icon: Icons.tune_rounded,
                text: 'İlgi alanlarınızı seçin; "Sizin İçin" akışı yalnızca o konulardan oluşsun.',
                action: 'Seç',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InterestsScreen())),
              ),
            ),
          ),
        if (feed.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: filtered
                ? EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Bu filtrelere uyan haber yok',
                    message: 'Zaman aralığını genişletmeyi veya başka konular seçmeyi deneyin.',
                    action: 'Filtreleri temizle',
                    onAction: () => ref.read(homeFeedProvider.notifier).clearFilter(),
                  )
                : state.mode == FeedMode.forYou
                ? EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Seçtiğiniz konularda yeni haber yok',
                    message: 'Bütün konulardaki gelişmelere göz atabilirsiniz.',
                    action: 'Tüm Gündem\'e geç',
                    onAction: () => ref.read(homeFeedProvider.notifier).setMode(FeedMode.all),
                  )
                : const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Henüz haber yok',
                    message: 'Haberler her saat güncellenir. Biraz sonra aşağı çekip yenileyin.',
                  ),
          )
        else ...[
          if (headline != null) ...[
            SliverToBoxAdapter(child: HeadlineCard(item: headline)),
            if (briefs.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: Tp.section)),
              const SliverToBoxAdapter(
                child: SectionHeader(title: 'Kısaca', subtitle: 'Öne çıkan diğer gelişmeler'),
              ),
              SliverToBoxAdapter(child: _BriefStrip(items: briefs)),
            ],
            if (list.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: Tp.section - 8)),
              const SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Son gelişmeler',
                  subtitle: 'En yeniden eskiye',
                  padding: EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 0),
                ),
              ),
            ],
          ],
          SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) => switch (entries[i]) {
              _Header(:final label) => TimeGroupHeader(label),
              _News(:final item) => Column(
                children: [
                  NewsRow(item: item),
                  if (i + 1 < entries.length && entries[i + 1] is _News)
                    Divider(indent: Tp.page, endIndent: Tp.page, color: tp.border),
                ],
              ),
              _RadarInsert() => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: RadarTeaser()),
              _ThreatInsert() => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: ThreatTeaser()),
            },
          ),
          SliverToBoxAdapter(
            child: _FeedEnd(
              forYou: state.mode == FeedMode.forYou && profile.interests.isNotEmpty && !filtered,
              onSwitch: () => ref.read(homeFeedProvider.notifier).setMode(FeedMode.all),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onLogoTap});

  final VoidCallback onLogoTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tp.page - 4, 6, 8, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'TechPulse. Başa dön veya yenile',
            child: InkWell(
              onTap: onLogoTap,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(padding: EdgeInsets.all(4), child: BrandLockup(markSize: 28, fontSize: 20)),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Ara',
            onPressed: () => openSearch(context),
            icon: const Icon(Icons.search_rounded, size: 26),
          ),
        ],
      ),
    );
  }
}

/// "Sizin İçin" / "Tüm Gündem" geçişi.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final FeedMode mode;
  final ValueChanged<FeedMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    Widget option(FeedMode value, String label) {
      final selected = mode == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? tp.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: context.text.labelLarge?.copyWith(
                  fontSize: 14,
                  color: selected ? tp.text : tp.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: tp.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [option(FeedMode.forYou, 'Sizin İçin'), option(FeedMode.all, 'Tüm Gündem')]),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Tooltip(
      message: 'Filtrele',
      child: Material(
        color: active ? tp.accentSoft : tp.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(
            dimension: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.filter_list_rounded, color: active ? tp.accent : tp.text),
                if (active)
                  Positioned(
                    right: 9,
                    top: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: tp.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: tp.surfaceAlt, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterBar extends ConsumerWidget {
  const _ActiveFilterBar({required this.filter, required this.count});

  final FeedFilter filter;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final parts = [
      if (filter.categories.isNotEmpty)
        filter.categories.length == 1 ? filter.categories.first.shortLabel : '${filter.categories.length} konu',
      if (filter.range != TimeRange.any) filter.range.label,
      if (filter.sort != FeedSort.recommended) filter.sort.label,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page - 8, 10),
      child: Row(
        children: [
          Icon(Icons.filter_list_rounded, size: 16, color: tp.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${parts.join(' · ')} · $count haber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: tp.text),
            ),
          ),
          TextButton(onPressed: () => ref.read(homeFeedProvider.notifier).clearFilter(), child: const Text('Temizle')),
        ],
      ),
    );
  }
}

class _BriefStrip extends StatelessWidget {
  const _BriefStrip({required this.items});

  final List<NewsItem> items;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // Görsel (16:9) + metin alanı; metin alanı yazı boyutu tercihine göre büyür.
    final height = 248 * 9 / 16 + 30 + scaler.scale(1) * 112;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tp.page),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => BriefCard(item: items[i]),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.icon, required this.text, required this.action, required this.onTap});

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(color: tp.accentSoft, borderRadius: BorderRadius.circular(Tp.radiusSmall)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tp.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: context.text.bodySmall?.copyWith(color: tp.text)),
          ),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _FeedEnd extends ConsumerWidget {
  const _FeedEnd({required this.forYou, required this.onSwitch});

  final bool forYou;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tp.page, 28, Tp.page, 8),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: tp.textTertiary, size: 28),
          const SizedBox(height: 10),
          Text('Hepsini gördünüz', style: context.text.titleSmall),
          const SizedBox(height: 4),
          Text(
            forYou ? 'Seçtiğiniz konulardaki bütün haberler bu kadar.' : 'Yeni haberler her saat eklenir.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: forYou ? onSwitch : () => ref.read(appTabProvider.notifier).select(AppTab.discover),
            child: Text(forYou ? 'Tüm Gündem\'e geç' : 'Keşfet\'e göz at'),
          ),
        ],
      ),
    );
  }
}
