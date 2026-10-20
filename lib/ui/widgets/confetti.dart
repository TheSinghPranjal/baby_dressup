import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight confetti burst used when a look is saved.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => ConfettiBurstState();
}

class ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  final _rng = math.Random();
  List<_Bit> _bits = const [];

  void fire() {
    _bits = List.generate(70, (_) => _Bit(_rng));
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _c.isAnimating
              ? CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_bits, _c.value))
              : const SizedBox.shrink(),
        ),
      );
}

class _Bit {
  final double x, vx, vy, spin, size;
  final Color color;
  _Bit(math.Random r)
      : x = 0.3 + r.nextDouble() * 0.4,
        vx = (r.nextDouble() - 0.5) * 1.2,
        vy = -0.9 - r.nextDouble() * 0.8,
        spin = r.nextDouble() * 12,
        size = 5 + r.nextDouble() * 6,
        color = const [Color(0xFFF06FA0), Color(0xFFB79CF0), Color(0xFF8FDCC2), Color(0xFFFFD166), Color(0xFF7FB6F0)][
            r.nextInt(5)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Bit> bits;
  final double t;
  _ConfettiPainter(this.bits, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      final px = (b.x + b.vx * t) * size.width;
      final py = size.height * (0.55 + b.vy * t + 1.6 * t * t);
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(b.spin * t);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.55),
          Paint()..color = b.color.withValues(alpha: (1 - t).clamp(0, 1)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
