import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Heides Lens logo variants — minimal geometric icons + wordmark.
/// Inspired by Pi's clean, rounded identity.

class HeidesLogo {
  final int id;
  final String name;
  final Color accent;
  final Widget Function(double size) builder;

  const HeidesLogo({
    required this.id,
    required this.name,
    required this.accent,
    required this.builder,
  });
}

const List<HeidesLogo> heidesLogos = [
  HeidesLogo(
    id: 1,
    name: 'Spark',
    accent: Color(0xFF7C5CFF),
    builder: _sparkLogo,
  ),
  HeidesLogo(
    id: 2,
    name: 'Node',
    accent: Color(0xFF2DD4BF),
    builder: _nodeLogo,
  ),
  HeidesLogo(
    id: 3,
    name: 'Bolt',
    accent: Color(0xFFF59E0B),
    builder: _boltLogo,
  ),
  HeidesLogo(
    id: 4,
    name: 'Signal',
    accent: Color(0xFF38BDF8),
    builder: _signalLogo,
  ),
  HeidesLogo(
    id: 5,
    name: 'Hex',
    accent: Color(0xFFF472B6),
    builder: _hexLogo,
  ),
];

HeidesLogo logoById(int id) =>
    heidesLogos.firstWhere((l) => l.id == id, orElse: () => heidesLogos.first);

/// Icon-only mark for compact surfaces (top bar, activity bar).
class HeidesLogoMark extends StatelessWidget {
  final int id;
  final double size;

  const HeidesLogoMark({super.key, required this.id, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return logoById(id).builder(size);
  }
}

/// Full logo: mark + wordmark.
class HeidesLogoFull extends StatelessWidget {
  final int id;
  final double markSize;
  final double fontSize;
  final Color textColor;

  const HeidesLogoFull({
    super.key,
    required this.id,
    this.markSize = 28,
    this.fontSize = 20,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeidesLogoMark(id: id, size: markSize),
        const SizedBox(width: 10),
        Text(
          'Heides Lens',
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Variant builders
// ---------------------------------------------------------------------------

Widget _sparkLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7C5CFF), Color(0xFF4F46E5)],
      ),
      borderRadius: BorderRadius.circular(size * 0.28),
    ),
    child: CustomPaint(painter: _SparkPainter(color: Colors.white)),
  );
}

Widget _nodeLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF2DD4BF), width: size * 0.06),
    ),
    child: CustomPaint(painter: _NodePainter(color: const Color(0xFF2DD4BF))),
  );
}

Widget _boltLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B),
      borderRadius: BorderRadius.circular(size * 0.22),
    ),
    child: Icon(Icons.bolt_rounded, color: Colors.white, size: size * 0.62),
  );
}

Widget _signalLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
      ),
      shape: BoxShape.circle,
    ),
    child: CustomPaint(painter: _SignalPainter(color: Colors.white)),
  );
}

Widget _hexLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
      ),
      borderRadius: BorderRadius.circular(size * 0.2),
    ),
    child: CustomPaint(painter: _HexPainter(color: Colors.white)),
  );
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class _SparkPainter extends CustomPainter {
  final Color color;
  _SparkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final c = size.center(Offset.zero);
    final w = size.width * 0.55;
    final h = size.width * 0.55;
    final path = Path()
      ..moveTo(c.dx, c.dy - h / 2)
      ..quadraticBezierTo(c.dx + w * 0.06, c.dy - w * 0.06, c.dx + w / 2, c.dy)
      ..quadraticBezierTo(c.dx + w * 0.06, c.dy + w * 0.06, c.dx, c.dy + h / 2)
      ..quadraticBezierTo(c.dx - w * 0.06, c.dy + w * 0.06, c.dx - w / 2, c.dy)
      ..quadraticBezierTo(c.dx - w * 0.06, c.dy - w * 0.06, c.dx, c.dy - h / 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _NodePainter extends CustomPainter {
  final Color color;
  _NodePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.5;
    final dot = r * 0.22;

    final p1 = Offset(c.dx - r * 0.35, c.dy - r * 0.25);
    final p2 = Offset(c.dx + r * 0.35, c.dy - r * 0.25);
    final p3 = Offset(c.dx, c.dy + r * 0.4);

    final line = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(p1, p3, line);
    canvas.drawLine(p2, p3, line);

    final dotPaint = Paint()..color = color;
    canvas.drawCircle(p1, dot, dotPaint);
    canvas.drawCircle(p2, dot, dotPaint);
    canvas.drawCircle(p3, dot, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _NodePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SignalPainter extends CustomPainter {
  final Color color;
  _SignalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;

    final c = size.center(Offset.zero);
    final r = size.width * 0.34;
    for (var i = 0; i < 3; i++) {
      final arcR = r - i * size.width * 0.11;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: arcR),
        -0.5, // start at top
        2.4, // sweep ~137 degrees
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HexPainter extends CustomPainter {
  final Color color;
  _HexPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final c = size.center(Offset.zero);
    final r = size.width * 0.32;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final p = Offset(
        c.dx + r * 0.9 * math.cos(angle),
        c.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);

    // Center spark
    final spark = Paint()..color = color;
    final w = size.width * 0.2;
    final inner = Path()
      ..moveTo(c.dx, c.dy - w)
      ..quadraticBezierTo(c.dx + w * 0.12, c.dy - w * 0.1, c.dx + w, c.dy)
      ..quadraticBezierTo(c.dx + w * 0.12, c.dy + w * 0.1, c.dx, c.dy + w)
      ..quadraticBezierTo(c.dx - w * 0.12, c.dy + w * 0.1, c.dx - w, c.dy)
      ..quadraticBezierTo(c.dx - w * 0.12, c.dy - w * 0.1, c.dx, c.dy - w)
      ..close();
    canvas.drawPath(inner, spark);
  }

  @override
  bool shouldRepaint(covariant _HexPainter oldDelegate) =>
      oldDelegate.color != color;
}