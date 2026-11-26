import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import 'common.dart';

/// Bağlantıyı uygulama içinde açılan tarayıcı sekmesinde açar (Android'de Custom Tabs, iOS'ta Safari
/// görünümü). Yalnızca https bağlantılarına izin verilir. Açılamazsa bağlantı panoya kopyalanabilir.
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') {
    showMessage(context, 'Bu bağlantı güvenli (https) değil; açılmadı.');
    return;
  }
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened) opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    showMessage(
      context,
      'Bağlantı açılamadı.',
      action: SnackBarAction(
        label: 'Kopyala',
        onPressed: () => Clipboard.setData(ClipboardData(text: url)),
      ),
    );
  }
}

Future<void> copyLink(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) showMessage(context, 'Bağlantı kopyalandı.');
}

Future<void> shareLink(BuildContext context, {required String title, required String url}) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: '$title\n$url\n\nTechPulse ile paylaşıldı',
        subject: title,
        sharePositionOrigin: box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (_) {
    if (context.mounted) showMessage(context, 'Paylaşım açılamadı.');
  }
}

/// Bağlantıyı açmadan önce adresini gösteren sayfa: aç, kopyala, paylaş.
/// Güvenlik açısından bağlantıyı kontrol etmek veya başka bir cihazda açmak isteyenler için.
Future<void> showLinkSheet(BuildContext context, {required String title, required String url}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final tp = sheetContext.tp;
      final uri = Uri.tryParse(url);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bağlantı', style: sheetContext.text.titleSmall),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: tp.surfaceAlt, borderRadius: BorderRadius.circular(Tp.radiusSmall)),
                child: SelectableText(
                  url,
                  style: TextStyle(fontFamily: Tp.monoFont, fontSize: 12.5, color: tp.text, height: 1.45),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: tp.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Güvenli bağlantı (https) · ${uri?.host ?? ''}',
                      style: sheetContext.text.labelSmall?.copyWith(color: tp.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        copyLink(context, url);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Kopyala'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        shareLink(context, title: title, url: url);
                      },
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Paylaş'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    openLink(context, url);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Tarayıcıda aç'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Kaydet düğmesi: dolu/boş simge ve kısa bir büyüme animasyonu.
class BookmarkButton extends ConsumerWidget {
  const BookmarkButton({super.key, required this.kind, required this.entry, this.onImage = false, this.size = 22});

  final BookmarkKind kind;
  final Entry entry;

  /// Görselin üzerindeyse yarı saydam koyu zeminli çizilir.
  final bool onImage;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = BookmarkRecord.keyFor(kind, entry.id);
    final saved = ref.watch(isBookmarkedProvider(key));
    final tp = context.tp;
    Future<void> toggle() async {
      final nowSaved = await ref.read(bookmarksProvider.notifier).toggle(kind, entry);
      if (!context.mounted) return;
      showMessage(
        context,
        nowSaved ? 'Kaydedilenlere eklendi.' : 'Kaydedilenlerden çıkarıldı.',
        action: nowSaved
            ? SnackBarAction(label: 'Göster', onPressed: () => ref.read(appTabProvider.notifier).select(AppTab.saved))
            : null,
      );
    }

    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        key: ValueKey(saved),
        size: size,
        color: onImage ? Colors.white : (saved ? tp.accent : tp.textSecondary),
      ),
    );
    final tooltip = saved ? 'Kaydedilenlerden çıkar' : 'Kaydet';
    if (onImage) return OverlayIconButton(tooltip: tooltip, onPressed: toggle, child: icon);
    return IconButton(tooltip: tooltip, onPressed: toggle, icon: icon);
  }
}

/// Görselin üzerindeki yuvarlak, yarı saydam düğme.
class OverlayIconButton extends StatelessWidget {
  const OverlayIconButton({super.key, required this.tooltip, required this.onPressed, required this.child});

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(dimension: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Kaynağın adresini kısaca gösteren satır (ör. "techcrunch.com/2026/11/…").
class LinkPreviewLine extends StatelessWidget {
  const LinkPreviewLine({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Row(
      children: [
        Icon(Icons.link_rounded, size: 15, color: tp.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            Fmt.prettyUrl(url),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: Tp.monoFont, fontSize: 12, color: tp.textSecondary),
          ),
        ),
      ],
    );
  }
}
