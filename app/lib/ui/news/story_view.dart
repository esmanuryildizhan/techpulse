import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// Haber anlatımı: giriş, "Neden önemli?" kutusu ve ara başlıklı bölümler. Metinde geçen teknik kavramların
/// ilk geçtiği yerin altı noktalı çizilir; dokununca kavramın açıklaması alttan açılır.
class StoryContent extends StatelessWidget {
  const StoryContent({super.key, required this.story, required this.level, required this.scale, this.whyTitle});

  final Story story;
  final ReadingLevel level;
  final double scale;

  /// "Neden önemli?" kutusunun başlığı (makalelerde farklı).
  final String? whyTitle;

  StoryVersion get _version =>
      level == ReadingLevel.technical && story.technical != null ? story.technical! : story.simple;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final version = _version;
    final body = Tp.article(context, scale);
    final paragraphs = <String>[version.intro, for (final section in version.sections) ...section.paragraphs];
    final plan = planGlossary(paragraphs, story.glossary);
    var index = 0;
    Widget paragraph(String text) {
      final terms = plan[index++];
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlossaryParagraph(text: text, terms: terms, style: body, onTap: (e) => showGlossarySheet(context, e)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (version.intro.isNotEmpty) paragraph(version.intro),
        if (story.why.isNotEmpty) ...[
          const SizedBox(height: 4),
          InfoPanel(
            title: whyTitle ?? 'Bu gelişme neden önemli?',
            icon: Icons.lightbulb_outline_rounded,
            tone: tp.accent,
            child: Text(story.why, style: body.copyWith(fontSize: 16 * scale, height: 1.55)),
          ),
          const SizedBox(height: 24),
        ],
        for (final section in version.sections) ...[
          if (section.heading.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Semantics(
                header: true,
                child: Text(
                  section.heading,
                  style: Tp.headline(context, size: 20 * scale, weight: FontWeight.w700, height: 1.3),
                ),
              ),
            ),
          for (final p in section.paragraphs) paragraph(p),
        ],
      ],
    );
  }
}

/// "30 saniyede oku" kutusu: haberin en önemli üç noktası.
class TldrPanel extends StatelessWidget {
  const TldrPanel({super.key, required this.points, required this.scale});

  final List<String> points;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final style = context.text.bodyLarge?.copyWith(fontSize: 15.5 * scale, height: 1.5, color: tp.text);
    return InfoPanel(
      title: '30 saniyede oku',
      icon: Icons.timer_outlined,
      tone: tp.textSecondary,
      child: Column(
        children: [
          for (final (i, point) in points.indexed)
            Padding(
              padding: EdgeInsets.only(bottom: i == points.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 8 * scale),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: tp.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(point, style: style)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Haberin sonundaki kavram listesi.
class GlossaryList extends StatelessWidget {
  const GlossaryList({super.key, required this.entries});

  final List<GlossaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return TpCard(
      child: Column(
        children: [
          for (final (i, entry) in entries.indexed) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            InkWell(
              onTap: () => showGlossarySheet(context, entry),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.term, style: context.text.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            entry.definition,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: tp.textTertiary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kavram açıklaması: ne olduğu, günlük hayattan bir benzetme, nerede kullanıldığı ve kimin geliştirdiği.
Future<void> showGlossarySheet(BuildContext context, GlossaryEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final tp = sheetContext.tp;
      Widget part(IconData icon, String title, String text) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: tp.surfaceAlt, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: tp.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: sheetContext.text.labelMedium),
                  const SizedBox(height: 4),
                  Text(text, style: sheetContext.text.bodyLarge?.copyWith(fontSize: 15, color: tp.text)),
                ],
              ),
            ),
          ],
        ),
      );
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kavram', style: sheetContext.text.labelSmall),
                const SizedBox(height: 4),
                Text(entry.term, style: sheetContext.text.headlineSmall),
                const SizedBox(height: 10),
                Text(entry.definition, style: Tp.article(sheetContext, 1).copyWith(fontSize: 17)),
                if (entry.analogy.isNotEmpty)
                  part(Icons.emoji_objects_outlined, 'Günlük hayattan bir benzetme', entry.analogy),
                if (entry.usage.isNotEmpty) part(Icons.handyman_outlined, 'Nerede kullanılır?', entry.usage),
                if (entry.origin.isNotEmpty) part(Icons.history_edu_outlined, 'Kim geliştirdi?', entry.origin),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Altı çizili kavramlar içeren paragraf.
class GlossaryParagraph extends StatefulWidget {
  const GlossaryParagraph({
    super.key,
    required this.text,
    required this.terms,
    required this.style,
    required this.onTap,
  });

  final String text;

  /// Bu paragrafta altı çizilecek kavramlar (yalnızca ilk geçtiği yer).
  final List<GlossaryEntry> terms;
  final TextStyle style;
  final void Function(GlossaryEntry entry) onTap;

  @override
  State<GlossaryParagraph> createState() => _GlossaryParagraphState();
}

class _GlossaryParagraphState extends State<GlossaryParagraph> {
  final Map<String, TapGestureRecognizer> _recognizers = {};

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(GlossaryParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final wanted = {for (final e in widget.terms) e.term};
    for (final key in _recognizers.keys.toList()) {
      if (!wanted.contains(key)) _recognizers.remove(key)?.dispose();
    }
    for (final entry in widget.terms) {
      _recognizers.putIfAbsent(entry.term, TapGestureRecognizer.new).onTap = () => widget.onTap(entry);
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    if (widget.terms.isEmpty) return Text(text, style: widget.style);
    final tp = context.tp;
    final folded = foldSameLength(text);
    final matches = <(int, int, GlossaryEntry)>[];
    for (final entry in widget.terms) {
      final at = findTerm(folded, foldSameLength(entry.term));
      if (at < 0) continue;
      final end = at + entry.term.length;
      if (matches.any((m) => at < m.$2 && end > m.$1)) continue; // çakışanları atla
      matches.add((at, end, entry));
    }
    matches.sort((a, b) => a.$1.compareTo(b.$1));
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final (start, end, entry) in matches) {
      if (start > cursor) spans.add(TextSpan(text: text.substring(cursor, start)));
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          recognizer: _recognizers[entry.term],
          semanticsLabel: '${text.substring(start, end)}, açıklaması için dokunun',
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: tp.accent,
            decorationThickness: 2,
          ),
        ),
      );
      cursor = end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

/// Her kavramın ilk geçtiği paragrafı bulur. Dönüş: her paragraf için altı çizilecek kavramlar.
List<List<GlossaryEntry>> planGlossary(List<String> paragraphs, List<GlossaryEntry> glossary) {
  final plan = [for (final _ in paragraphs) <GlossaryEntry>[]];
  final folded = [for (final p in paragraphs) foldSameLength(p)];
  for (final entry in glossary) {
    final term = foldSameLength(entry.term);
    if (term.trim().length < 2) continue;
    for (var i = 0; i < folded.length; i++) {
      if (findTerm(folded[i], term) >= 0) {
        plan[i].add(entry);
        break;
      }
    }
  }
  return plan;
}

final RegExp _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

bool _isWordChar(String text, int index) => index >= 0 && index < text.length && _wordChar.hasMatch(text[index]);

/// Kavramı metinde arar (büyük/küçük harf ve Türkçe i/ı farkı gözetmeden). Kavram bir kelimenin ortasında
/// başlayamaz; Türkçe ekler ("Clojure'un", "çekirdeğinde") için sonunda harf gelmesine izin verilir, ancak
/// kısa kısaltmalarda (ör. "AI") kelime sınırı aranır ki "MAIL" içinde eşleşmesin.
int findTerm(String foldedText, String foldedTerm) {
  if (foldedTerm.isEmpty) return -1;
  var from = 0;
  while (true) {
    final at = foldedText.indexOf(foldedTerm, from);
    if (at < 0) return -1;
    final end = at + foldedTerm.length;
    final leftOk = !_isWordChar(foldedText, at - 1);
    final rightOk = foldedTerm.length >= 4 || !_isWordChar(foldedText, end);
    if (leftOk && rightOk) return at;
    from = at + 1;
  }
}

/// Uzunluğu değiştirmeden küçük harfe çevirir (konumlar orijinal metinle aynı kalsın diye).
String foldSameLength(String input) {
  final buffer = StringBuffer();
  for (final unit in input.codeUnits) {
    final ch = String.fromCharCode(unit);
    switch (ch) {
      case 'İ' || 'I' || 'ı':
        buffer.write('i');
      default:
        final lower = ch.toLowerCase();
        buffer.write(lower.length == 1 ? lower : ch);
    }
  }
  return buffer.toString();
}
