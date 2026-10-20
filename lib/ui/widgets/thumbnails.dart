import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../character/character_definition.dart';
import '../../character/part.dart';
import '../../character/pose.dart';
import '../../character/skeleton.dart';
import '../../doll/doll_art.dart';
import '../../engine/math3d.dart';
import '../../engine/renderer.dart';
import '../../scene/character_assembler.dart';
import '../../wardrobe/garment.dart';
import '../../wardrobe/outfit_state.dart';

final _thumbRenderer = SoftRenderer();

/// Renders [parts] posed on [bones], auto-framed to fit [size].
void paintFramed(Canvas canvas, Size size, List<Part> parts, Map<String, Affine> bones,
    {double margin = 1.18, double pitch = 0.12}) {
  if (parts.isEmpty) return;
  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity;
  var maxY = -double.infinity, maxZ = -double.infinity;
  for (final p in parts) {
    final m = bones[p.bone] ?? Affine.identity;
    final pos = p.mesh.positions;
    final step = math.max(1, p.mesh.vertexCount ~/ 40) * 3;
    for (var i = 0; i < pos.length; i += step) {
      final w = m.point(Vec3(pos[i], pos[i + 1], pos[i + 2]));
      minX = math.min(minX, w.x);
      maxX = math.max(maxX, w.x);
      minY = math.min(minY, w.y);
      maxY = math.max(maxY, w.y);
      maxZ = math.max(maxZ, w.z);
    }
  }
  const fov = 0.5;
  final aspect = size.width / size.height;
  final h = math.max(maxY - minY, (maxX - minX) / aspect) * margin;
  final dist = h / (2 * math.tan(fov / 2)) + math.max(0, maxZ);
  final cam = OrbitCamera(
    pitch: pitch,
    distance: math.max(0.25, dist),
    targetY: (minY + maxY) / 2,
    targetX: (minX + maxX) / 2,
    fovY: fov,
  );
  _thumbRenderer.render(canvas, size, cam, CharacterAssembler.toRenderItems(parts, bones));
}

final Map<String, Affine> _thumbBones = Skeleton.solve(
  rotations: poseById('casual').rotations,
  scales: {Bones.fingersR: const Vec3(0.001, 0.001, 0.001)},
  turntable: 0.42,
);

/// 3D-rendered thumbnail of a single garment (no body).
class GarmentThumbnail extends StatelessWidget {
  final GarmentDefinition garment;
  final int variant;
  final CharacterDefinition character;
  final CharacterAssembler assembler;

  const GarmentThumbnail({
    super.key,
    required this.garment,
    required this.variant,
    required this.character,
    required this.assembler,
  });

  @override
  Widget build(BuildContext context) {
    final icon = AppScope.maybeOf(context)?.dolls.iconFor(character.id, garment.id);
    if (icon != null) return Image.asset(icon, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    return RepaintBoundary(
      child: ClipRect(
        child: CustomPaint(
          size: Size.infinite,
          painter: _GarmentPainter(garment, variant, character, assembler),
        ),
      ),
    );
  }
}

class _GarmentPainter extends CustomPainter {
  final GarmentDefinition g;
  final int variant;
  final CharacterDefinition c;
  final CharacterAssembler assembler;
  _GarmentPainter(this.g, this.variant, this.c, this.assembler);

  @override
  void paint(Canvas canvas, Size size) {
    final parts = assembler.garment(g, variant, c);
    final hair = g.slot == GarmentSlot.hair;
    paintFramed(canvas, size, parts, _thumbBones, margin: hair ? 1.1 : 1.2);
  }

  @override
  bool shouldRepaint(_GarmentPainter old) =>
      old.g.id != g.id || old.variant != variant || old.c.id != c.id ||
      old.g.assetVersion != g.assetVersion;
}

/// Static full-character render of an outfit (saved looks, avatars).
class LookThumbnail extends StatelessWidget {
  final OutfitState look;
  final CharacterDefinition character;
  final CharacterAssembler assembler;
  final bool headOnly;

  const LookThumbnail({
    super.key,
    required this.look,
    required this.character,
    required this.assembler,
    this.headOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final dolls = AppScope.maybeOf(context)?.dolls;
    final art = dolls?.artFor(character.id);
    if (art != null) {
      return RepaintBoundary(
        child: ClipRect(
          child: CustomPaint(
            size: Size.infinite,
            painter: _DollPainter(dolls!, art, dolls.layersFor(look, art), headOnly),
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: ClipRect(
        child: CustomPaint(
          size: Size.infinite,
          painter: _LookPainter(look, character, assembler, headOnly),
        ),
      ),
    );
  }
}

class _LookPainter extends CustomPainter {
  final OutfitState look;
  final CharacterDefinition c;
  final CharacterAssembler assembler;
  final bool headOnly;
  _LookPainter(this.look, this.c, this.assembler, this.headOnly);

  @override
  void paint(Canvas canvas, Size size) {
    final pose = poseById(look.poseId);
    final bones = Skeleton.solve(
      rotations: pose.rotations,
      scales: {...c.boneScales, Bones.fingersR: const Vec3(0.001, 0.001, 0.001), ...pose.scales},
      turntable: headOnly ? 0.0 : 0.25,
    );
    var parts = assembler.assemble(look, c);
    if (headOnly) {
      parts = [for (final p in parts) if (p.bone == Bones.head || p.bone == Bones.eyeL || p.bone == Bones.eyeR) p];
    }
    paintFramed(canvas, size, parts, bones, margin: headOnly ? 1.05 : 1.08, pitch: 0.06);
  }

  @override
  bool shouldRepaint(_LookPainter old) =>
      !identical(old.look, look) || old.c.id != c.id || old.headOnly != headOnly;
}

/// Paper-doll version of [_LookPainter]: the whole doll, or just her face.
class _DollPainter extends CustomPainter {
  final DollLibrary dolls;
  final DollArt art;
  final List<String> layers;
  final bool headOnly;
  _DollPainter(this.dolls, this.art, this.layers, this.headOnly) : super(repaint: dolls);

  @override
  void paint(Canvas canvas, Size size) {
    final base = dolls.image(art.base);
    if (base == null) return;
    final canvasSize = Size(base.width.toDouble(), base.height.toDouble());
    // The part of the doll canvas to show, in doll pixels.
    final focus = headOnly
        ? Rect.fromLTWH(art.headRect.left * canvasSize.width, art.headRect.top * canvasSize.height,
            art.headRect.width * canvasSize.width, art.headRect.height * canvasSize.height)
        : Offset.zero & canvasSize;
    final fit = headOnly ? BoxFit.cover : BoxFit.contain;
    final s = applyBoxFit(fit, focus.size, size).destination.width / focus.width;
    final shown = focus.size * s;
    canvas.translate((size.width - shown.width) / 2 - focus.left * s, (size.height - shown.height) / 2 - focus.top * s);
    paintDollLayers(canvas, Offset.zero & canvasSize * s, layers, dolls);
  }

  @override
  bool shouldRepaint(_DollPainter old) =>
      old.art != art || old.headOnly != headOnly || !listEquals(old.layers, layers);
}
