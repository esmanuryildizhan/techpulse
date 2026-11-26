import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// TechPulse logosu: "Konuşan sinyal".
///
/// Konuşma balonu, dünyadaki teknoloji gelişmelerinin anlaşılır bir Türkçeyle anlatılmasını; balonun
/// içindeki T harfi TechPulse'u ve Türkçeyi; köşeden yayılan iki dalga ise gündemin canlı olarak
/// izlendiğini anlatır. Geometri, uygulama simgesini üreten betikle (tools/brand/logo.py) birebir aynıdır;
/// böylece telefondaki simge ile uygulamanın içindeki logo aynı görünür.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36, this.background, this.foreground});

  final double size;

  /// Simgenin zemini (varsayılan: uygulama renginin simgedeki tonu).
  final Color? background;

  /// Balon ve dalgalar (varsayılan: beyaz).
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Semantics(
      label: 'TechPulse logosu',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: BrandMarkPainter(background: background ?? tp.brand, foreground: foreground ?? Colors.white),
        ),
      ),
    );
  }
}

class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({required this.background, required this.foreground, this.markScale = 0.66});

  final Color background;
  final Color foreground;

  /// Logonun simge içindeki büyüklüğü (simge kenarına oranı).
  final double markScale;

  // Birim karedeki geometri (tools/brand/logo.py ile aynı).
  static const _bubble = Rect.fromLTRB(0.17, 0.30, 0.71, 0.72);
  static const _bubbleRadius = 0.15;
  static const _tail = [Offset(0.22, 0.62), Offset(0.20, 0.81), Offset(0.37, 0.70)];
  static const _tBar = Rect.fromLTRB(0.31, 0.415, 0.57, 0.49);
  static const _tStem = Rect.fromLTRB(0.4025, 0.415, 0.4775, 0.62);
  static const _tRadius = 0.0375;
  static const _arcCenter = Offset(0.56, 0.45);
  static const _arcRadii = [0.225, 0.325];
  static const _arcWidth = 0.058;
  static const _arcStartDeg = -76.0;
  static const _arcEndDeg = -14.0;

  // Logonun kapladığı alan; simgede ortalamak için.
  static const _bounds = Rect.fromLTRB(0.17, 0.125, 0.885, 0.81);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(side * 0.225)),
      Paint()..color = background,
    );

    final scale = side * markScale / math.max(_bounds.width, _bounds.height);
    final dx = (size.width - _bounds.width * scale) / 2 - _bounds.left * scale;
    final dy = (size.height - _bounds.height * scale) / 2 - _bounds.top * scale;
    Offset p(Offset o) => Offset(dx + o.dx * scale, dy + o.dy * scale);
    Rect r(Rect rect) => Rect.fromPoints(p(rect.topLeft), p(rect.bottomRight));

    final fg = Paint()
      ..color = foreground
      ..isAntiAlias = true;
    canvas.drawRRect(RRect.fromRectAndRadius(r(_bubble), Radius.circular(_bubbleRadius * scale)), fg);
    canvas.drawPath(Path()..addPolygon([for (final o in _tail) p(o)], true), fg);

    final cut = Paint()..color = background;
    canvas.drawRRect(RRect.fromRectAndRadius(r(_tBar), Radius.circular(_tRadius * scale)), cut);
    canvas.drawRRect(RRect.fromRectAndRadius(r(_tStem), Radius.circular(_tRadius * scale)), cut);

    final wave = Paint()
      ..color = foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = _arcWidth * scale
      ..strokeCap = StrokeCap.round;
    final center = p(_arcCenter);
    const start = _arcStartDeg * math.pi / 180;
    const sweep = (_arcEndDeg - _arcStartDeg) * math.pi / 180;
    for (final radius in _arcRadii) {
      // Betikteki yay, verilen yarıçaptan içeri doğru çizilir; çizgi ortası (yarıçap - kalınlık/2).
      final rr = (radius - _arcWidth / 2) * scale;
      canvas.drawArc(Rect.fromCircle(center: center, radius: rr), start, sweep, false, wave);
    }
  }

  @override
  bool shouldRepaint(covariant BrandMarkPainter old) =>
      old.background != background || old.foreground != foreground || old.markScale != markScale;
}

/// Logo ve yazı: "TechPulse".
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 30, this.fontSize = 21});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        SizedBox(width: markSize * 0.32),
        Text(
          'TechPulse',
          style: TextStyle(
            fontFamily: Tp.serif,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: context.tp.text,
            height: 1,
          ),
        ),
      ],
    );
  }
}
