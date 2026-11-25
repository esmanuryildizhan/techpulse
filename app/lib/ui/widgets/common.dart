import 'package:flutter/material.dart';

import '../../core/categories.dart';
import '../../core/config.dart';
import '../../core/theme.dart';

/// Uygulama logosu: mor degrade zeminde nabız çizgisi.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF7047F5), Color(0xFF3988FF)],
        ),
      ),
      child: Icon(Icons.monitor_heart_outlined, color: Colors.white, size: size * 0.6),
    );
  }
}

/// Dokunulduğunda hafifçe küçülen kart: dokunmaya görsel geri bildirim verir.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.borderRadius = Tp.radius, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 110),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _down = value),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Kart zemini: koyu antrasit yüzey, ince düşük kontrastlı kenarlık, 16 px köşe.
class TpCard extends StatelessWidget {
  const TpCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.onTap, this.color, this.semanticLabel});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    // Material zemin: içindeki ListTile ve dokunma dalgaları kartın üzerinde doğru çizilir.
    final content = Material(
      color: color ?? tp.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tp.radius), side: BorderSide(color: tp.border)),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return content;
    return Pressable(onTap: onTap, semanticLabel: semanticLabel, child: content);
  }
}

/// Kartın üstündeki küçük renkli konu etiketi ("SİBER GÜVENLİK").
class CategoryKicker extends StatelessWidget {
  const CategoryKicker(this.category, {super.key, this.short = true});

  final TechCategory category;
  final bool short;

  @override
  Widget build(BuildContext context) {
    return Text(
      trUpper(short ? category.shortLabel : category.label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: category.tone(context.brightness),
      ),
    );
  }
}

/// Görselin üzerindeki koyu, yarı saydam konu etiketi.
class CategoryOverlayPill extends StatelessWidget {
  const CategoryOverlayPill(this.category, {super.key});

  final TechCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xCC0B0D17), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 13, color: category.color),
          const SizedBox(width: 6),
          Text(
            category.shortLabel,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Konu rozeti (ayrıntı ekranı ve listeler): konu renginde saydam zemin.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge(this.category, {super.key, this.onTap});

  final TechCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = category.tone(context.brightness);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: tone.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Text(category.label, style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: tone)),
        ],
      ),
    );
    if (onTap == null) return badge;
    return InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: badge);
  }
}

/// Kaynak adının baş harflerinden küçük logo.
class SourceAvatar extends StatelessWidget {
  const SourceAvatar({super.key, required this.name, this.size = 20});

  final String name;
  final double size;

  static const _palette = [
    Color(0xFF7047F5),
    Color(0xFF3988FF),
    Color(0xFF0EA5A4),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF16A34A),
    Color(0xFF64748B),
  ];

  @override
  Widget build(BuildContext context) {
    final words = name.replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ').split(' ').where((w) => w.isNotEmpty).toList();
    final initials = words.isEmpty
        ? '?'
        : words.length == 1
            ? words.first.characters.take(2).toString()
            : '${words[0].characters.first}${words[1].characters.first}';
    final color = _palette[name.codeUnits.fold<int>(0, (h, c) => h + c) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Text(
        trUpper(initials),
        style: TextStyle(fontFamily: 'Inter', fontSize: size * 0.42, fontWeight: FontWeight.w700, color: Colors.white, height: 1),
      ),
    );
  }
}

/// Kaynak · zaman · okuma süresi satırı.
class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.source, required this.time, this.minutes, this.avatar = true, this.trailing});

  final String source;
  final String time;
  final int? minutes;
  final bool avatar;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodySmall;
    return Row(
      children: [
        if (avatar) ...[SourceAvatar(name: source, size: 18), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(fontWeight: FontWeight.w600, color: context.tp.textSecondary),
          ),
        ),
        Text('  ·  $time', style: style),
        if (minutes != null) Text('  ·  $minutes dk', style: style),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

/// Bölüm başlığı ve isteğe bağlı "Tümünü gör" bağlantısı.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.actionLabel, this.onAction, this.padding});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(Tp.page, 28, Tp.page - 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: context.text.titleLarge)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(actionLabel!), const SizedBox(width: 2), const Icon(Icons.chevron_right_rounded, size: 18)],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bilgi kutusu: ikon, başlık ve açıklama (ör. "Önce bunu bil", makine çevirisi notu).
class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.icon, required this.title, required this.child, this.tone});

  final IconData icon;
  final String title;
  final Widget child;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? context.tp.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Tp.radius),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: context.text.titleSmall?.copyWith(color: color))),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Küçük istatistik kutusu (Profil).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, required this.icon, this.onTap});

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TpCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.tp.primary),
          const SizedBox(height: 10),
          Text(value, style: context.text.headlineSmall),
          const SizedBox(height: 2),
          Text(label, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Boş liste, hata veya bilgi durumu: ikon, başlık, açıklama ve isteğe bağlı düğme.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: tp.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: tp.primary),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: context.text.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Basit ekran başlığı (büyük yazı + açıklama), sekmelerin üst kısmında kullanılır.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tp.page, 12, Tp.page - 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: context.text.headlineMedium)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: context.text.bodyMedium),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Uygulama adı ve sloganı (Ana Sayfa başlığı).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tp.page, 10, Tp.page - 8, 6),
      child: Row(
        children: [
          const BrandMark(size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppConfig.appName, style: context.text.titleLarge?.copyWith(fontSize: 20)),
                Text(AppConfig.slogan, style: context.text.bodySmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
