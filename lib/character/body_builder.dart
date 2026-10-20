import 'dart:math' as math;

import '../engine/math3d.dart';
import '../engine/mesh.dart';
import '../engine/primitives.dart';
import 'body_metrics.dart';
import 'character_definition.dart';
import 'part.dart';
import 'skeleton.dart';

/// Body region tags. Garments list the tags they fully cover in `hides`.
abstract final class BodyTags {
  static const torso = 'torso';
  static const pelvis = 'pelvis';
  static const neck = 'neck';
  static const ears = 'ears';
  static String upperArm(bool l) => Bones.side('upperArm', l);
  static String forearm(bool l) => Bones.side('forearm', l);
  static String thigh(bool l) => Bones.side('thigh', l);
  static String shin(bool l) => Bones.side('shin', l);
  static String foot(bool l) => Bones.side('foot', l);

  static const arms = {'upperArm_L', 'upperArm_R', 'forearm_L', 'forearm_R'};
  static const upperArms = {'upperArm_L', 'upperArm_R'};
  static const legs = {'thigh_L', 'thigh_R', 'shin_L', 'shin_R'};
  static const thighs = {'thigh_L', 'thigh_R'};
  static const feet = {'foot_L', 'foot_R'};
}

/// Builds the procedural body and face for a character.
class BodyBuilder {
  static List<Part> build(CharacterDefinition c) {
    final skin = c.skinTone;
    final parts = <Part>[];
    void add(String bone, Mesh m,
        {int? color, double bias = 0, String? tag, double gloss = 0.06}) {
      parts.add(Part(bone, m,
          color: color ?? skin, bias: bias, tag: tag, gloss: gloss));
    }

    // Head and face.
    add(
        Bones.head,
        Prim.lathe(Prim.smooth(Body.headProfile, steps: 3),
            segments: 28, sx: c.face.cheekWidth, sz: Body.headDepth),
        tag: 'head');
    for (final l in [true, false]) {
      final s = l ? 1.0 : -1.0;
      add(
          Bones.head,
          Prim.ellipsoid(0.018, 0.03, 0.022,
              center: Vec3(s * 0.145 * c.face.cheekWidth, 0.14, -0.01),
              segments: 10,
              rings: 8),
          tag: BodyTags.ears);
    }
    add(
        Bones.head,
        Prim.ellipsoid(0.008, 0.007, 0.008,
            center: Body.faceSurface(0, 0.098, offset: -0.0045), segments: 10),
        color: shadeArgb(skin, 0.97),
        bias: 0.004);
    parts.addAll(_face(c));

    // Neck and trunk.
    add(Bones.neck,
        Prim.capsule(0.11, 0.05, 0.056).transformed(
            Affine.translation(const Vec3(0, 0.07, 0))),
        tag: BodyTags.neck);
    add(
        Bones.spine,
        Prim.lathe(Prim.smooth(Body.torsoProfile, steps: 3),
            segments: 24, sz: Body.torsoDepth),
        tag: BodyTags.torso);
    add(
        Bones.hips,
        Prim.lathe(Prim.smooth(Body.pelvisProfile, steps: 3),
            segments: 24, sz: Body.pelvisDepth),
        tag: BodyTags.pelvis);

    // Limbs.
    for (final l in [true, false]) {
      add(Bones.side('upperArm', l),
          Prim.capsule(Body.upperArmLen, Body.upperArmR0, Body.upperArmR1),
          tag: BodyTags.upperArm(l));
      add(Bones.side('forearm', l),
          Prim.capsule(Body.forearmLen, Body.forearmR0, Body.forearmR1),
          tag: BodyTags.forearm(l));
      add(Bones.side('hand', l), handMesh(l), tag: Bones.side('hand', l));
      add(Bones.side('thigh', l),
          Prim.capsule(Body.thighLen, Body.thighR0, Body.thighR1),
          tag: BodyTags.thigh(l));
      add(Bones.side('shin', l),
          Prim.capsule(Body.shinLen, Body.shinR0, Body.shinR1),
          tag: BodyTags.shin(l));
      add(
          Bones.side('foot', l),
          Prim.ellipsoid(0.04, 0.032, 0.082,
              center: const Vec3(0, -0.03, 0.035), segments: 12),
          tag: BodyTags.foot(l));
    }
    // Peace-sign fingers (scaled to zero except in the peace pose).
    add(
        Bones.fingersR,
        Mesh.merge([
          Prim.capsule(0.05, 0.0085, 0.0075)
              .transformed(Affine.rotZ(-0.28) * Affine.translation(const Vec3(0, 0.004, 0))),
          Prim.capsule(0.05, 0.0085, 0.0075)
              .transformed(Affine.rotZ(0.28) * Affine.translation(const Vec3(0, 0.004, 0))),
        ]),
        tag: 'fingers');
    return parts;
  }

  static Mesh handMesh(bool left) {
    final palm = Prim.ellipsoid(0.024, 0.046, 0.034,
        center: const Vec3(0, -0.04, 0), segments: 12);
    final thumb = Prim.capsule(0.03, 0.009, 0.008).transformed(
        Affine.translation(const Vec3(0.0, -0.02, 0.022)) *
            Affine.rotX(-0.5));
    final m = Mesh.merge([palm, thumb]);
    return left ? m : m.transformed(Affine.scale(const Vec3(-1, 1, 1)));
  }

  static List<Part> _face(CharacterDefinition c) {
    final f = c.face;
    final parts = <Part>[];
    final es = f.eyeScale;
    for (final l in [true, false]) {
      final s = l ? 1.0 : -1.0;
      final eyeBone = l ? Bones.eyeL : Bones.eyeR;
      final ex = s * (0.058 + f.eyeSpacing);
      final orient = Affine.translation(Vec3(f.eyeSpacing * s, 0, 0)) *
          Affine.lookDir(Body.faceNormal(ex, 0.128)) *
          Affine.rotZ(s * f.eyeTilt);
      Part eyePart(Mesh m, int color, double bias, {double gloss = 0.1}) =>
          Part(eyeBone, m.transformed(orient),
              color: color, bias: bias, gloss: gloss, tag: 'eyes', decal: true);

      final rx = 0.035 * es, ry = 0.043 * es;
      parts.add(eyePart(Prim.disc(rx, ry, dome: 0.22, segments: 18),
          0xFFFFFDFB, 0.004));
      final iris = Prim.disc(rx * 0.74, ry * 0.8,
              dome: 0.3,
              segments: 18,
              center: Vec3(-s * 0.002, -0.004 * es, 0.0035))
          .painted((p, _) {
        final t = ((p.y + 0.03 * es) / (0.06 * es)).clamp(0.0, 1.0);
        return mixArgb(shadeArgb(c.eyeColor, 1.25), shadeArgb(c.eyeColor, 0.55), t);
      });
      parts.add(eyePart(iris, 0xFFFFFFFF, 0.006));
      parts.add(eyePart(
          Prim.disc(rx * 0.36, ry * 0.42,
              dome: 0.3, segments: 14, center: Vec3(-s * 0.002, -0.004 * es, 0.0065)),
          0xFF1E1420,
          0.008));
      parts.add(eyePart(
          Prim.disc(0.0075 * es, 0.0085 * es,
              dome: 0.4,
              segments: 10,
              center: Vec3(s * 0.008 * es, 0.01 * es, 0.009)),
          0xFFFFFFFF,
          0.01));
      parts.add(eyePart(
          Prim.disc(0.0035 * es, 0.0035 * es,
              dome: 0.4,
              segments: 8,
              center: Vec3(-s * 0.008 * es, -0.014 * es, 0.009)),
          0xFFFFFFFF,
          0.01));
      // Upper lash line with a small outward flick.
      final lash = <Vec3>[];
      for (var k = 0; k <= 10; k++) {
        final a = math.pi * (1.08 - 1.16 * k / 10);
        final ax = s * math.cos(a);
        lash.add(Vec3(rx * 1.04 * ax, ry * 0.98 * math.sin(a) + 0.002, 0.007));
      }
      lash.add(Vec3(s * rx * 1.32, ry * 0.42, 0.006));
      parts.add(eyePart(
          Prim.tube(lash,
              radii: [for (var k = 0; k < lash.length; k++) k == lash.length - 1 ? 0.0018 : 0.0042],
              sides: 6),
          0xFF2A1A22,
          0.012));

      // Eyebrow.
      final brow = <Vec3>[];
      for (var k = 0; k <= 8; k++) {
        final t = k / 8;
        final x = s * (0.028 + 0.062 * t) + s * f.eyeSpacing;
        final y = 0.19 + 0.012 * f.browArch * math.sin(t * math.pi) - 0.006 * t;
        brow.add(Body.faceSurface(x, y, offset: 0.002));
      }
      parts.add(Part(
          Bones.head,
          Prim.tube(brow,
              radii: [
                for (var k = 0; k <= 8; k++)
                  0.0038 * f.browThickness * (1.2 - 0.6 * k / 8)
              ],
              sides: 6),
          color: c.browColor,
          bias: 0.016,
          decal: true,
          tag: 'brows'));

      // Cheek blush.
      if (f.blush > 0) {
        final cp = Body.faceSurface(s * 0.088 * f.cheekWidth, 0.088, offset: 0.0005);
        parts.add(Part(
            Bones.head,
            Prim.disc(0.026, 0.014, dome: 0.08, segments: 14).transformed(
                Affine.translation(cp) *
                    Affine.lookDir(Body.faceNormal(s * 0.088, 0.088))),
            color: mixArgb(c.skinTone, 0xFFFF8FA3, 0.35 * f.blush),
            bias: 0.012,
            decal: true,
            gloss: 0));
      }
      if (f.freckles) {
        const spots = [Vec3(0.07, 0.1, 0), Vec3(0.085, 0.092, 0), Vec3(0.1, 0.1, 0), Vec3(0.078, 0.083, 0)];
        for (final sp in spots) {
          final p = Body.faceSurface(s * sp.x, sp.y, offset: 0.0012);
          parts.add(Part(Bones.head, Prim.sphere(0.0032, center: p, segments: 6),
              color: shadeArgb(c.skinTone, 0.72), bias: 0.016, decal: true));
        }
      }
    }

    // Smile.
    final mouth = <Vec3>[];
    for (var k = 0; k <= 10; k++) {
      final t = -1 + 2 * k / 10;
      final y = 0.07 - 0.009 * f.smile * (1 - t * t);
      mouth.add(Body.faceSurface(0.024 * t, y, offset: 0.0015));
    }
    parts.add(Part(
        Bones.head,
        Prim.tube(mouth,
            radii: [for (var k = 0; k <= 10; k++) 0.0026 + 0.0012 * math.sin(k / 10 * math.pi)],
            sides: 6),
        color: c.lipColor,
        bias: 0.02,
        decal: true,
        tag: 'mouth'));
    return parts;
  }
}
