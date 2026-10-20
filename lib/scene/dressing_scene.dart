import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../character/character_definition.dart';
import '../character/part.dart';
import '../character/pose.dart';
import '../doll/doll_art.dart';
import '../engine/math3d.dart';
import '../engine/renderer.dart';
import '../wardrobe/outfit_state.dart';
import 'character_assembler.dart';
import 'environment.dart';

/// Owns everything needed to draw one animated character on a set:
/// animation state, camera, cached parts and a cached backdrop picture.
class DressingScene extends ChangeNotifier {
  final CharacterAssembler assembler;
  final CharacterAnimator animator;

  /// Paper-doll art; characters that have some are drawn flat.
  final DollLibrary? dolls;
  final SoftRenderer _renderer = SoftRenderer();
  final SoftRenderer _envRenderer = SoftRenderer();

  List<Part> _parts = const [];
  DollArt? _doll;
  List<String> _dollLayers = const [];
  OutfitState? _state;
  String? _characterId;
  BackgroundTheme background = kBackgrounds.first;
  bool showEnvironment;

  // Camera controls.
  double pitch = _defaultPitch;
  double zoom = 1.0;
  bool autoRotate = false;
  static const _defaultPitch = 0.1;

  ui.Picture? _envPicture;
  String? _envKey;

  DressingScene(this.assembler, {this.dolls, this.showEnvironment = true, int seed = 7})
      : animator = CharacterAnimator(seed: seed) {
    dolls?.addListener(notifyListeners);
  }

  /// True when the current character is a 2D paper doll (no turntable).
  bool get isFlat => _doll != null;

  int get triangleCount => _renderer.lastTriangleCount;

  /// Rebuilds the visible parts when the outfit or character changes.
  void show(OutfitState state, CharacterDefinition character) {
    final changedChar = character.id != _characterId;
    final first = _state == null;
    if (!identical(state, _state) || changedChar) {
      if (_state == null ||
          changedChar ||
          !mapEquals(state.items, _state!.items) ||
          !mapEquals(state.variants, _state!.variants)) {
        _doll = dolls?.artFor(character.id);
        if (_doll != null) {
          _dollLayers = dolls!.layersFor(state, _doll!);
          _parts = const [];
        } else {
          _parts = assembler.assemble(state, character);
        }
      }
      _state = state;
      _characterId = character.id;
      animator.baseScales = character.boneScales;
      animator.setPose(state.poseId, snap: first);
      final bg = backgroundById(state.backgroundId);
      if (bg.id != background.id) {
        background = bg;
        _invalidateEnv();
      }
      notifyListeners();
    }
  }

  void tick(double dt) {
    animator.update(dt);
    if (autoRotate && !isFlat) animator.turntable += dt * 0.7;
    notifyListeners();
  }

  void rotateBy(double radians) {
    animator.turntable += radians;
    notifyListeners();
  }

  void pitchBy(double d) {
    pitch = (pitch + d).clamp(-0.12, 0.55);
    _invalidateEnv();
    notifyListeners();
  }

  void setZoom(double z) {
    zoom = z.clamp(0.75, 2.6);
    _invalidateEnv();
    notifyListeners();
  }

  void resetCamera() {
    pitch = _defaultPitch;
    zoom = 1;
    animator.turntable = 0;
    _invalidateEnv();
    notifyListeners();
  }

  void _invalidateEnv() {
    _envPicture?.dispose();
    _envPicture = null;
    _envKey = null;
  }

  OrbitCamera cameraFor(Size size) {
    final aspect = size.width / math.max(1, size.height);
    final fit = math.max(3.0, 1.55 / aspect);
    final focus = ((zoom - 1) / 1.6).clamp(0.0, 1.0);
    return OrbitCamera(
      pitch: pitch,
      distance: fit / zoom,
      targetY: 0.84 + 0.5 * focus,
    );
  }

  void paint(Canvas canvas, Size size) {
    final cam = cameraFor(size);
    if (showEnvironment) {
      final key = '${background.id}|${size.width}x${size.height}|${cam.pitch}|${cam.distance}';
      if (_envKey != key) {
        _envPicture?.dispose();
        final rec = ui.PictureRecorder();
        _paintEnvironment(Canvas(rec), size, cam);
        _envPicture = rec.endRecording();
        _envKey = key;
      }
      canvas.drawPicture(_envPicture!);
    }
    _paintShadow(canvas, size, cam);
    if (_doll != null) return _paintDoll(canvas, size, cam, _doll!);
    _renderer.render(canvas, size, cam,
        CharacterAssembler.toRenderItems(_parts, animator.solve()));
  }

  void _paintEnvironment(Canvas canvas, Size size, OrbitCamera cam) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter,
              [Color(background.skyTop), Color(background.skyBottom)]));
    _envRenderer.render(canvas, size, cam, background.props);
  }

  /// Stands the paper doll on the origin at the same scale as the set.
  void _paintDoll(Canvas canvas, Size size, OrbitCamera cam, DollArt art) {
    final base = dolls!.image(art.base);
    if (base == null) return;
    final m = animator.flatMotion;
    final feet = cam.project(Vec3(0, m.lift, 0), size);
    final top = cam.project(Vec3(0, m.lift + art.worldHeight, 0), size);
    final h = feet.dy - top.dy;
    final w = h * base.width / base.height;
    canvas
      ..save()
      ..translate(feet.dx, feet.dy)
      ..scale(math.cos(m.spin), 1 + 0.004 * m.breath);
    paintDollLayers(canvas, Rect.fromLTWH(-w / 2, -h, w, h), _dollLayers, dolls!);
    canvas.restore();
  }

  void _paintShadow(Canvas canvas, Size size, OrbitCamera cam) {
    final c = cam.project(const Vec3(0, 0.001, 0), size);
    final ex = cam.project(const Vec3(0.26, 0.001, 0), size);
    final ez = cam.project(const Vec3(0, 0.001, 0.26), size);
    final rx = (ex - c).distance, ry = math.max(2.0, (ez - c).distance);
    final r = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    canvas.drawOval(
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, rx, [
            const Color(0x55402040),
            const Color(0x00402040),
          ], null, TileMode.clamp, Float64List.fromList([1, 0, 0, 0, 0, ry / rx, 0, 0, 0, 0, 1, 0, 0, c.dy * (1 - ry / rx), 0, 1])));
  }

  @override
  void dispose() {
    dolls?.removeListener(notifyListeners);
    _envPicture?.dispose();
    super.dispose();
  }
}

class DressingScenePainter extends CustomPainter {
  final DressingScene scene;
  DressingScenePainter(this.scene) : super(repaint: scene);

  @override
  void paint(Canvas canvas, Size size) => scene.paint(canvas, size);

  @override
  bool shouldRepaint(covariant DressingScenePainter old) => old.scene != scene;
}
