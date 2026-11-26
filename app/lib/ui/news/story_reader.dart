import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import 'story_view.dart';

/// Uzun yazı okuma ekranı (haber ve makale ortak): üst çubukta yazı boyutu, kaydet ve paylaş, altında okuma
/// ilerlemesi; başlık bölümü, sade/teknik geçişi, "30 saniyede oku", anlatım, kavramlar ve kaynak.
class StoryReader extends ConsumerStatefulWidget {
  const StoryReader({
    super.key,
    required this.kind,
    required this.entry,
    required this.title,
    required this.header,
    required this.story,
    required this.fallback,
    required this.footer,
    this.trailing = const [],
    this.whyTitle,
    this.excerptNote,
    this.glossaryTitle = 'Bu yazıdaki kavramlar',
  });

  final BookmarkKind kind;
  final Entry entry;
  final String title;

  /// Başlık, kaynak, tarih ve görsel.
  final List<Widget> header;
  final Story? story;

  /// Anlatım henüz yoksa gösterilecek kısa içerik.
  final List<Widget> fallback;

  /// Kaynak kutusu ve notlar.
  final List<Widget> footer;

  /// Sayfanın sonundaki ek bölümler (ör. ilgili haberler), sliver olarak.
  final List<Widget> trailing;
  final String? whyTitle;

  /// Anlatım kaynağın yalnızca kısa bir bölümüne dayanıyorsa gösterilecek not.
  final String? excerptNote;
  final String glossaryTitle;

  @override
  ConsumerState<StoryReader> createState() => _StoryReaderState();
}

class _StoryReaderState extends ConsumerState<StoryReader> {
  final _scroll = ScrollController();
  final _progress = ValueNotifier<double>(0);
  final _showTitle = ValueNotifier<bool>(false);
  late ReadingLevel _level = ref.read(settingsProvider).readingLevel;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(settingsProvider).recordHistory) {
        ref.read(historyProvider.notifier).add(widget.kind, widget.entry);
      }
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final max = position.maxScrollExtent;
    _progress.value = max <= 0 ? 1 : (position.pixels / max).clamp(0.0, 1.0);
    _showTitle.value = position.pixels > 140;
  }

  void _setLevel(ReadingLevel level) {
    if (level == _level) return;
    setState(() => _level = level);
    // Anlatım değişince yazının başına dönülür; okur yeni metni baştan okur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _levelKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 250), alignment: 0.02);
      }
    });
  }

  final _levelKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    _progress.dispose();
    _showTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final scale = settings.readingSize.scale;
    final story = widget.story;
    final level = story?.technical == null ? ReadingLevel.simple : _level;

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            titleSpacing: 0,
            title: ValueListenableBuilder<bool>(
              valueListenable: _showTitle,
              builder: (context, show, _) => AnimatedOpacity(
                opacity: show ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Yazı boyutu',
                onPressed: () => showReadingSizeSheet(context),
                icon: const Icon(Icons.format_size_rounded),
              ),
              BookmarkButton(kind: widget.kind, entry: widget.entry),
              IconButton(
                tooltip: 'Paylaş',
                onPressed: () => shareLink(context, title: widget.title, url: widget.entry.url),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2.5),
              child: ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                  semanticsLabel: 'Okuma ilerlemesi',
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 12, Tp.page, 0),
            sliver: SliverList.list(
              children: [
                ...widget.header,
                const SizedBox(height: 22),
                if (story == null)
                  ...widget.fallback
                else ...[
                  if (story.technical != null) ...[
                    LevelToggle(key: _levelKey, story: story, level: level, onChanged: _setLevel),
                    const SizedBox(height: 20),
                  ],
                  if (story.tldr.isNotEmpty) ...[
                    TldrPanel(points: story.tldr, scale: scale),
                    const SizedBox(height: 24),
                  ],
                  StoryContent(
                    key: ValueKey(level),
                    story: story,
                    level: level,
                    scale: scale,
                    whyTitle: widget.whyTitle,
                  ),
                  if (story.technical != null && level == ReadingLevel.simple)
                    _SwitchHint(
                      text:
                          'Konunun nasıl çalıştığını, ayrıntılarını ve uygulayıcı için anlamını teknik anlatımda '
                          '${minutesOf(story, ReadingLevel.technical)} dakikalık bir yazıyla okuyabilirsiniz.',
                      action: 'Teknik derinliğe geç',
                      onTap: () => _setLevel(ReadingLevel.technical),
                    ),
                  if (story.fromExcerpt && widget.excerptNote != null) ...[
                    const SizedBox(height: 4),
                    ReaderNote(icon: Icons.info_outline_rounded, text: widget.excerptNote!),
                  ],
                  if (story.glossary.isNotEmpty) ...[
                    const SizedBox(height: Tp.section - 8),
                    SectionHeader(
                      title: widget.glossaryTitle,
                      subtitle: 'Metinde altı çizili kelimelere dokunarak da açabilirsiniz.',
                      padding: const EdgeInsets.only(bottom: 12),
                    ),
                    GlossaryList(entries: story.glossary),
                  ],
                ],
                const SizedBox(height: Tp.section),
                ...widget.footer,
              ],
            ),
          ),
          ...widget.trailing,
          SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

/// Anlatımın okuma süresi (dakika; dakikada 180 kelime).
int minutesOf(Story story, ReadingLevel level) {
  final words = level == ReadingLevel.technical && story.technical != null
      ? story.technical!.wordCount
      : story.simple.wordCount +
            story.tldr.join(' ').split(RegExp(r'\s+')).length +
            story.why.split(RegExp(r'\s+')).length;
  return (words / 180).ceil().clamp(1, 99);
}

/// Sade / teknik anlatım seçimi. Seçili olan vurgu rengiyle dolar; her seçenekte okuma süresi yazar.
class LevelToggle extends StatelessWidget {
  const LevelToggle({super.key, required this.story, required this.level, required this.onChanged});

  final Story story;
  final ReadingLevel level;
  final ValueChanged<ReadingLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    Widget option(ReadingLevel value, IconData icon, String label) {
      final selected = value == level;
      final fg = selected ? tp.onAccent : tp.textSecondary;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: '$label, ${minutesOf(story, value)} dakika',
          excludeSemantics: true,
          child: Material(
            color: selected ? tp.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => onChanged(value),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 17, color: fg),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelLarge?.copyWith(color: fg, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${minutesOf(story, value)} dk okuma',
                      style: context.text.labelSmall?.copyWith(color: fg.withValues(alpha: selected ? 0.85 : 1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: tp.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: tp.border),
          ),
          child: Row(
            children: [
              option(ReadingLevel.simple, Icons.spa_outlined, 'Sade anlatım'),
              const SizedBox(width: 4),
              option(ReadingLevel.technical, Icons.bolt_rounded, 'Teknik derinlik'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(level.description, style: context.text.labelSmall),
      ],
    );
  }
}

class _SwitchHint extends StatelessWidget {
  const _SwitchHint({required this.text, required this.action, required this.onTap});

  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(color: tp.accentSoft, borderRadius: BorderRadius.circular(Tp.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: tp.accent),
              const SizedBox(width: 8),
              Text('Daha derine inmek ister misiniz?', style: context.text.labelLarge?.copyWith(color: tp.accent)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: context.text.bodyMedium?.copyWith(color: tp.text)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(action),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gri bilgi notu (ör. kaynak yalnızca kısa bir bölüm yayımlıyor).
class ReaderNote extends StatelessWidget {
  const ReaderNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tp.surfaceAlt, borderRadius: BorderRadius.circular(Tp.radiusSmall)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tp.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: context.text.bodySmall?.copyWith(color: tp.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// Yazı boyutu: A− / A / A+.
Future<void> showReadingSizeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final size = ref.watch(settingsProvider.select((s) => s.readingSize));
        final controller = ref.read(settingsProvider.notifier);
        final tp = context.tp;
        Widget button(String label, double fontSize, ReadingSize? target, String tooltip) => Expanded(
          child: Tooltip(
            message: tooltip,
            child: OutlinedButton(
              onPressed: target == null ? null : () => controller.setReadingSize(target),
              style: OutlinedButton.styleFrom(
                backgroundColor: target == size ? tp.accentSoft : null,
                side: BorderSide(color: target == size ? tp.accent : tp.border),
              ),
              child: Text(
                label,
                style: TextStyle(fontFamily: Tp.serif, fontSize: fontSize, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yazı boyutu', style: context.text.titleSmall),
                const SizedBox(height: 4),
                Text('${size.label} · bütün yazılarda geçerli', style: context.text.bodySmall),
                const SizedBox(height: 16),
                Row(
                  children: [
                    button('A−', 16, size == ReadingSize.small ? null : size.smaller, 'Küçült'),
                    const SizedBox(width: 10),
                    button('A', 20, ReadingSize.normal, 'Normal boyut'),
                    const SizedBox(width: 10),
                    button('A+', 24, size == ReadingSize.xlarge ? null : size.larger, 'Büyüt'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Örnek metin: Yeni sürüm, uygulamaların daha az bellekle daha hızlı açılmasını sağlıyor.',
                  style: Tp.article(context, size.scale),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
