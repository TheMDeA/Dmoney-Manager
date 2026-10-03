import 'package:flutter/material.dart';

/// Playful onboarding illustrations drawn in code, echoing the app's
/// dark + lime + violet palette.
enum OnboardingArtKind { monitoring, budgets, savings }

class OnboardingArt extends StatelessWidget {
  const OnboardingArt({super.key, required this.kind});

  final OnboardingArtKind kind;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArtPainter(kind),
      size: const Size(280, 260),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.kind);
  final OnboardingArtKind kind;

  static const _white = Color(0xFFFFFFFF);
  static const _ink = Color(0xFF101828);
  static const _lime = Color(0xFFC6FF4A);
  static const _violet = Color(0xFFA78BFA);
  static const _pink = Color(0xFFF472B6);
  static const _gold = Color(0xFFF5C518);
  static const _green = Color(0xFF34D399);
  static const _red = Color(0xFFF87171);
  static const _blue = Color(0xFF38BDF8);
  static const _orange = Color(0xFFFB923C);
  static const _muted = Color(0xFF3A3A40);

  void _dot(Canvas c, double x, double y, double r, Color color) {
    c.drawCircle(Offset(x, y), r, Paint()..color = color);
  }

  void _cross(Canvas c, double x, double y, double s, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(x - s, y - s), Offset(x + s, y + s), p);
    c.drawLine(Offset(x - s, y + s), Offset(x + s, y - s), p);
  }

  void _dash(Canvas c, double x, double y, double w, Color color) {
    c.drawLine(
      Offset(x, y),
      Offset(x + w, y),
      Paint()
        ..color = color
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _decorations(Canvas c) {
    _dot(c, 52, 56, 6, _violet);
    _dot(c, 232, 64, 5, _blue);
    _dot(c, 60, 208, 5, _orange);
    _dot(c, 226, 212, 6, _pink);
    _cross(c, 84, 96, 6, _blue);
    _cross(c, 208, 176, 6, _green);
    _cross(c, 96, 176, 6, _orange);
    _dash(c, 120, 40, 34, _muted);
    _dash(c, 236, 110, 4, _muted);
    _dash(c, 40, 140, 4, _muted);
    _dash(c, 128, 232, 28, _muted);
  }

  void _text(Canvas c, String s, double x, double y, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  void _card(Canvas c, Rect r, {double radius = 14}) {
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      Paint()..color = _white,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _monitoring(Canvas c) {
    // Document.
    _card(c, const Rect.fromLTWH(66, 76, 120, 128), radius: 12);
    // Folded corner.
    final fold = Path()
      ..moveTo(66, 76)
      ..lineTo(94, 76)
      ..lineTo(66, 104)
      ..close();
    c.drawPath(
        fold,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    // Ledger lines with colored dots.
    const dotColors = [_green, _gold, _red, _blue];
    for (var i = 0; i < 4; i++) {
      final y = 116.0 + i * 18;
      _dot(c, 88, y, 4, dotColors[i]);
      c.drawLine(
        Offset(100, y),
        Offset(168, y),
        Paint()
          ..color = const Color(0xFFD4D4D8)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
    // Mini bars.
    const bars = [18.0, 30.0, 13.0, 24.0, 34.0];
    const barColors = [_green, _gold, _red, _blue, _orange];
    for (var i = 0; i < bars.length; i++) {
      final x = 96.0 + i * 17;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 204 - bars[i], 10, bars[i]),
          const Radius.circular(3),
        ),
        Paint()..color = barColors[i],
      );
    }
    // Overlapping stat card.
    _card(c, const Rect.fromLTWH(168, 118, 84, 56), radius: 10);
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(180, 130, 16, 16), const Radius.circular(4)),
      Paint()..color = _blue,
    );
    c.drawLine(
        const Offset(202, 134), const Offset(232, 134), Paint()..color = _blue..strokeWidth = 4..strokeCap = StrokeCap.round);
    c.drawLine(
        const Offset(202, 143), const Offset(224, 143), Paint()..color = _blue..strokeWidth = 4..strokeCap = StrokeCap.round);
    _dot(c, 232, 158, 8, _orange);
    _dot(c, 242, 158, 8, _pink.withValues(alpha: 0.85));
    // Trend arrows.
    _arrow(c, const Offset(196, 100), true, _green);
    _arrow(c, const Offset(222, 100), false, _red);
  }

  void _arrow(Canvas c, Offset tip, bool up, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dir = up ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(tip.dx, tip.dy + 18 * dir)
      ..lineTo(tip.dx, tip.dy)
      ..moveTo(tip.dx - 7, tip.dy + 7 * dir)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + 7, tip.dy + 7 * dir);
    c.drawPath(path, p);
  }

  void _budgets(Canvas c) {
    // Progress ring.
    const center = Offset(140, 118);
    c.drawArc(
      Rect.fromCircle(center: center, radius: 64),
      0, 3.14159 * 2,
      false,
      Paint()
        ..color = _muted
        ..strokeWidth = 18
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    c.drawArc(
      Rect.fromCircle(center: center, radius: 64),
      -3.14159 / 2, 3.14159 * 2 * 0.72,
      false,
      Paint()
        ..color = _lime
        ..strokeWidth = 18
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    _text(c, '72%', center.dx, center.dy, 30, _white);
    // Coins.
    _coin(c, 104, 214, 17);
    _coin(c, 142, 220, 21);
    _coin(c, 182, 214, 17);
  }

  void _coin(Canvas c, double x, double y, double r) {
    c.drawCircle(Offset(x, y), r, Paint()..color = _gold);
    c.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    _text(c, '\$', x, y, r * 0.9, _ink);
  }

  void _savings(Canvas c) {
    // Jar body.
    _card(c, const Rect.fromLTWH(102, 92, 76, 116), radius: 16);
    // Lid.
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(96, 70, 88, 20), const Radius.circular(8)),
      Paint()..color = _pink,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(96, 70, 88, 20), const Radius.circular(8)),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Big coin.
    _coin(c, 140, 136, 27);
    // Coin stack.
    for (var i = 0; i < 3; i++) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(114, 172.0 + i * 11, 52, 8),
          const Radius.circular(4),
        ),
        Paint()..color = _gold,
      );
    }
    _coin(c, 186, 196, 15);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _decorations(canvas);
    switch (kind) {
      case OnboardingArtKind.monitoring:
        _monitoring(canvas);
        break;
      case OnboardingArtKind.budgets:
        _budgets(canvas);
        break;
      case OnboardingArtKind.savings:
        _savings(canvas);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
