import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Kaydet / kayıttan çıkar düğmesi.
class BookmarkButton extends ConsumerWidget {
  const BookmarkButton({super.key, required this.kind, required this.entry, this.compact = false});

  final BookmarkKind kind;
  final Entry entry;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = BookmarkRecord.keyFor(kind, entry.id);
    final saved = ref.watch(isBookmarkedProvider(key));
    final color = saved ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant;
    return IconButton(
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      tooltip: saved ? 'Kaydedilenlerden çıkar' : 'Kaydet',
      isSelected: saved,
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: color),
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
