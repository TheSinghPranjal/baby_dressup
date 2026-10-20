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
import '../models/mia_looks.dart';
import '../models/mia_model_library.dart';
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

  /// Preloaded whole-body models. When one resolves for the current outfit
  /// it is drawn instead of the paper doll or the procedural body.
  final MiaModelLibrary? models;
  final SoftRenderer _renderer = SoftRenderer();
  final SoftRenderer _envRenderer = SoftRenderer();

  List<Part> _parts = const [];
  DollArt? _doll;
  List<String> _dollLayers = const [];
  GltfModel? _model;
  GltfModel? _fadeOut;
  double _fade = 1;
  static const _fadeSeconds = 0.30;
  OutfitState? _state;
  CharacterDefinition? _character;
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

  DressingScene(
    this.assembler, {
    this.dolls,
    this.models,
    this.showEnvironment = true,
    int seed = 7,
  }) : animator = CharacterAnimator(seed: seed) {
    dolls?.addListener(notifyListeners);
    models?.addListener(_onModels);
  }

  /// True when the current character is a 2D paper doll (no turntable).
  bool get isFlat => _doll != null;

  /// True when a whole-body GLB is on the turntable. Those files have no
  /// skeleton, so pose buttons are hidden; swipe, zoom and auto-rotate stay.
  bool get isModel => _model != null;

  /// Asset path of the model currently shown (the incoming one during a swap).
  String? get activeModelAsset => _model?.assetPath;

  /// True while the previous model is still fading out.
  bool get swapActive => _fadeOut != null;

  int get triangleCount => _renderer.lastTriangleCount;

  void _onModels() {
    final state = _state;
    final character = _character;
    if (state != null && character != null) show(state, character);
  }

  /// Rebuilds the visible parts when the outfit or character changes.
  void show(OutfitState state, CharacterDefinition character) {
    final changedChar = character.id != _characterId;
    final first = _state == null;
    final nextModel = models?.modelFor(state);
    final modelChanged = !identical(nextModel, _model);
    if (!identical(state, _state) || changedChar || modelChanged) {
      final outfitChanged =
          _state == null ||
          changedChar ||
          !mapEquals(state.items, _state!.items) ||
          !mapEquals(state.variants, _state!.variants);
      if (outfitChanged || modelChanged) {
        if (nextModel != null) {
          _doll = null;
          _dollLayers = const [];
          _parts = const [];
        } else {
          _doll = dolls?.artFor(character.id);
          if (_doll != null) {
            _dollLayers = dolls!.layersFor(state, _doll!);
            _parts = const [];
          } else {
            _parts = assembler.assemble(state, character);
          }
        }
        _retargetModel(
          nextModel,
          snap: first || changedChar || _model == null || nextModel == null,
        );
      }
      _state = state;
      _character = character;
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

  void _retargetModel(GltfModel? next, {required bool snap}) {
    if (identical(next, _model)) return;
    if (!snap && next != null && _model != null) {
      _fadeOut = _model;
      _fade = 0;
    } else {
      _fadeOut = null;
      _fade = 1;
    }
    _model = next;
  }

  void tick(double dt) {
    animator.update(dt);
    if (autoRotate && !isFlat) animator.turntable += dt * 0.7;
    if (_fade < 1) {
      _fade = (_fade + dt / _fadeSeconds).clamp(0.0, 1.0);
      if (_fade >= 1) _fadeOut = null;
    }
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
      final key =
          '${background.id}|${size.width}x${size.height}|${cam.pitch}|${cam.distance}';
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
    final model = _model;
    if (model != null) return _paintModelStack(canvas, size, cam, model);
    if (_doll != null) return _paintDoll(canvas, size, cam, _doll!);
    _renderer.render(
      canvas,
      size,
      cam,
      CharacterAssembler.toRenderItems(_parts, animator.solve()),
    );
  }

  /// Cross-fades the previous whole-body model into the next one. Both stay
  /// on the same transform, so the feet do not jump and the camera is left
  /// where the player put it. ~300ms, with a small scale-in on the new look.
  void _paintModelStack(
    Canvas canvas,
    Size size,
    OrbitCamera cam,
    GltfModel model,
  ) {
    final s = smoothstep(0, 1, _fade);
    final outgoing = _fadeOut;
    if (outgoing != null && s < 1) {
      _paintModel(canvas, size, cam, outgoing, opacity: 1 - s, pop: 1);
    }
    _paintModel(
      canvas,
      size,
      cam,
      model,
      opacity: outgoing == null ? 1 : s,
      pop: outgoing == null ? 1 : 0.96 + 0.04 * s,
    );
  }

  void _paintModel(
    Canvas canvas,
    Size size,
    OrbitCamera cam,
    GltfModel model, {
    required double opacity,
    required double pop,
  }) {
    if (opacity <= 0.01 || model.primitives.isEmpty) return;
    final motion = animator.flatMotion;
    final s = MiaLooks.worldScale * pop * (1 + 0.008 * motion.breath);
    final placed =
        Affine.translation(Vec3(0, motion.lift, 0)) *
        Affine.rotY(animator.turntable + motion.spin) *
        Affine.scale(Vec3(s, s, s));
    void draw() {
      _renderer.render(canvas, size, cam, [
        for (final prim in model.primitives)
          RenderItem(
            prim.mesh,
            placed,
            albedo: prim.albedo,
            color: prim.tint,
            gloss: 0.04,
            doubleSided: prim.doubleSided,
          ),
      ]);
    }

    if (opacity >= 0.999) {
      draw();
      return;
    }
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    draw();
    canvas.restore();
  }

  void _paintEnvironment(Canvas canvas, Size size, OrbitCamera cam) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
          Color(background.skyTop),
          Color(background.skyBottom),
        ]),
    );
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
    paintDollLayers(
      canvas,
      Rect.fromLTWH(-w / 2, -h, w, h),
      _dollLayers,
      dolls!,
    );
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
        ..shader = ui.Gradient.radial(
          c,
          rx,
          [const Color(0x55402040), const Color(0x00402040)],
          null,
          TileMode.clamp,
          Float64List.fromList([
            1,
            0,
            0,
            0,
            0,
            ry / rx,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            c.dy * (1 - ry / rx),
            0,
            1,
          ]),
        ),
    );
  }

  @override
  void dispose() {
    dolls?.removeListener(notifyListeners);
    models?.removeListener(_onModels);
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
