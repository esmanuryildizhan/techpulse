import 'package:flutter/material.dart';

import '../../core/categories.dart';
import '../../core/theme.dart';

/// Dokununca hafifçe küçülerek geri bildirim veren sarmalayıcı.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: widget.onTap == null ? null : (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// İnce kenarlıklı kart. İçindeki ListTile ve dokunma dalgaları kartın üzerinde doğru çizilsin diye Material.
class TpCard extends StatelessWidget {
  const TpCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.color, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Tp.radius),
      side: BorderSide(color: tp.border),
    );
    return Material(
      color: color ?? tp.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              customBorder: shape,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// Bölüm başlığı: başlık, isteğe bağlı açıklama ve sağda "Tümünü gör" gibi bir eylem.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.action, this.onAction, this.padding});

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: context.text.titleSmall?.copyWith(fontSize: 16.5, fontWeight: FontWeight.w700),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: context.text.bodySmall?.copyWith(color: tp.textTertiary)),
                ],
              ],
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(48, 40),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Kartlardaki küçük konu etiketi: konu renginde nokta ve ad.
class CategoryLabel extends StatelessWidget {
  const CategoryLabel(this.category, {super.key, this.short = true, this.color});

  final TechCategory category;
  final bool short;

  /// Görsel üzerindeyken metin rengi (ör. beyaz).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = category.tone(context.brightness);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color ?? tone, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            short ? category.shortLabel : category.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: color ?? tone,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Kaynak, zaman ve okuma süresi gibi bilgileri "·" ile ayırarak tek satırda gösterir.
class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.parts, this.leading, this.color, this.maxLines = 1});

  final List<String> parts;
  final Widget? leading;
  final Color? color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelSmall?.copyWith(color: color ?? context.tp.textTertiary, fontSize: 12);
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Flexible(
          child: Text(
            parts.where((p) => p.isNotEmpty).join('  ·  '),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Kaynağın baş harflerinden küçük bir rozet.
class SourceAvatar extends StatelessWidget {
  const SourceAvatar({super.key, required this.name, this.size = 18});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final letters = name.replaceAll(RegExp(r'[^A-Za-z0-9ÇĞİÖŞÜçğıöşü ]'), '').trim().split(RegExp(r'\s+'));
    final text = letters.isEmpty || letters.first.isEmpty
        ? '?'
        : (letters.length > 1
              ? '${letters[0][0]}${letters[1][0]}'
              : letters[0].substring(0, letters[0].length.clamp(1, 2)));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tp.surfaceAlt,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: tp.border),
      ),
      child: Text(
        trUpper(text),
        style: TextStyle(
          fontFamily: Tp.sans,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: tp.textSecondary,
          height: 1,
        ),
      ),
    );
  }
}

/// Küçük etiket (ör. "Yeni", "Fidye yazılımı").
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.tp.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: tone), const SizedBox(width: 4)],
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: tone, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Bilgi kutusu: "30 saniyede", "Neden önemli?", uyarılar.
class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key, required this.title, required this.child, this.icon, this.tone});

  final String title;
  final Widget child;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final color = tone ?? tp.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.brightness == Brightness.dark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(Tp.radius),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 17, color: color), const SizedBox(width: 8)],
              Expanded(
                child: Text(title, style: context.text.labelLarge?.copyWith(color: color, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Sayfanın üstündeki büyük başlık ve açıklama (sekme ekranları).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tp.page, 12, Tp.page, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: context.text.headlineMedium)),
                if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: context.text.bodyMedium)],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Boş durum: ikon, başlık, açıklama ve isteğe bağlı eylem.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 24 : 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: tp.surfaceAlt, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: tp.textSecondary),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: context.text.titleSmall?.copyWith(fontSize: 17)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

/// Geri alınamayan işlemler için onay penceresi. Onaylanırsa true döner.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final tp = context.tp;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: tp.textSecondary),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive ? FilledButton.styleFrom(backgroundColor: tp.danger, foregroundColor: Colors.white) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Kısa bilgi mesajı.
void showMessage(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action, duration: const Duration(seconds: 3)));
}
