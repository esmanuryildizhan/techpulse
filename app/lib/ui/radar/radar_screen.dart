import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../news/news_screen.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import 'radar_cards.dart';

/// YZ Radarı: Hugging Face'te trend modeller, öne çıkan makaleler ve GitHub'da yükselen projeler.
class RadarScreen extends StatelessWidget {
  const RadarScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: const Text('YZ Radarı'),
          actions: const [SearchAction(), SettingsAction(), SizedBox(width: 4)],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Modeller', icon: Icon(Icons.hub_outlined, size: 20)),
              Tab(text: 'Makaleler', icon: Icon(Icons.article_outlined, size: 20)),
              Tab(text: 'Projeler', icon: Icon(Icons.code, size: 20)),
            ],
          ),
        ),
        body: const TabBarView(children: [_ModelsTab(), _PapersTab(), _ReposTab()]),
      ),
    );
  }
}

Future<void> _refresh<T>(
  BuildContext context,
  WidgetRef ref,
  Endpoint endpoint,
  T Function(String) parse,
  void Function() invalidate,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await refreshFeed(ref, endpoint, parse, invalidate);
  if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
}

class _Intro extends StatelessWidget {
  const _Intro(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

class _ModelsTab extends ConsumerStatefulWidget {
  const _ModelsTab();

  @override
  ConsumerState<_ModelsTab> createState() => _ModelsTabState();
}

class _ModelsTabState extends ConsumerState<_ModelsTab> with AutomaticKeepAliveClientMixin {
  Modality? _modality;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return FeedView<AiModel>(
      value: ref.watch(modelsProvider),
      onRetry: () => ref.invalidate(modelsProvider),
      builder: (context, snapshot) {
        final all = snapshot.data.items;
        final present = {for (final m in all) m.modality};
        final items = _modality == null ? all : all.where((m) => m.modality == _modality).toList();
        return RefreshIndicator(
          onRefresh: () => _refresh(context, ref, Endpoint.models, parseModels, () => ref.invalidate(modelsProvider)),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: items.length + 3,
            itemBuilder: (context, index) {
              if (index == 0) return StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt);
              if (index == 1) {
                return const _Intro("Hugging Face'te son günlerde en çok ilgi gören modeller. Sıralama, beğenilerin son "
                    'günlerdeki artışına göre yapılır.');
              }
              if (index == 2) {
                return SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    children: [
                      ChoiceChip(
                        showCheckmark: false,
                        label: Text('Tümü ${all.length}'),
                        selected: _modality == null,
                        onSelected: (_) => setState(() => _modality = null),
                      ),
                      for (final modality in Modality.values)
                        if (present.contains(modality))
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              showCheckmark: false,
                              avatar: Icon(modality.icon, size: 16, color: modalityColor(modality, theme.brightness)),
                              label: Text(modality.label),
                              selected: _modality == modality,
                              selectedColor: modalityColor(modality, theme.brightness).withValues(alpha: 0.18),
                              onSelected: (_) => setState(() => _modality = modality),
                            ),
                          ),
                    ],
                  ),
                );
              }
              return ModelCard(model: items[index - 3]);
            },
          ),
        );
      },
    );
  }
}

class _PapersTab extends ConsumerStatefulWidget {
  const _PapersTab();

  @override
  ConsumerState<_PapersTab> createState() => _PapersTabState();
}

class _PapersTabState extends ConsumerState<_PapersTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FeedView<Paper>(
      value: ref.watch(papersProvider),
      onRetry: () => ref.invalidate(papersProvider),
      builder: (context, snapshot) {
        final items = snapshot.data.items;
        // Günlere göre gruplayarak göster: "Bugün", "Dün", "22 Kas"…
        final rows = <Object>[];
        String? lastDay;
        for (final paper in items) {
          final day = _dayLabel(paper.publishedAt);
          if (day != lastDay) {
            rows.add(day);
            lastDay = day;
          }
          rows.add(paper);
        }
        return RefreshIndicator(
          onRefresh: () => _refresh(context, ref, Endpoint.papers, parsePapers, () => ref.invalidate(papersProvider)),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: rows.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt);
              if (index == 1) {
                return const _Intro('Hugging Face Daily Papers: araştırma topluluğunun her gün öne çıkardığı yeni '
                    'makaleler, Türkçe özetleriyle.');
              }
              final row = rows[index - 2];
              if (row is String) return SectionLabel(row);
              return PaperCard(paper: row as Paper);
            },
          ),
        );
      },
    );
  }

  String _dayLabel(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    return MaterialLocalizations.of(context).formatMediumDate(local);
  }
}

class _ReposTab extends ConsumerStatefulWidget {
  const _ReposTab();

  @override
  ConsumerState<_ReposTab> createState() => _ReposTabState();
}

class _ReposTabState extends ConsumerState<_ReposTab> with AutomaticKeepAliveClientMixin {
  bool _aiOnly = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return FeedView<Repo>(
      value: ref.watch(reposProvider),
      onRetry: () => ref.invalidate(reposProvider),
      builder: (context, snapshot) {
        final all = snapshot.data.items;
        final items = _aiOnly ? all.where((r) => r.isAi).toList() : all;
        return RefreshIndicator(
          onRefresh: () => _refresh(context, ref, Endpoint.repos, parseRepos, () => ref.invalidate(reposProvider)),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: items.length + 3,
            itemBuilder: (context, index) {
              if (index == 0) return StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt);
              if (index == 1) {
                return const _Intro("Son 7 günde açılıp GitHub'da en çok yıldız alan projeler.");
              }
              if (index == 2) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      FilterChip(
                        avatar: Icon(Icons.auto_awesome, size: 16, color: categoryColor(NewsCategory.ai, theme.brightness)),
                        label: const Text('Yalnızca yapay zekâ'),
                        selected: _aiOnly,
                        showCheckmark: false,
                        onSelected: (value) => setState(() => _aiOnly = value),
                      ),
                    ],
                  ),
                );
              }
              return RepoCard(repo: items[index - 3]);
            },
          ),
        );
      },
    );
  }
}
