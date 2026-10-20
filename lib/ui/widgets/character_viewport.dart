import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../scene/dressing_scene.dart';

/// Animated, touch-controllable 3D view of a [DressingScene].
///
/// One finger: horizontal swipe spins the turntable, vertical swipe orbits
/// the camera. Two fingers: pinch to zoom. Double-tap resets the camera.
class CharacterViewport extends StatefulWidget {
  final DressingScene scene;
  final bool interactive;
  final bool animate;

  const CharacterViewport({
    super.key,
    required this.scene,
    this.interactive = true,
    this.animate = true,
  });

  @override
  State<CharacterViewport> createState() => _CharacterViewportState();
}

class _CharacterViewportState extends State<CharacterViewport>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _zoomAtStart = 1;
  double _spinVelocity = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.animate) _ticker.start();
  }

  @override
  void didUpdateWidget(CharacterViewport old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!widget.animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero ? 0.016 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (_spinVelocity.abs() > 0.01) {
      widget.scene.rotateBy(_spinVelocity * dt);
      _spinVelocity *= 0.92;
    }
    widget.scene.tick(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paint = ClipRect(
      child: CustomPaint(
        painter: DressingScenePainter(widget.scene),
        size: Size.infinite,
        isComplex: true,
        willChange: widget.animate,
      ),
    );
    if (!widget.interactive) return paint;
    return Semantics(
      label: '3D character. Swipe to rotate, pinch to zoom, double tap to reset.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.scene.resetCamera,
        onScaleStart: (d) {
          _zoomAtStart = widget.scene.zoom;
          _spinVelocity = 0;
        },
        onScaleUpdate: (d) {
          if (d.pointerCount >= 2) {
            widget.scene.setZoom(_zoomAtStart * d.scale);
          } else {
            widget.scene.rotateBy(d.focalPointDelta.dx * 0.012);
            widget.scene.pitchBy(d.focalPointDelta.dy * 0.004);
          }
        },
        onScaleEnd: (d) {
          if (d.pointerCount <= 1) {
            _spinVelocity = (d.velocity.pixelsPerSecond.dx * 0.004).clamp(-8.0, 8.0);
          }
        },
        child: Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) {
              widget.scene.setZoom(widget.scene.zoom * (e.scrollDelta.dy > 0 ? 0.92 : 1.08));
            }
          },
          child: paint,
        ),
      ),
    );
  }
}
