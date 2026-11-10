import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original, offline poster artwork. No remote artwork or copyrighted posters.
class NovaArtwork extends StatelessWidget {
  const NovaArtwork({
    super.key,
    required this.color,
    this.variant = 0,
    this.landscape = false,
    this.title,
  });

  final int color;
  final int variant;
  final bool landscape;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : (landscape ? 640.0 : 240.0);
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : width * (landscape ? .5625 : 1.5);
          return SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _ArtworkPainter(Color(color), variant, landscape),
                ),
                if (title != null)
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x38000000),
                          Colors.transparent,
                          Color(0xD90A0B10),
                        ],
                        stops: [0, .42, 1],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(math.max(12.0, width * .075)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'N O V A  /  C O L L E C T I O N',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              color: Colors.white.withAlpha(185),
                              fontSize: (width * .035).clamp(7, 11).toDouble(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            title!.toUpperCase(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Segoe UI',
                              color: const Color(0xFFF5F2EB),
                              height: 1.04,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              fontSize: (width * .115).clamp(16, 46).toDouble(),
                              shadows: const [
                                Shadow(color: Colors.black45, blurRadius: 15),
                              ],
                            ),
                          ),
                          SizedBox(height: height * .025),
                          Container(
                            height: 2,
                            width: width * .18,
                            color: Color(color).withAlpha(220),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArtworkPainter extends CustomPainter {
  const _ArtworkPainter(this.color, this.variant, this.landscape);

  final Color color;
  final int variant;
  final bool landscape;

  Color blend(Color other, double amount) => Color.lerp(color, other, amount)!;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            blend(const Color(0xFF101827), .72),
            const Color(0xFF070C14),
          ],
        ).createShader(rect),
    );
    switch (variant % 4) {
      case 0:
        _cosmos(canvas, size);
      case 1:
        _ocean(canvas, size);
      case 2:
        _dunes(canvas, size);
      case 3:
        _architecture(canvas, size);
    }
    final random = math.Random(207 + variant);
    final grain = Paint()..color = const Color(0x12FFFFFF);
    for (var index = 0; index < 220; index++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        random.nextDouble() * .65 + .15,
        grain,
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x18000000), Color(0xB0080C13)],
          stops: [0, .55, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  void _cosmos(Canvas canvas, Size size) {
    final center = Offset(size.width * .63, size.height * .34);
    final radius = math.min(size.width * .36, size.height * .39);
    final glowRect = Rect.fromCircle(center: center, radius: radius * 1.9);
    canvas.drawRect(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withAlpha(135), color.withAlpha(0)],
        ).createShader(glowRect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [blend(Colors.white, .7), color, const Color(0xFF101021)],
          stops: const [0, .24, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.34);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 3.8,
        height: radius * .65,
      ),
      Paint()
        ..color = blend(Colors.white, .6).withAlpha(95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, radius * .022),
    );
    canvas.restore();
    final random = math.Random(31 + variant);
    for (var i = 0; i < 50; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height * .7,
        ),
        i % 7 == 0 ? 1.1 : .55,
        Paint()..color = Colors.white.withAlpha(i % 7 == 0 ? 200 : 95),
      );
    }
    _ridge(canvas, size, .75, const Color(0xFF111A26), 0);
    _ridge(canvas, size, .85, const Color(0xFF090E18), .13);
  }

  void _ocean(Canvas canvas, Size size) {
    final horizon = size.height * .49;
    final sun = Offset(size.width * .65, horizon * .75);
    final sunRadius = math.min(size.width * .21, size.height * .19);
    canvas.drawCircle(
      sun,
      sunRadius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [blend(Colors.white, .86), color.withAlpha(190)],
        ).createShader(Rect.fromCircle(center: sun, radius: sunRadius)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withAlpha(190), const Color(0xFF09111B)],
            ).createShader(
              Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
            ),
    );
    final linePaint = Paint()
      ..color = blend(Colors.white, .55).withAlpha(85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    for (var i = 0; i < 19; i++) {
      final y = horizon + 2 + (i * i * .0013 + i * .006) * size.height;
      final wave = Path()..moveTo(-20, y);
      wave.cubicTo(
        size.width * .25,
        y - 6,
        size.width * .56,
        y + 6,
        size.width + 20,
        y - 2,
      );
      canvas.drawPath(wave, linePaint);
    }
    _ridge(canvas, size, .72, const Color(0xFF101C23), .15);
    _ridge(canvas, size, .83, const Color(0xFF080F18), -.08);
    final boat = Path()
      ..moveTo(size.width * .39, horizon + size.height * .12)
      ..lineTo(size.width * .47, horizon + size.height * .12)
      ..lineTo(size.width * .45, horizon + size.height * .13)
      ..lineTo(size.width * .41, horizon + size.height * .13)
      ..close();
    canvas.drawPath(boat, Paint()..color = const Color(0xFF070D14));
  }

  void _dunes(Canvas canvas, Size size) {
    final sun = Offset(size.width * .58, size.height * .27);
    final radius = math.min(size.width * .28, size.height * .23);
    canvas.drawCircle(
      sun,
      radius,
      Paint()..color = blend(const Color(0xFFFFE6B5), .8),
    );
    final layers = [
      (height: .44, light: .37, shift: -.04),
      (height: .59, light: .18, shift: .07),
      (height: .75, light: -.1, shift: -.13),
      (height: .91, light: -.45, shift: .06),
    ];
    for (final layer in layers) {
      final duneColor = layer.light >= 0
          ? blend(const Color(0xFFF2B776), layer.light)
          : blend(const Color(0xFF110F15), -layer.light);
      final y = size.height * layer.height;
      final path = Path()
        ..moveTo(-10, y + size.height * .18)
        ..cubicTo(
          size.width * (.21 + layer.shift),
          y - size.height * .2,
          size.width * .66,
          y + size.height * .19,
          size.width + 10,
          y - size.height * .08,
        )
        ..lineTo(size.width + 10, size.height + 10)
        ..lineTo(-10, size.height + 10)
        ..close();
      canvas.drawPath(path, Paint()..color = duneColor);
    }
  }

  void _architecture(Canvas canvas, Size size) {
    final glow = Rect.fromLTWH(
      size.width * .1,
      size.height * .06,
      size.width,
      size.height * .9,
    );
    canvas.drawRect(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withAlpha(150), Colors.transparent],
        ).createShader(glow),
    );
    for (var i = 5; i >= 0; i--) {
      final x = size.width * (.07 + i * .13);
      final top = size.height * (.21 - i * .021);
      final block = Rect.fromLTWH(x, top, size.width * .105, size.height * .65);
      canvas.drawRect(
        block,
        Paint()
          ..shader = LinearGradient(
            colors: [
              blend(const Color(0xFFD4DEE8), .36),
              blend(const Color(0xFF0D1420), .75),
            ],
          ).createShader(block),
      );
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + size.height * .65),
        Paint()
          ..color = blend(Colors.white, .7).withAlpha(130)
          ..strokeWidth = 1,
      );
    }
    final portal = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        size.width * .3,
        size.height * .36,
        size.width * .3,
        size.height * .38,
      ),
      topLeft: Radius.circular(size.width * .15),
      topRight: Radius.circular(size.width * .15),
    );
    canvas.drawRRect(portal, Paint()..color = const Color(0xFF08121E));
    canvas.drawRRect(
      portal.deflate(3),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withAlpha(10)],
        ).createShader(portal.outerRect),
    );
    final floor = Path()
      ..moveTo(0, size.height * .9)
      ..lineTo(size.width * .45, size.height * .68)
      ..lineTo(size.width, size.height * .94)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(floor, Paint()..color = const Color(0xFF090F19));
  }

  void _ridge(
    Canvas canvas,
    Size size,
    double height,
    Color ridgeColor,
    double shift,
  ) {
    final y = size.height * height;
    final path = Path()
      ..moveTo(-10, size.height)
      ..lineTo(-10, y + size.height * .06)
      ..lineTo(size.width * (.18 + shift), y - size.height * .10)
      ..lineTo(size.width * .34, y + size.height * .045)
      ..lineTo(size.width * .52, y - size.height * .05)
      ..lineTo(size.width * (.77 + shift), y - size.height * .17)
      ..lineTo(size.width + 10, y + size.height * .08)
      ..lineTo(size.width + 10, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = ridgeColor);
  }

  @override
  bool shouldRepaint(covariant _ArtworkPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.variant != variant ||
      oldDelegate.landscape != landscape;
}

class NovaMark extends StatelessWidget {
  const NovaMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'NOVA IPTV',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: const _MarkPainter()),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * .26),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA68BFF), Color(0xFF7052E8)],
        ).createShader(rect),
    );
    final mark = Path()
      ..moveTo(size.width * .25, size.height * .74)
      ..lineTo(size.width * .25, size.height * .27)
      ..lineTo(size.width * .37, size.height * .27)
      ..lineTo(size.width * .63, size.height * .64)
      ..lineTo(size.width * .63, size.height * .27)
      ..lineTo(size.width * .75, size.height * .27)
      ..lineTo(size.width * .75, size.height * .74)
      ..lineTo(size.width * .63, size.height * .74)
      ..lineTo(size.width * .37, size.height * .37)
      ..lineTo(size.width * .37, size.height * .74)
      ..close();
    canvas.drawPath(mark, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(size.width * .79, size.height * .2),
      size.width * .025,
      Paint()..color = const Color(0xFFE7DDFF),
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => false;
}
