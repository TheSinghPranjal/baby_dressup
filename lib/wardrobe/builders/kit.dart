import 'dart:math' as math;

import '../../character/body_builder.dart';
import '../../character/body_metrics.dart';
import '../../character/part.dart';
import '../../character/skeleton.dart';
import '../../engine/math3d.dart';
import '../../engine/mesh.dart';
import '../../engine/primitives.dart';

typedef Painter = int Function(Vec3 p, Vec3 n);

/// Garment construction helpers. All shells are authored against the shared
/// body metrics, so any garment fits every character on the shared rig.
abstract final class Kit {
  static const tau = 2 * math.pi;

  /// Profile restricted to [from, to] with interpolated end points.
  static List<P2> slice(List<P2> profile, double from, double to) {
    final out = <P2>[P2(Body.profileRadius(profile, from), from)];
    for (final p in profile) {
      if (p.y > from + 1e-4 && p.y < to - 1e-4) out.add(p);
    }
    out.add(P2(Body.profileRadius(profile, to), to));
    return out;
  }

  static Mesh _paint(Mesh m, int color, Painter? paint) =>
      paint == null ? m.solid(color) : m.painted(paint);

  /// Upper-body shell on the spine bone. Use [a0]/[a1] for open fronts.
  static Part torso(int color,
      {double from = -0.06,
      double to = 0.35,
      double grow = 0.013,
      double bias = Layer.top,
      double a0 = 0,
      double a1 = tau,
      double flare = 0,
      Painter? paint,
      double gloss = 0.05}) {
    final prof = [
      for (final p in slice(Prim.smooth(Body.torsoProfile, steps: 3), from, to))
        P2(p.r + (p.y < 0.08 ? flare * (0.08 - p.y) / (0.08 - from) : 0),
            p.y)
    ];
    final m = Prim.lathe(prof,
            segments: 30, sz: Body.torsoDepth, a0: a0, a1: a1, inflate: grow)
        .doubleSided();
    return Part(Bones.spine, _paint(m, color, paint),
        bias: bias, gloss: gloss);
  }

  /// Waistband region of bottoms on the spine bone (covers the lower torso).
  static Part waist(int color,
      {double top = 0.02, double grow = 0.006, Painter? paint, double bias = Layer.bottom}) {
    final prof = slice(Body.torsoProfile, -0.07, top);
    return Part(Bones.spine,
        _paint(Prim.lathe(prof, segments: 30, sz: Body.torsoDepth, inflate: grow).doubleSided(),
            color, paint),
        bias: bias);
  }

  /// Pelvis shell on the hips bone.
  static Part pelvis(int color,
      {double grow = 0.009, Painter? paint, double bias = Layer.bottom}) {
    final prof = Prim.smooth(Body.pelvisProfile, steps: 3);
    return Part(Bones.hips,
        _paint(Prim.lathe(prof, segments: 30, sz: Body.pelvisDepth, inflate: grow),
            color, paint),
        bias: bias, tag: 'garmentPelvis');
  }

  /// Leg shells from the hip down [length] (0.74 = ankle).
  static List<Part> legs(int color,
      {double length = 0.72,
      double grow = 0.008,
      double flare = 0,
      double bias = Layer.bottom,
      Painter? paint,
      double cuff = 0}) {
    final parts = <Part>[];
    for (final l in [true, false]) {
      final thighEnd = math.min(length, Body.thighLen);
      double rAt(double d) {
        // d = distance down the whole leg
        if (d <= Body.thighLen) {
          return lerpDouble(Body.thighR0, Body.thighR1, d / Body.thighLen);
        }
        return lerpDouble(
            Body.shinR0, Body.shinR1, (d - Body.thighLen) / Body.shinLen);
      }

      double flareAt(double d) => flare * smoothstep(0.3, length, d);
      final thighProf = <P2>[
        for (var k = 6; k >= 0; k--)
          P2(rAt(thighEnd * k / 6) + grow + flareAt(thighEnd * k / 6),
              -thighEnd * k / 6),
        P2(rAt(0) + grow, 0.05),
      ];
      parts.add(Part(
          Bones.side('thigh', l),
          _paint(Prim.lathe(thighProf, segments: 18).doubleSided(), color, paint),
          bias: bias));
      if (length > Body.thighLen) {
        final shinLen = length - Body.thighLen;
        final shinProf = <P2>[
          for (var k = 6; k >= 0; k--)
            P2(rAt(Body.thighLen + shinLen * k / 6) + grow +
                    flareAt(Body.thighLen + shinLen * k / 6),
                -shinLen * k / 6),
          P2(Body.shinR0 + grow + flareAt(Body.thighLen), 0.035),
        ];
        parts.add(Part(
            Bones.side('shin', l),
            _paint(Prim.lathe(shinProf, segments: 18).doubleSided(), color, paint),
            bias: bias));
        parts.add(Part(
            Bones.side('shin', l),
            _paint(Prim.sphere(Body.shinR0 + grow + flareAt(Body.thighLen) * 0.6,
                segments: 14), color, paint),
            bias: bias));
        if (cuff > 0) {
          parts.add(Part(
              Bones.side('shin', l),
              Prim.torus(Body.shinR1 + grow + flare + 0.004, cuff, sides: 6, segments: 16)
                  .transformed(Affine.translation(Vec3(0, -shinLen + cuff, 0))),
              color: shadeArgb(color, 0.92),
              bias: bias + 0.002));
        }
      } else if (cuff > 0) {
        parts.add(Part(
            Bones.side('thigh', l),
            Prim.torus(rAt(thighEnd) + grow + flare + 0.003, cuff, sides: 6, segments: 16)
                .transformed(Affine.translation(Vec3(0, -thighEnd + cuff, 0))),
            color: shadeArgb(color, 0.92),
            bias: bias + 0.002));
      }
    }
    return parts;
  }

  /// Sleeves from the shoulder down [length] (0.47 = wrist).
  static List<Part> sleeves(int color,
      {double length = 0.12,
      double grow = 0.008,
      double bias = Layer.top,
      double puff = 0,
      double flare = 0,
      Painter? paint,
      int? cuffColor}) {
    final parts = <Part>[];
    for (final l in [true, false]) {
      final upperEnd = math.min(length, Body.upperArmLen);
      final up = <P2>[
        P2(lerpDouble(Body.upperArmR0, Body.upperArmR1, upperEnd / Body.upperArmLen) +
            grow + (length <= Body.upperArmLen ? flare : 0) + puff * 0.3, -upperEnd),
        P2(Body.upperArmR0 + grow + puff, -upperEnd * 0.45),
        P2(Body.upperArmR0 + grow + 0.004 + puff * 0.8, 0.0),
        P2(Body.upperArmR0 * 0.7 + grow, 0.03),
        P2(0, Body.upperArmR0 + grow),
      ];
      parts.add(Part(Bones.side('upperArm', l),
          _paint(Prim.lathe(up, segments: 16).doubleSided(), color, paint),
          bias: bias));
      if (length > Body.upperArmLen) {
        final fl = math.min(length - Body.upperArmLen, Body.forearmLen);
        final fore = <P2>[
          P2(lerpDouble(Body.forearmR0, Body.forearmR1, fl / Body.forearmLen) + grow + flare, -fl),
          P2(Body.forearmR0 + grow, 0.0),
          P2(Body.forearmR0 + grow, 0.03),
        ];
        parts.add(Part(Bones.side('forearm', l),
            _paint(Prim.lathe(fore, segments: 14).doubleSided(), color, paint),
            bias: bias));
        parts.add(Part(Bones.side('forearm', l),
            _paint(Prim.sphere(Body.forearmR0 + grow + 0.003, segments: 12), color, paint),
            bias: bias));
        if (cuffColor != null) {
          parts.add(Part(
              Bones.side('forearm', l),
              Prim.torus(Body.forearmR1 + grow + flare + 0.002, 0.007, sides: 6, segments: 14)
                  .transformed(Affine.translation(Vec3(0, -fl + 0.008, 0))),
              color: cuffColor,
              bias: bias + 0.002));
        }
      }
    }
    return parts;
  }

  static Set<String> sleeveHides(double length) => {
        if (length >= Body.upperArmLen - 0.01) ...BodyTags.upperArms,
        if (length >= Body.upperArmLen + Body.forearmLen - 0.03) ...{
          'forearm_L',
          'forearm_R'
        },
      };

  static Set<String> legHides(double length) => {
        if (length >= Body.thighLen - 0.02) ...BodyTags.thighs,
        if (length >= Body.thighLen + Body.shinLen - 0.06) ...{'shin_L', 'shin_R'},
      };

  /// Skirt on the hips bone from [top] to [hem] (hip-space y).
  static Part skirt(int color,
      {double top = 0.06,
      double hem = -0.3,
      double rTop = 0.114,
      double rHem = 0.2,
      double pleats = 0,
      int pleatCount = 18,
      double bias = Layer.bottom,
      double depth = 0.72,
      Painter? paint,
      double gloss = 0.05}) {
    final prof = <P2>[];
    const steps = 14;
    for (var k = 0; k <= steps; k++) {
      final t = k / steps; // 0 = hem, 1 = top
      final y = lerpDouble(hem, top, t);
      final belly = math.sin(t * math.pi) * 0.008 * (1 - t);
      prof.add(P2(lerpDouble(rHem, rTop, math.pow(t, 0.8).toDouble()) + belly, y));
    }
    final m = Prim.lathe(prof,
        segments: pleats > 0 ? pleatCount * 2 : 40,
        sz: depth,
        radiusMod: pleats > 0
            ? (a, v) => 1 + pleats * (1 - v) * (((a * pleatCount / math.pi).floor().isEven) ? 1 : -1)
            : null);
    return Part(Bones.hips, _paint(m.doubleSided(), color, paint),
        bias: bias, gloss: gloss);
  }

  /// A path of points on the front of the torso (spine space).
  static List<Vec3> frontPath(List<List<double>> xy, {double offset = 0.02}) =>
      [for (final p in xy) Body.torsoFront(p[0], p[1], offset: offset)];

  static Part buttons(int color, double x, List<double> ys,
      {double offset = 0.016, double r = 0.006, double bias = Layer.top + 0.006}) {
    return Part(
        Bones.spine,
        Mesh.merge([
          for (final y in ys)
            Prim.disc(r, r, dome: 0.5, segments: 8)
                .transformed(Affine.translation(Body.torsoFront(x, y, offset: offset)))
        ]),
        color: color,
        bias: bias,
        gloss: 0.4,
        decal: true);
  }

  // --- Painters -----------------------------------------------------------

  static Painter stripes(int a, int b, {double freq = 70, double axisY = 1}) =>
      (p, _) => (math.sin(p.y * freq * axisY) > 0.25) ? b : a;

  static Painter dots(int base, int dot, {double freq = 60}) => (p, _) {
        final u = math.sin(p.x * freq) * math.sin(p.y * freq) *
            math.cos(p.z * freq * 0.7);
        return u > 0.55 ? dot : base;
      };

  static Painter plaid(int base, int line1, int line2, {double freq = 55}) =>
      (p, _) {
        final h = math.sin(p.y * freq);
        final v = math.sin(math.atan2(p.x, p.z) * 10);
        if (h > 0.85) return line1;
        if (v > 0.85) return line2;
        if (h > 0.6 && v > 0.6) return mixArgb(base, line1, 0.5);
        return base;
      };

  static Painter denim(int base) => (p, _) {
        final n = math.sin(p.x * 310 + p.y * 170) * math.sin(p.z * 260 - p.y * 90);
        return shadeArgb(base, 1 + 0.06 * n);
      };

  /// Fine vertical ribbing.
  static Painter rib(int base) => (p, _) {
        final a = math.atan2(p.x, p.z);
        return shadeArgb(base, 0.95 + 0.06 * math.sin(a * 90));
      };

  /// Soft cotton twill with faint diagonal weave.
  static Painter twill(int base) => (p, _) =>
      shadeArgb(base, 1 + 0.025 * math.sin((p.x + p.y + p.z) * 420));

  static Painter knit(int base) => (p, _) {
        final a = math.atan2(p.x, p.z);
        return shadeArgb(base, math.sin(a * 40) > 0 ? 1.0 : 0.9);
      };

  static Painter floral(int base, int petal, int center, {double freq = 45}) =>
      (p, _) {
        final u = math.sin(p.x * freq + 1.3) * math.sin(p.y * freq) +
            math.sin(p.z * freq * 0.8) * 0.4;
        if (u > 0.95) return center;
        if (u > 0.6) return petal;
        return base;
      };

  static Painter gradientY(int top, int bottom, double y0, double y1) =>
      (p, _) => mixArgb(bottom, top, ((p.y - y0) / (y1 - y0)).clamp(0.0, 1.0));
}
