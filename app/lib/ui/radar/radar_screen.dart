import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../widgets/state_views.dart';
import 'radar_cards.dart';

enum RadarTab { models, papers, repos }

/// Yapay Zekâ Radarı: Hugging Face trend modelleri, günün makaleleri ve GitHub'da yükselen projeler.
class RadarScreen extends StatelessWidget {
  const RadarScreen({super.key, this.initialTab = RadarTab.models});

  final RadarTab initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: RadarTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Yapay Zekâ Radarı'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Modeller'),
              Tab(text: 'Makaleler'),
              Tab(text: 'Projeler'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ModelsTab(), _PapersTab(), _ReposTab()]),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Tp.page, 14, Tp.page, 6),
        child: Text(text, style: context.text.bodySmall),
      );
}

Future<void> _refresh(BuildContext context, WidgetRef ref, Endpoint endpoint, Object? Function(String) parse, VoidCallback invalidate) async {
  final message = await refreshFeed(ref, endpoint, parse, invalidate);
  if (message != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    return FeedView<AiModel>(
      value: ref.watch(modelsProvider),
      onRetry: () => ref.invalidate(modelsProvider),
      builder: (context, snapshot) {
        final all = snapshot.data.items;
        final present = {for (final m in all) m.modality};
        final items = _modality == null ? all : all.where((m) => m.modality == _modality).toList();
        return RefreshIndicator(
          onRefresh: () => _refresh(context, ref, Endpoint.models, parseModels, () => ref.invalidate(modelsProvider)),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: items.length + 3,
            separatorBuilder: (context, index) => SizedBox(height: index < 3 ? 0 : 12),
            itemBuilder: (context, index) {
              if (index == 0) return StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt);
              if (index == 1) {
                return const _Intro("Hugging Face'te son günlerde en çok ilgi gören modeller. Sıralama, beğenilerin son günlerdeki artışına göre yapılır.");
              }
              if (index == 2) {
                return SizedBox(
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(Tp.page, 6, Tp.page, 10),
                    children: [
                      ChoiceChip(
                        label: Text('Tümü ${all.length}'),
                        selected: _modality == null,
                        onSelected: (_) => setState(() => _modality = null),
                      ),
                      for (final modality in Modality.values)
                        if (present.contains(modality))
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              avatar: Icon(modality.icon, size: 16, color: _modality == modality ? Colors.white : modalityColor(modality, context.brightness)),
                              label: Text(modality.label),
                              selected: _modality == modality,
                              onSelected: (_) => setState(() => _modality = modality),
                            ),
                          ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tp.page),
                child: ModelCard(model: items[index - 3]),
              );
            },
          ),
        );
      },
    );
  }
}

class _PapersTab extends ConsumerWidget {
  const _PapersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeedView<Paper>(
      value: ref.watch(papersProvider),
      onRetry: () => ref.invalidate(papersProvider),
      builder: (context, snapshot) {
        final items = snapshot.data.items;
        return RefreshIndicator(
          onRefresh: () => _refresh(context, ref, Endpoint.papers, parsePapers, () => ref.invalidate(papersProvider)),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: items.length + 2,
            separatorBuilder: (context, index) => SizedBox(height: index < 2 ? 0 : 14),
            itemBuilder: (context, index) {
              if (index == 0) return StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt);
              if (index == 1) {
                return const _Intro('Hugging Face Daily Papers: araştırma topluluğunun her gün öne çıkardığı yeni makaleler, sade bir Türkçeyle.');
              }
              return Padding(padding: const EdgeInsets.symmetric(horizontal: Tp.page), child: PaperCard(paper: items[index - 2]));
            },
          ),
        );
      },
    );
  }
}

class _ReposTab extends ConsumerWidget {
  const _ReposTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeedView<Repo>(
      value: ref.watch(reposProvider),
      onRetry: () => ref.invalidate(reposProvider),
      builder: (context, snapshot) {
        final items = snapshot.data.items;
        return RefreshIndicator(
          onRefresh: () => _refresh(context, ref, Endpoint.repos, parseRepos, () => ref.invalidate(reposProvider)),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: items.length + 2,
            separatorBuilder: (context, index) => SizedBox(height: index < 2 ? 0 : 14),
            itemBuilder: (context, index) {
              if (index == 0) return StatusBanner(snapshot: snapshot, generatedAt: snapshot.data.generatedAt);
              if (index == 1) {
                return const _Intro("Son 7 günde açılan ve GitHub'da en hızlı yıldız toplayan açık kaynak projeler.");
              }
              return Padding(padding: const EdgeInsets.symmetric(horizontal: Tp.page), child: RepoCard(repo: items[index - 2]));
            },
          ),
        );
      },
    );
  }
}
