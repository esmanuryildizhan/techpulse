import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/ranking.dart';
import '../news/cards.dart';
import '../news/news_list_screen.dart';
import '../profile/profile_pages.dart';
import '../search/search_screen.dart';
import '../updates/updates_screen.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';

/// Ana Sayfa: logo ve bildirimler, arama, konu filtreleri, öne çıkan haber, "Öne Çıkanlar" ve
/// "Son Gelişmeler". Konuların sırası kullanıcının ilgi alanlarına göre belirlenir.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _page = 15;
  TechCategory? _category;
  int _visible = _page;

  void _select(TechCategory? category) {
    setState(() {
      _category = category;
      _visible = _page;
    });
  }

  Future<void> _refresh() async {
    final message = await refreshNews(ref);
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(newsProvider);
    final profile = ref.watch(profileProvider);
    final now = ref.watch(clockProvider)();
    final all = ref.watch(visibleNewsProvider);
    final items = _category == null ? all : all.where((n) => n.category == _category).toList();
    final layout = HomeLayout.build(items, now, interests: profile.interests.toSet());

    final header = <Widget>[
      const BrandHeader(trailing: NotificationBell()),
      const SizedBox(height: 10),
      const SearchLauncher(),
      const SizedBox(height: 14),
      _CategoryChips(order: profile.categoryOrder, selected: _category, onSelected: _select),
    ];

    return SafeArea(
      bottom: false,
      child: FeedView<NewsItem>(
        value: value,
        onRetry: () => ref.invalidate(newsProvider),
        loading: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...header, const SizedBox(height: 16), const FeedSkeleton()]),
        ),
        builder: (context, snapshot) {
          final latest = layout.latest.take(_visible).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 700 && _visible < layout.latest.length) {
                  setState(() => _visible += _page);
                }
                return false;
              },
              child: CustomScrollView(
                key: PageStorageKey('home-${_category?.key ?? 'all'}'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverList.list(
                    children: [
                      ...header,
                      StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt),
                      if (profile.interests.isEmpty && _category == null) const _InterestsPrompt(),
                    ],
                  ),
                  if (layout.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: _category?.icon ?? Icons.article_outlined,
                        title: 'Bu konuda henüz haber yok',
                        message: 'Yeni haberler saatte bir eklenir. Diğer konulara göz atabilirsin.',
                        actionLabel: _category == null ? null : 'Tüm haberleri göster',
                        onAction: _category == null ? null : () => _select(null),
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(Tp.page, 16, Tp.page, 0),
                      sliver: SliverToBoxAdapter(child: FeaturedNewsCard(item: layout.featured!)),
                    ),
                    if (layout.highlights.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          'Öne Çıkanlar',
                          actionLabel: 'Tümünü gör',
                          onAction: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _category == null ? const NewsListScreen.popular() : NewsListScreen.category(_category!),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: Tp.page),
                        sliver: SliverGrid.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 262,
                          ),
                          itemCount: layout.highlights.length,
                          itemBuilder: (context, index) => GridNewsCard(item: layout.highlights[index]),
                        ),
                      ),
                    ],
                    if (latest.isNotEmpty) ...[
                      const SliverToBoxAdapter(child: SectionHeader('Son Gelişmeler', subtitle: 'En yeni haberler, yayın sırasıyla')),
                      SliverList.separated(
                        itemCount: latest.length,
                        separatorBuilder: (context, index) => Divider(indent: Tp.page, endIndent: Tp.page, color: context.tp.border),
                        itemBuilder: (context, index) => ListNewsCard(item: latest[index]),
                      ),
                      if (_visible < layout.latest.length)
                        const SliverToBoxAdapter(
                          child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))),
                        ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Yatay kaydırılabilen konu filtreleri. Seçili konu mor zeminle belirginleşir.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.order, required this.selected, required this.onSelected});

  final List<TechCategory> order;
  final TechCategory? selected;
  final ValueChanged<TechCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Tp.page),
        children: [
          _chip(context, label: 'Tümü', icon: Icons.dashboard_outlined, active: selected == null, onTap: () => onSelected(null)),
          for (final category in order)
            _chip(
              context,
              label: category.label,
              icon: category.icon,
              active: selected == category,
              onTap: () => onSelected(selected == category ? null : category),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, {required String label, required IconData icon, required bool active, required VoidCallback onTap}) {
    final tp = context.tp;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: active,
        button: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? tp.primary : tp.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? tp.primary : tp.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: active ? Colors.white : tp.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : tp.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// İlgi alanı seçilmemişse akışı kişiselleştirmeye davet eden kart.
class _InterestsPrompt extends StatelessWidget {
  const _InterestsPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tp.page, 12, Tp.page, 0),
      child: TpCard(
        color: context.tp.primarySoft,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InterestsScreen())),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, color: context.tp.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text('İlgi alanlarını seç; konular ve öne çıkan haberler sana göre sıralansın.', style: context.text.bodyMedium),
            ),
            Icon(Icons.chevron_right_rounded, color: context.tp.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Bildirim ikonu: son bakıştan bu yana yenilik varsa sayıyla gösterir.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unseen = ref.watch(updatesProvider.select((u) => u.unseen));
    return IconButton(
      tooltip: unseen > 0 ? 'Yenilikler ($unseen yeni)' : 'Yenilikler',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UpdatesScreen())),
      icon: Badge(
        isLabelVisible: unseen > 0,
        label: Text(unseen > 99 ? '99+' : '$unseen'),
        backgroundColor: context.tp.primary,
        child: Icon(Icons.notifications_none_rounded, color: context.tp.textPrimary),
      ),
    );
  }
}
