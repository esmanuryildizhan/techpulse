import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/categories.dart';
import '../../core/config.dart';
import '../../core/theme.dart';

/// Haber görseli. Yayıncının kapak görseli varsa diskte önbelleğe alınarak gösterilir; yoksa veya
/// yüklenemezse konuya özel, her haber için farklı (kimliğinden türetilen) bir kapak çizilir.
class NewsImage extends StatelessWidget {
  const NewsImage({
    super.key,
    required this.url,
    required this.seed,
    required this.category,
    this.borderRadius = BorderRadius.zero,
    this.icon,
    this.label,
  });

  final String? url;

  /// Yedek kapağın deseni bu metinden türetilir (haber kimliği): aynı kapak iki haberde tekrar etmez.
  final String seed;
  final TechCategory category;
  final BorderRadius borderRadius;

  /// Yedek kapakta konu ikonu yerine gösterilecek ikon (ör. makale, model).
  final IconData? icon;

  /// Yedek kapağın köşesindeki küçük yazı (ör. kaynak adı).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final fallback = ProceduralCover(seed: seed, category: category, icon: icon, label: label);
    final image = url;
    final Widget child = image == null || !AppConfig.networkImages
        ? fallback
        : LayoutBuilder(
            builder: (context, constraints) {
              // Görsel, ekrandaki boyutuna yetecek çözünürlükte çözülür; küçük kartta 1200 piksellik görseli
              // belleğe açmak hem belleği hem pili boşa harcar. (Yatay görseller için yükseklik payı bırakılır.)
              final dpr = MediaQuery.devicePixelRatioOf(context);
              final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
              final h = constraints.maxHeight.isFinite ? constraints.maxHeight : w;
              final decodeWidth = (math.max(w, h * 1.9) * dpr).round().clamp(96, 1400);
              return CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 220),
                memCacheWidth: decodeWidth,
                placeholder: (context, _) => ColoredBox(color: context.tp.skeleton),
                errorWidget: (context, _, _) => fallback,
              );
            },
          );
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox.expand(child: child),
    );
  }
}

/// Konuya özel çizilmiş kapak: konu renginde degrade, kimlikten türetilen soyut desen ve konu ikonu.
class ProceduralCover extends StatelessWidget {
  const ProceduralCover({super.key, required this.seed, required this.category, this.icon, this.label});

  final String seed;
  final TechCategory category;
  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold<int>(17, (h, c) => (h * 31 + c) & 0x7fffffff);
    final base = category.color;
    final dark = context.brightness == Brightness.dark;
    final deep = Color.lerp(base, const Color(0xFF181713), dark ? 0.70 : 0.50)!;
    final mid = Color.lerp(base, const Color(0xFF23211C), dark ? 0.32 : 0.15)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + (hash % 7) / 6, -1),
              end: Alignment(1, 1 - (hash % 5) / 4),
              colors: [deep, mid],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _PatternPainter(hash: hash, color: Colors.white),
              ),
              Align(
                alignment: Alignment(0.7 - (hash % 3) * 0.2, 0.1),
                child: Icon(
                  icon ?? category.icon,
                  size: size.isFinite ? size * 0.42 : 64,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              if (label != null && size > 90)
                Positioned(
                  left: 12,
                  bottom: 10,
                  right: 12,
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({required this.hash, required this.color});

  final int hash;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(hash);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.09);
    final fill = Paint()..color = color.withValues(alpha: 0.05);
    final variant = hash % 3;
    if (variant == 0) {
      // Eş merkezli halkalar
      final center = Offset(size.width * (0.55 + random.nextDouble() * 0.4), size.height * random.nextDouble());
      for (var r = 24.0; r < size.longestSide * 1.2; r += 22 + random.nextDouble() * 10) {
        canvas.drawCircle(center, r, stroke);
      }
    } else if (variant == 1) {
      // Devre kartı benzeri çizgiler ve düğümler
      for (var i = 0; i < 9; i++) {
        final y = size.height * random.nextDouble();
        final x1 = size.width * random.nextDouble() * 0.5;
        final x2 = x1 + size.width * (0.2 + random.nextDouble() * 0.5);
        final path = Path()
          ..moveTo(x1, y)
          ..lineTo(x2, y)
          ..lineTo(x2 + 14, y + (random.nextBool() ? 14 : -14));
        canvas.drawPath(path, stroke);
        canvas.drawCircle(Offset(x1, y), 3, fill..color = color.withValues(alpha: 0.16));
      }
    } else {
      // Nokta ızgarası ve büyük daireler
      const step = 18.0;
      final dot = Paint()..color = color.withValues(alpha: 0.10);
      for (var x = step / 2; x < size.width; x += step) {
        for (var y = step / 2; y < size.height; y += step) {
          if (random.nextDouble() > 0.55) canvas.drawCircle(Offset(x, y), 1.3, dot);
        }
      }
      canvas.drawCircle(Offset(size.width * random.nextDouble(), size.height * 1.1), size.shortestSide * 0.7, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) => oldDelegate.hash != hash || oldDelegate.color != color;
}
