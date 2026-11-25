import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Bağlantıyı uygulama içinde açılan tarayıcı sekmesinde açar (Android'de Custom Tabs,
/// iOS'ta Safari görünümü). Yalnızca https bağlantılarına izin verilir.
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (uri == null || uri.scheme != 'https') {
    messenger?.showSnackBar(const SnackBar(content: Text('Bu bağlantı güvenli değil, açılmadı.')));
    return;
  }
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened) opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
  }
}

Future<void> shareLink(BuildContext context, {required String title, required String url}) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: '$title\n$url\n\nTechPulse ile paylaşıldı',
        subject: title,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (_) {
    // Paylaşım penceresi açılamazsa sessizce geç.
  }
}

/// Kaydet / kayıttan çıkar düğmesi. Kaydedilince ikon dolar ve kısa bir büyüme animasyonu oynar.
/// [onImage] true ise görselin üzerinde okunacak koyu yuvarlak zeminle çizilir.
class BookmarkButton extends ConsumerWidget {
  const BookmarkButton({super.key, required this.kind, required this.entry, this.onImage = false, this.size = 22});

  final BookmarkKind kind;
  final Entry entry;
  final bool onImage;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = BookmarkRecord.keyFor(kind, entry.id);
    final saved = ref.watch(isBookmarkedProvider(key));
    final tp = context.tp;
    final color = saved ? (onImage ? Colors.white : tp.primary) : (onImage ? Colors.white : tp.textMuted);
    return _ToggleIcon(
      active: saved,
      icon: Icons.bookmark_border_rounded,
      activeIcon: Icons.bookmark_rounded,
      color: color,
      activeBackground: onImage ? tp.primary : null,
      onImage: onImage,
      size: size,
      tooltip: saved ? 'Kaydedilenlerden çıkar' : 'Kaydet',
      onPressed: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        final nowSaved = await ref.read(bookmarksProvider.notifier).toggle(kind, entry);
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text(nowSaved ? 'Kaydedilenlere eklendi' : 'Kaydedilenlerden çıkarıldı'),
            ),
          );
      },
    );
  }
}

/// Favori (beğen) düğmesi.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.kind, required this.entry, this.onImage = false});

  final BookmarkKind kind;
  final Entry entry;
  final bool onImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = BookmarkRecord.keyFor(kind, entry.id);
    final liked = ref.watch(isFavoriteProvider(key));
    final tp = context.tp;
    return _ToggleIcon(
      active: liked,
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      color: liked ? (onImage ? Colors.white : tp.danger) : (onImage ? Colors.white : tp.textMuted),
      activeBackground: onImage ? tp.danger : null,
      onImage: onImage,
      size: 22,
      tooltip: liked ? 'Favorilerden çıkar' : 'Favorilere ekle',
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(kind, entry),
    );
  }
}

/// Görselin üzerinde de okunabilen yuvarlak ikon düğmesi (geri, paylaş).
class OverlayIconButton extends StatelessWidget {
  const OverlayIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0x990B0D17),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 42, height: 42, child: Icon(icon, color: Colors.white, size: 21)),
        ),
      ),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.color,
    required this.onImage,
    required this.size,
    required this.tooltip,
    required this.onPressed,
    this.activeBackground,
  });

  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final Color color;
  final Color? activeBackground;
  final bool onImage;
  final double size;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final glyph = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
        child: child,
      ),
      child: Icon(active ? activeIcon : icon, key: ValueKey(active), color: color, size: size),
    );
    if (onImage) {
      return Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          selected: active,
          label: tooltip,
          child: Material(
            color: active && activeBackground != null ? activeBackground : const Color(0x990B0D17),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(width: 42, height: 42, child: Center(child: glyph)),
            ),
          ),
        ),
      );
    }
    return IconButton(tooltip: tooltip, isSelected: active, onPressed: onPressed, icon: glyph);
  }
}
