import 'dart:math' as math;

import '../../character/body_metrics.dart';
import '../../character/part.dart';
import '../../character/skeleton.dart';
import '../../engine/math3d.dart';
import '../../engine/mesh.dart';
import '../../engine/primitives.dart';
import '../garment.dart';

/// Hair tags: hats hide [top] pieces (buns, high ponytails).
abstract final class HairTags {
  static const top = 'hairTop';
}

const _hairVariants = [
  ColorVariant('Natural', 0, natural: true),
  ColorVariant('Honey Blonde', 0xFFE8C07A),
  ColorVariant('Chestnut', 0xFF7A4A2E),
  ColorVariant('Jet Black', 0xFF26222B),
  ColorVariant('Cotton Candy', 0xFFF7A6C6),
  ColorVariant('Lavender', 0xFFB9A0E8),
  ColorVariant('Mint', 0xFF9EDFC8),
  ColorVariant('Copper', 0xFFC0623A),
];

int Function(Vec3, Vec3) _strands(int c, {double freq = 46}) => (p, _) {
      final a = math.atan2(p.x, p.z);
      final s = math.sin(a * freq + p.y * 9) * 0.5 + math.sin(a * freq * 0.37 + 1.7) * 0.5;
      return shadeArgb(c, 0.93 + 0.13 * s);
    };

const _gloss = 0.45;

Part _hp(Mesh m, int c, {String bone = Bones.head, double bias = Layer.hair, String? tag}) =>
    Part(bone, m.painted(_strands(c)), bias: bias, gloss: _gloss, tag: tag);

/// Skull cap with a hairline that is high at the front and low at the nape.
Mesh _cap({double grow = 0.0, double front = 0.64, double back = 0.22}) {
  const c = Vec3(0, 0.176, -0.006);
  final rx = 0.162 + grow, ry = 0.157 + grow, rz = 0.153 + grow;
  return Prim.surface(30, 12, (u, v) {
    final a = 2 * math.pi * u;
    final f = math.pow((1 + math.cos(a)) / 2, 1.5).toDouble();
    final pMin = math.pi * (back + (front - back) * f);
    final phi = pMin + (math.pi - pMin) * v;
    final s = math.sin(phi);
    return Vec3(c.x + rx * s * math.sin(a), c.y - ry * math.cos(phi), c.z + rz * s * math.cos(a));
  }, wrapU: true).doubleSided(innerShade: 0.6);
}

/// Hanging curtain of hair behind the head and down the back.
Mesh _curtain({
  double top = 0.2,
  double bottom = -0.3,
  double rTop = 0.163,
  double rMid = 0.172,
  double rBottom = 0.15,
  double frontTop = 0.95,
  double frontBottom = 2.05,
  double wave = 0,
  double shoulderY = 0.02,
}) {
  return Prim.surface(30, 14, (u, v) {
    final y = lerpDouble(bottom, top, v);
    final sideT = smoothstep(shoulderY - 0.04, shoulderY + 0.12, y);
    final amin = lerpDouble(frontBottom, frontTop, sideT);
    final a = amin + (2 * math.pi - 2 * amin) * u;
    final r0 = y > 0.06
        ? lerpDouble(rMid, rTop, smoothstep(0.06, top, y))
        : lerpDouble(rBottom, rMid, smoothstep(bottom, 0.06, y));
    final r = r0 * (1 + wave * math.sin(a * 9 + y * 26) + wave * 0.6 * math.sin(y * 40));
    return Vec3(r * math.sin(a), y, r * 0.95 * math.cos(a) - 0.012);
  }).doubleSided(innerShade: 0.55);
}

/// Strands of fringe over the forehead.
Mesh _bangs({int count = 7, double sweep = 0, double length = 0.2, double width = 0.115}) {
  final strands = <Mesh>[];
  for (var k = 0; k < count; k++) {
    final t = count == 1 ? 0.5 : k / (count - 1);
    final x0 = lerpDouble(-width, width, t);
    final pts = <Vec3>[];
    final radii = <double>[];
    const n = 6;
    for (var j = 0; j <= n; j++) {
      final s = j / n;
      final y = lerpDouble(0.3, length, s);
      final x = x0 * (0.4 + 0.6 * s) + sweep * s * s;
      pts.add(Body.faceSurface(x, y, offset: 0.017 - 0.006 * s));
      radii.add(lerpDouble(0.022, 0.006, s * s));
    }
    strands.add(Prim.tube(pts, radii: radii, sides: 7));
  }
  return Mesh.merge(strands);
}

/// Face-framing locks at the temples.
Mesh _sideLocks({double bottom = 0.05, double flare = 0.0}) {
  return Mesh.merge([
    for (final s in [1.0, -1.0])
      Prim.tube([
        for (var j = 0; j <= 6; j++)
          () {
            final t = j / 6;
            final y = lerpDouble(0.25, bottom, t);
            final p = Body.faceSurface(s * lerpDouble(0.128, 0.122 + flare, t), y, offset: 0.012 + flare * t);
            return p;
          }()
      ], radii: [for (var j = 0; j <= 6; j++) lerpDouble(0.017, 0.007, j / 6)], sides: 7)
  ]);
}

Mesh _tail(List<Vec3> path, List<double> radii) => Prim.tube(path, radii: radii, sides: 10);

Mesh _braid(List<Vec3> path, double r) {
  final beads = <Mesh>[];
  for (var k = 0; k < path.length - 1; k++) {
    for (var j = 0; j < 3; j++) {
      final t = j / 3;
      final p = path[k].lerp(path[k + 1], t);
      final side = ((k * 3 + j).isEven ? 1 : -1) * r * 0.35;
      final rr = r * (1 - 0.35 * (k * 3 + j) / (path.length * 3));
      beads.add(Prim.ellipsoid(rr, rr * 1.25, rr, center: p + Vec3(side, 0, 0), segments: 10, rings: 7));
    }
  }
  return Mesh.merge(beads);
}

Part _tie(Vec3 at, int color, {double r = 0.03, Vec3 tilt = Vec3.zero}) => Part(
    Bones.head,
    Prim.torus(r, 0.01, segments: 14, sides: 6).transformed(Affine.translation(at) * Affine.euler(tilt)),
    color: color,
    bias: Layer.hair + 0.004,
    gloss: 0.3);

/// Curtain bangs parted in the middle, sweeping out to the temples.
Mesh _curtainBangs() {
  final strands = <Mesh>[];
  for (final s in [1.0, -1.0]) {
    for (var k = 0; k < 9; k++) {
      final pts = <Vec3>[];
      final radii = <double>[];
      const n = 9;
      // Inner strands sweep out from the part; outer ones hug the temples.
      final reach = 0.1 + 0.004 * k;
      final drop = 0.1 + 0.009 * k + (k.isEven ? 0.0 : 0.01);
      for (var j = 0; j <= n; j++) {
        final t = j / n;
        final x = s * (0.004 + 0.009 * k * (1 - 0.5 * t) + reach * math.pow(t, 0.7));
        final y = 0.305 - 0.007 * k * (1 - t) - drop * math.pow(t, 1.25);
        pts.add(Body.faceSurface(x, y, offset: 0.021 - 0.01 * t + 0.0015 * (8 - k) * (1 - t)));
        radii.add(lerpDouble(0.021, 0.006, t * t));
      }
      strands.add(Prim.tube(pts, radii: radii, sides: 7));
    }
  }
  return Mesh.merge(strands);
}

/// Thin wavy strands that escaped the bun, framing the face.
Mesh _tendrils() => Mesh.merge([
      for (final s in [1.0, -1.0])
        for (final lane in [
          (x: 0.132, z: 0.035, bottom: 0.03, r: 0.0065),
          (x: 0.148, z: -0.02, bottom: 0.06, r: 0.0055),
          (x: 0.12, z: 0.06, bottom: 0.1, r: 0.0045),
        ])
          Prim.tube([
            for (var j = 0; j <= 10; j++)
              () {
                final t = j / 10;
                final y = lerpDouble(0.23, lane.bottom, t);
                final wig = 0.012 * math.sin(t * math.pi * 2.2 + lane.x * 40) * t;
                final face = Body.faceSurface(s * (lane.x + wig), y, offset: 0.006);
                return Vec3(face.x + s * 0.004, y, lane.z > 0 ? face.z - 0.07 + lane.z : lane.z);
              }()
          ], radii: [for (var j = 0; j <= 10; j++) lerpDouble(lane.r, 0.0025, j / 10)], sides: 5),
    ]);

/// Loose, lived-in top bun built from overlapping loops.
Mesh _messyBun() => Mesh.merge([
      Prim.ellipsoid(0.058, 0.05, 0.055, center: const Vec3(0, 0.35, -0.045), segments: 14),
      Prim.ellipsoid(0.042, 0.04, 0.045, center: const Vec3(-0.035, 0.37, -0.03), segments: 12),
      Prim.ellipsoid(0.04, 0.042, 0.04, center: const Vec3(0.032, 0.375, -0.06), segments: 12),
      Prim.ellipsoid(0.036, 0.036, 0.036, center: const Vec3(0.005, 0.395, -0.035), segments: 12),
      Prim.torus(0.038, 0.016, segments: 16, sides: 7)
          .transformed(Affine.translation(const Vec3(0.02, 0.38, -0.02)) * Affine.rotX(1.2) * Affine.rotZ(0.5)),
      Prim.torus(0.032, 0.013, segments: 16, sides: 7)
          .transformed(Affine.translation(const Vec3(-0.028, 0.385, -0.06)) * Affine.rotX(-0.9) * Affine.rotZ(-0.7)),
      // A couple of short loose loops for the messy look.
      Prim.torus(0.022, 0.006, segments: 12, sides: 5, a0: 0, a1: 4.2)
          .transformed(Affine.translation(const Vec3(0.05, 0.385, -0.03)) * Affine.rotX(1.3)),
      Prim.torus(0.02, 0.006, segments: 12, sides: 5, a0: 0, a1: 4.0)
          .transformed(Affine.translation(const Vec3(-0.05, 0.38, -0.05)) * Affine.rotX(-1.2) * Affine.rotZ(0.6)),
    ]);

List<GarmentDefinition> buildHair() => [
      GarmentDefinition(
        id: 'hair_messy_bun',
        name: 'Messy High Bun',
        subtype: 'Bun',
        category: GarmentCategory.hair,
        slot: GarmentSlot.hair,
        variants: _hairVariants,
        build: (c) => [
          _hp(_cap(grow: 0.0, front: 0.67, back: 0.3), c.primary),
          _hp(_curtainBangs(), c.primary, bias: Layer.hair + 0.006),
          _hp(_tendrils(), c.primary, bias: Layer.hair + 0.004),
          _hp(_messyBun(), c.primary, tag: HairTags.top),
          Part(
              Bones.head,
              Prim.torus(0.042, 0.016, segments: 20, sides: 8)
                  .transformed(Affine.translation(const Vec3(0, 0.316, -0.045)) * Affine.rotX(-0.35))
                  .painted((p, _) => shadeArgb(0xFFF28AA2, 0.92 + 0.1 * math.sin(math.atan2(p.x, p.z) * 14))),
              bias: Layer.hair + 0.004,
              gloss: 0.15,
              tag: HairTags.top),
        ],
      ),
      GarmentDefinition(
        id: 'hair_long_straight',
        name: 'Long & Sleek',
        subtype: 'Long Straight',
        category: GarmentCategory.hair,
        slot: GarmentSlot.hair,
        variants: _hairVariants,
        hides: {'ears'},
        build: (c) => [
          _hp(_cap(), c.primary),
          _hp(_curtain(bottom: -0.36), c.primary, bias: Layer.hair - 0.004),
          _hp(_bangs(count: 8, length: 0.205), c.primary, bias: Layer.hair + 0.006),
          _hp(_sideLocks(bottom: -0.02), c.primary, bias: Layer.hair + 0.004),
        ],
      ),
      GarmentDefinition(
        id: 'hair_long_waves',
        name: 'Mermaid Waves',
        subtype: 'Wavy',
        category: GarmentCategory.hair,
        slot: GarmentSlot.hair,
        variants: _hairVariants,
        hides: {'ears'},
        build: (c) => [
          _hp(_cap(grow: 0.004, front: 0.66), c.primary),
          _hp(_curtain(bottom: -0.34, wave: 0.06, rMid: 0.182, rBottom: 0.17), c.primary,
              bias: Layer.hair - 0.004),
          _hp(_bangs(count: 5, sweep: 0.05, length: 0.225, width: 0.1), c.primary, bias: Layer.hair + 0.006),
          _hp(_sideLocks(bottom: -0.05, flare: 0.02), c.primary, bias: Layer.hair + 0.004),
        ],
      ),
      GarmentDefinition(
        id: 'hair_high_ponytail',
        name: 'High Ponytail',
        subtype: 'Ponytail',
        category: GarmentCategory.hair,
        slot: GarmentSlot.hair,
        variants: _hairVariants,
        build: (c) => [
          _hp(_cap(grow: -0.002, front: 0.66, back: 0.3), c.primary),
          _hp(_bangs(count: 5, sweep: -0.03, length: 0.22, width: 0.1), c.primary, bias: Layer.hair + 0.006),
          _hp(
              _tail([
                const Vec3(0, 0.29, -0.125),
                const Vec3(0, 0.3, -0.2),
                const Vec3(0, 0.22, -0.25),
                const Vec3(0, 0.08, -0.25),
                const Vec3(0, -0.04, -0.22),
              ], [0.04, 0.05, 0.052, 0.038, 0.012]),
              c.primary,
              tag: HairTags.top),
          _tie(const Vec3(0, 0.292, -0.135), c.variant.natural ? 0xFFF26D9A : 0xFFFFFFFF,
              r: 0.034, tilt: const Vec3(1.2, 0, 0)),
        ],
      ),
      GarmentDefinition(
        id: 'hair_twin_braids',
        name: 'Twin Braids',
        subtype: 'Braids',
        category: GarmentCategory.hair,
        slot: GarmentSlot.hair,
        variants: _hairVariants,
        build: (c) => [
          _hp(_cap(front: 0.65, back: 0.28), c.primary),
          _hp(_bangs(count: 7, length: 0.215), c.primary, bias: Layer.hair + 0.006),
          for (final s in [1.0, -1.0]) ...[
            _hp(
                _braid([
                  Vec3(s * 0.13, 0.12, -0.07),
                  Vec3(s * 0.14, 0.0, -0.03),
                  Vec3(s * 0.13, -0.12, 0.05),
                  Vec3(s * 0.11, -0.26, 0.085),
                ], 0.03),
                c.primary,
                bias: Layer.hair + 0.004),
            _tie(Vec3(s * 0.11, -0.27, 0.085), 0xFFF7C948, r: 0.016),
          ],
        ],
      ),
      GarmentDefinition(
        id: 'hair_top_bun',
        name: 'Ballerina Bun',
        subtype: 'Bun',
        category: GarmentCategory.hair,
        slot: GarmentSlot.hair,
        variants: _hairVariants,
        build: (c) => [
          _hp(_cap(grow: -0.003, front: 0.7, back: 0.3), c.primary),
          _hp(Prim.ellipsoid(0.072, 0.062, 0.072, center: const Vec3(0, 0.335, -0.045), segments: 16),
              c.primary,
              tag: HairTags.top),
          _hp(_sideLocks(bottom: 0.08), c.primary, bias: Layer.hair + 0.004),
        ],
      ),
      GarmentDefinition(
        id: 'hair_space_buns',
        name: 'Space Buns',
        subtype: 'Bun',
        category: GarmentCategory.hair,
        slot: GarmentSlot.hair,
        variants: _hairVariants,
        build: (c) => [
          _hp(_cap(grow: 0.002, front: 0.66, back: 0.28), c.primary),
          _hp(_bangs(count: 6, length: 0.225, width: 0.105), c.primary, bias: Layer.hair + 0.006),
          for (final s in [1.0, -1.0])
            _hp(
                Prim.ellipsoid(0.062, 0.06, 0.062, center: Vec3(s * 0.11, 0.3, -0.03), segments: 14)
                    .painted((p, n) => shadeArgb(c.primary, 0.92 + 0.12 * math.sin(p.x * 160) * math.sin(p.y * 160))),
                c.primary,
                tag: HairTags.top),
        ],
      ),
      GarmentDefinition(
        id: 'hair_chin_bob',
        name: 'Chin-Length Bob',
        subtype: 'Short',
        category: GarmentCategory.hair,
        slot: GarmentSlot.hair,
        variants: _hairVariants,
        hides: {'ears'},
        build: (c) => [
          _hp(_cap(grow: 0.004), c.primary),
          _hp(
              _curtain(
                  top: 0.2,
                  bottom: 0.015,
                  rTop: 0.167,
                  rMid: 0.18,
                  rBottom: 0.178,
                  frontTop: 0.92,
                  frontBottom: 1.0,
                  shoulderY: -0.2),
              c.primary,
              bias: Layer.hair - 0.002),
          _hp(_bangs(count: 9, length: 0.215, width: 0.12), c.primary, bias: Layer.hair + 0.006),
        ],
      ),
      GarmentDefinition(
        id: 'hair_pixie',
        name: 'Pixie Cut',
        subtype: 'Short',
        category: GarmentCategory.hair,
        slot: GarmentSlot.hair,
        variants: _hairVariants,
        build: (c) => [
          _hp(_cap(grow: 0.002, front: 0.66, back: 0.33), c.primary),
          _hp(_bangs(count: 6, sweep: 0.07, length: 0.225, width: 0.11), c.primary, bias: Layer.hair + 0.006),
          _hp(_sideLocks(bottom: 0.14), c.primary, bias: Layer.hair + 0.004),
        ],
      ),
    ];
