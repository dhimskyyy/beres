import 'package:flutter/material.dart';

/// Widget Logo Resmi Google (4 Warna) dibuat dengan CustomPainter
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    final redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill;
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill;
    final greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill;

    final cx = w / 2;
    final cy = h / 2;
    final radius = w / 2;
    final strokeWidth = w * 0.22;

    // Blue horizontal bar
    final barRect = Rect.fromLTWH(cx, cy - strokeWidth / 2, radius, strokeWidth);
    canvas.drawRect(barRect, bluePaint);

    // Blue arc (Right)
    final outerRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final innerRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius - strokeWidth);

    final pathBlue = Path()
      ..arcTo(outerRect, -0.6, 0.9, false)
      ..arcTo(innerRect, 0.3, -0.9, false)
      ..close();
    canvas.drawPath(pathBlue, bluePaint);

    // Green arc (Bottom)
    final pathGreen = Path()
      ..arcTo(outerRect, 0.3, 1.25, false)
      ..arcTo(innerRect, 1.55, -1.25, false)
      ..close();
    canvas.drawPath(pathGreen, greenPaint);

    // Yellow arc (Bottom-Left to Left)
    final pathYellow = Path()
      ..arcTo(outerRect, 1.55, 1.3, false)
      ..arcTo(innerRect, 2.85, -1.3, false)
      ..close();
    canvas.drawPath(pathYellow, yellowPaint);

    // Red arc (Top)
    final pathRed = Path()
      ..arcTo(outerRect, 2.85, 1.8, false)
      ..arcTo(innerRect, 4.65, -1.8, false)
      ..close();
    canvas.drawPath(pathRed, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
