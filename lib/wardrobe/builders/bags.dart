import 'dart:math' as math;

import '../../character/body_builder.dart';
import '../../character/body_metrics.dart';
import '../../character/part.dart';
import '../../character/skeleton.dart';
import '../../engine/math3d.dart';
import '../../engine/mesh.dart';
import '../../engine/primitives.dart';
import '../garment.dart';
import 'accessories.dart' show heartBadge, roundGlasses;
import 'kit.dart';

const _bag = Layer.accessory;

Part _b(String bone, Mesh m, int color, {double gloss = 0.15, double bias = _bag}) =>
    Part(bone, m, color: color, gloss: gloss, bias: bias);

/// Strap over one shoulder down the front and back to a point at the side.
List<Vec3> _shoulderStrap(double s, {double endX = 0.2, double endY = 0.05}) => [
      Body.torsoBack(s * 0.06, 0.25, offset: 0.03),
      Vec3(s * 0.08, 0.345, -0.02),
      Vec3(s * 0.09, 0.348, 0.03),
      Body.torsoFront(s * 0.1, 0.28, offset: 0.03),
      Vec3(s * endX, endY + 0.05, 0.03),
      Vec3(s * endX, endY, 0.0),
    ];

/// Diagonal strap from the right shoulder to the left hip, front and back.
List<Vec3> _crossStrap({double offset = 0.03}) {
  final pts = <Vec3>[];
  for (var k = 0; k <= 8; k++) {
    final t = k / 8;
    pts.add(Body.torsoBack(lerpDouble(0.11, -0.07, t), lerpDouble(0.0, 0.3, t), offset: offset));
  }
  pts.add(const Vec3(-0.085, 0.348, 0.0));
  for (var k = 0; k <= 10; k++) {
    final t = k / 10;
    pts.add(Body.torsoFront(lerpDouble(-0.07, 0.11, t), lerpDouble(0.3, 0.0, t), offset: offset));
  }
  return pts;
}

List<Part> _backpack(GarmentBuildContext c, {double scale = 1}) {
  final s = scale;
  return [
    _b(Bones.spine,
        Prim.roundedBox(0.2 * s, 0.24 * s, 0.09 * s, e: 0.3, center: Vec3(0, 0.17, -0.12 - 0.02 * s)), c.primary),
    _b(Bones.spine,
        Prim.roundedBox(0.15 * s, 0.1 * s, 0.04, e: 0.35, center: Vec3(0, 0.12, -0.17 - 0.035 * s)), c.secondary,
        bias: _bag + 0.004),
    _b(Bones.spine, Prim.torus(0.025, 0.006, segments: 12, sides: 5).transformed(
        Affine.translation(Vec3(0, 0.17 + 0.125 * s, -0.12)) * Affine.rotX(math.pi / 2) * Affine.rotZ(math.pi / 2)),
        c.accent),
    for (final side in [1.0, -1.0])
      _b(
          Bones.spine,
          Prim.tube([
            Vec3(side * 0.06, 0.28, -0.1),
            Vec3(side * 0.08, 0.35, -0.03),
            Vec3(side * 0.085, 0.35, 0.02),
            Body.torsoFront(side * 0.095, 0.27, offset: 0.028),
            Body.torsoFront(side * 0.11, 0.16, offset: 0.03),
            Vec3(side * 0.125, 0.08, -0.03),
            Vec3(side * 0.07, 0.07, -0.1),
          ], radius: 0.009, sides: 6),
          c.accent),
  ];
}

List<GarmentDefinition> buildBags() => [
      GarmentDefinition(
        id: 'bag_mini_backpack',
        name: 'Mini Backpack',
        subtype: 'Backpack',
        category: GarmentCategory.bags,
        slot: GarmentSlot.bag,
        variants: const [
          ColorVariant('Lilac', 0xFFC9B6F2, secondary: 0xFFE3D8FA, accent: 0xFF8A6AD8),
          ColorVariant('Pink', 0xFFF6B3C9, secondary: 0xFFFFDCE8, accent: 0xFFE86A92),
          ColorVariant('Mint', 0xFFAEE6CF, secondary: 0xFFDDF6EA, accent: 0xFF3FAE88),
        ],
        build: (c) => _backpack(c, scale: 0.8),
      ),
      GarmentDefinition(
        id: 'bag_school_backpack',
        name: 'Campus Backpack',
        subtype: 'Backpack',
        category: GarmentCategory.bags,
        slot: GarmentSlot.bag,
        variants: const [
          ColorVariant('Navy', 0xFF34437A, secondary: 0xFFE95C8B, accent: 0xFF2A2A3A),
          ColorVariant('Red', 0xFFD8435E, secondary: 0xFFFFD166, accent: 0xFF3A2A2A),
          ColorVariant('Canvas', 0xFFD9CBB0, secondary: 0xFF7A8358, accent: 0xFF5A4630),
        ],
        build: (c) => _backpack(c, scale: 1.15),
      ),
      GarmentDefinition(
        id: 'bag_tote',
        name: 'Canvas Tote',
        subtype: 'Shoulder Bag',
        category: GarmentCategory.bags,
        slot: GarmentSlot.bag,
        variants: const [
          ColorVariant('Natural', 0xFFEFE6D2, accent: 0xFFF48FB1),
          ColorVariant('Black', 0xFF2E2C33, accent: 0xFFFFFFFF),
          ColorVariant('Sage', 0xFFB7D3A0, accent: 0xFFFFFFFF),
        ],
        build: (c) => [
          _b(Bones.spine,
              Prim.roundedBox(0.04, 0.2, 0.2, e: 0.2, center: const Vec3(0.235, -0.01, 0.0)), c.primary,
              gloss: 0.03),
          _b(Bones.spine, heartBadge(0.06).transformed(Affine.translation(const Vec3(0.257, -0.01, 0.0)) * Affine.rotY(math.pi / 2)),
              c.accent,
              bias: _bag + 0.004),
          _b(Bones.spine, Prim.tube(_shoulderStrap(1, endX: 0.235, endY: 0.09), radius: 0.008, sides: 6), c.primary,
              gloss: 0.03),
        ],
      ),
      GarmentDefinition(
        id: 'bag_quilted',
        name: 'Quilted Shoulder Bag',
        subtype: 'Shoulder Bag',
        category: GarmentCategory.bags,
        slot: GarmentSlot.bag,
        variants: const [
          ColorVariant('Black + Gold', 0xFF26232B, accent: 0xFFE9C46A),
          ColorVariant('Blush + Gold', 0xFFF4C2CF, accent: 0xFFE9C46A),
          ColorVariant('Cream + Silver', 0xFFF2EADB, accent: 0xFFD5D9E2),
        ],
        build: (c) => [
          _b(
              Bones.spine,
              Prim.roundedBox(0.05, 0.11, 0.16, e: 0.3, center: const Vec3(0.235, 0.06, 0.0)).painted((p, _) {
                final q = math.sin((p.y + p.z) * 120) * math.sin((p.y - p.z) * 120);
                return shadeArgb(c.primary, q > 0.7 ? 0.85 : 1.0);
              }),
              0xFFFFFFFF,
              gloss: 0.5),
          _b(Bones.spine, Prim.roundedBox(0.01, 0.02, 0.03, e: 0.4, center: const Vec3(0.262, 0.07, 0.0)), c.accent,
              gloss: 0.9, bias: _bag + 0.004),
          _b(Bones.spine, Prim.tube(_shoulderStrap(1, endX: 0.235, endY: 0.11), radius: 0.004, sides: 5), c.accent,
              gloss: 0.9),
        ],
      ),
      GarmentDefinition(
        id: 'bag_camera_crossbody',
        name: 'Camera Crossbody',
        subtype: 'Crossbody Bag',
        category: GarmentCategory.bags,
        slot: GarmentSlot.bag,
        variants: const [
          ColorVariant('Tan', 0xFFB98455, accent: 0xFFE9C46A),
          ColorVariant('Pink', 0xFFF29BB6, accent: 0xFFFFFFFF),
          ColorVariant('Black', 0xFF2E2C33, accent: 0xFFD5D9E2),
        ],
        build: (c) => [
          _b(Bones.spine, Prim.tube(_crossStrap(), radius: 0.007, sides: 6), shadeArgb(c.primary, 0.8)),
          _b(Bones.spine, Prim.roundedBox(0.14, 0.1, 0.05, e: 0.3, center: Body.torsoFront(0.12, -0.03, offset: 0.05)),
              c.primary,
              gloss: 0.35),
          _b(Bones.spine, Prim.roundedBox(0.03, 0.02, 0.012, e: 0.4, center: Body.torsoFront(0.12, -0.01, offset: 0.078)),
              c.accent,
              gloss: 0.9,
              bias: _bag + 0.004),
        ],
      ),
      GarmentDefinition(
        id: 'bag_heart_crossbody',
        name: 'Heart Crossbody',
        subtype: 'Crossbody Bag',
        category: GarmentCategory.bags,
        slot: GarmentSlot.bag,
        variants: const [
          ColorVariant('Red Patent', 0xFFD8435E, accent: 0xFFE9C46A),
          ColorVariant('Pink Patent', 0xFFF48FB1, accent: 0xFFFFFFFF),
          ColorVariant('Silver', 0xFFD5D9E2, accent: 0xFFF48FB1),
        ],
        build: (c) => [
          _b(Bones.spine, Prim.tube(_crossStrap(), radius: 0.004, sides: 5), c.accent, gloss: 0.9),
          _b(
              Bones.spine,
              Mesh.merge([
                Prim.sphere(0.04, center: const Vec3(-0.03, 0.02, 0), segments: 12),
                Prim.sphere(0.04, center: const Vec3(0.03, 0.02, 0), segments: 12),
                Prim.roundedBox(0.075, 0.075, 0.06, e: 0.5).transformed(Affine.translation(const Vec3(0, -0.015, 0)) * Affine.rotZ(math.pi / 4)),
              ]).transformed(Affine.translation(Body.torsoFront(0.12, -0.02, offset: 0.05)) * Affine.scale(const Vec3(1, 1, 0.55))),
              c.primary,
              gloss: 0.9),
        ],
      ),
      GarmentDefinition(
        id: 'bag_mini_handbag',
        name: 'Mini Top-Handle Bag',
        subtype: 'Handbag',
        category: GarmentCategory.bags,
        slot: GarmentSlot.bag,
        variants: const [
          ColorVariant('Lilac', 0xFFC9B6F2, accent: 0xFFE9C46A),
          ColorVariant('Butter', 0xFFFFE7A3, accent: 0xFFE9C46A),
          ColorVariant('Cherry', 0xFFC7364F, accent: 0xFFE9C46A),
        ],
        build: (c) => [
          _b(Bones.handL, Prim.roundedBox(0.04, 0.09, 0.13, e: 0.3, center: const Vec3(0.005, -0.15, 0.0)), c.primary,
              gloss: 0.5),
          _b(
              Bones.handL,
              Prim.torus(0.042, 0.006, segments: 14, sides: 5, a0: -1.7, a1: 1.7)
                  .transformed(Affine.translation(const Vec3(0.005, -0.105, 0.0)) * Affine.rotZ(math.pi / 2) * Affine.rotX(math.pi / 2) * Affine.rotY(math.pi)),
              c.primary,
              gloss: 0.5),
          _b(Bones.handL, Prim.roundedBox(0.008, 0.015, 0.025, e: 0.4, center: const Vec3(0.027, -0.13, 0.0)), c.accent,
              gloss: 0.9, bias: _bag + 0.004),
        ],
      ),
      GarmentDefinition(
        id: 'bag_bucket',
        name: 'Drawstring Bucket Bag',
        subtype: 'Handbag',
        category: GarmentCategory.bags,
        slot: GarmentSlot.bag,
        variants: const [
          ColorVariant('Caramel', 0xFFC08A5A, accent: 0xFFF2E6D0),
          ColorVariant('Sage', 0xFF9DBFA6, accent: 0xFFFFFFFF),
          ColorVariant('Blush', 0xFFF4C2CF, accent: 0xFFFFFFFF),
        ],
        build: (c) => [
          _b(
              Bones.handL,
              Prim.lathe(const [P2(0.0, -0.21), P2(0.05, -0.205), P2(0.058, -0.17), P2(0.055, -0.12), P2(0.045, -0.11)],
                      segments: 18)
                  .doubleSided(),
              c.primary,
              gloss: 0.2),
          _b(Bones.handL, Prim.tube([const Vec3(0.0, -0.11, 0.04), const Vec3(0.0, -0.04, 0.0), const Vec3(0.0, -0.11, -0.04)], radius: 0.005, sides: 5),
              c.accent),
        ],
      ),
    ];

List<GarmentDefinition> buildExtras() => [
      GarmentDefinition(
        id: 'extra_round_glasses',
        name: 'Round Glasses',
        subtype: 'Glasses',
        category: GarmentCategory.extras,
        slot: GarmentSlot.eyewear,
        variants: const [
          ColorVariant('Gold', 0xFFE9C46A, secondary: 0xFFE9C46A),
          ColorVariant('Tortoise', 0xFF9C6A3A, secondary: 0xFF6A4426),
          ColorVariant('Pink', 0xFFF48FB1, secondary: 0xFFF48FB1),
        ],
        build: roundGlasses,
      ),
      GarmentDefinition(
        id: 'extra_knit_scarf',
        name: 'Chunky Knit Scarf',
        subtype: 'Scarf',
        category: GarmentCategory.extras,
        slot: GarmentSlot.scarf,
        variants: const [
          ColorVariant('Cream', 0xFFF1E8D8),
          ColorVariant('Red Plaid', 0xFFC7364F, secondary: 0xFF2E2E4A),
          ColorVariant('Lavender', 0xFFC9B6F2),
        ],
        hides: {BodyTags.neck},
        build: (c) {
          final paint = c.variant.name.contains('Plaid')
              ? Kit.plaid(c.primary, c.secondary, 0xFFFFFFFF, freq: 80)
              : Kit.knit(c.primary);
          return [
            Part(
                Bones.neck,
                Prim.torus(0.068, 0.03, segments: 22, sides: 8, sz: 0.9)
                    .transformed(Affine.translation(const Vec3(0, 0.0, 0)))
                    .painted(paint),
                bias: _bag,
                gloss: 0.02),
            Part(
                Bones.spine,
                Prim.tube([
                  Body.torsoFront(0.05, 0.34, offset: 0.04),
                  Body.torsoFront(0.06, 0.25, offset: 0.035),
                  Body.torsoFront(0.065, 0.12, offset: 0.035),
                ], radii: const [0.03, 0.028, 0.026], sides: 8)
                    .transformed(Affine.scale(const Vec3(1, 1, 1)))
                    .painted(paint),
                bias: _bag + 0.002,
                gloss: 0.02),
          ];
        },
      ),
      GarmentDefinition(
        id: 'extra_silk_scarf',
        name: 'Silk Neck Scarf',
        subtype: 'Scarf',
        category: GarmentCategory.extras,
        slot: GarmentSlot.scarf,
        variants: const [
          ColorVariant('Polka Red', 0xFFD8435E, secondary: 0xFFFFFFFF),
          ColorVariant('Sky Dot', 0xFF7FB6F0, secondary: 0xFFFFFFFF),
          ColorVariant('Lemon', 0xFFFFE07A, secondary: 0xFFFFFFFF),
        ],
        build: (c) {
          final p = Kit.dots(c.primary, c.secondary, freq: 200);
          return [
            Part(Bones.neck, Prim.torus(0.05, 0.012, segments: 20, sides: 6, sz: 0.9).painted(p),
                bias: _bag, gloss: 0.4),
            Part(
                Bones.neck,
                Mesh.merge([
                  Prim.sphere(0.017, center: const Vec3(0.03, -0.01, 0.045)),
                  Prim.ellipsoid(0.03, 0.016, 0.008, center: const Vec3(0.055, -0.03, 0.05)).transformed(Affine.identity),
                  Prim.ellipsoid(0.014, 0.03, 0.008, center: const Vec3(0.035, -0.045, 0.05)),
                ]).painted(p),
                bias: _bag + 0.004,
                gloss: 0.4),
          ];
        },
      ),
      GarmentDefinition(
        id: 'extra_leather_belt',
        name: 'Classic Belt',
        subtype: 'Belt',
        category: GarmentCategory.extras,
        slot: GarmentSlot.belt,
        variants: const [
          ColorVariant('Brown + Gold', 0xFF7A4A2E, accent: 0xFFE9C46A),
          ColorVariant('Black + Silver', 0xFF26232B, accent: 0xFFD5D9E2),
          ColorVariant('White + Gold', 0xFFF7F4EE, accent: 0xFFE9C46A),
        ],
        build: (c) => _belt(c, chain: false),
      ),
      GarmentDefinition(
        id: 'extra_heart_belt',
        name: 'Heart Buckle Belt',
        subtype: 'Belt',
        category: GarmentCategory.extras,
        slot: GarmentSlot.belt,
        variants: const [
          ColorVariant('Pink', 0xFFF48FB1, accent: 0xFFE9C46A),
          ColorVariant('Black', 0xFF26232B, accent: 0xFFF48FB1),
        ],
        build: (c) => _belt(c, chain: true),
      ),
      GarmentDefinition(
        id: 'extra_crew_socks',
        name: 'Sporty Crew Socks',
        subtype: 'Socks',
        category: GarmentCategory.extras,
        slot: GarmentSlot.socks,
        variants: const [
          ColorVariant('White + Pink', 0xFFFAFAFA, secondary: 0xFFF48FB1),
          ColorVariant('White + Blue', 0xFFFAFAFA, secondary: 0xFF5B8ED6),
          ColorVariant('Lilac', 0xFFD8C8F2, secondary: 0xFFFFFFFF),
        ],
        build: (c) => _socks(c, top: -0.24),
      ),
      GarmentDefinition(
        id: 'extra_knee_socks',
        name: 'Knee-High Socks',
        subtype: 'Socks',
        category: GarmentCategory.extras,
        slot: GarmentSlot.socks,
        variants: const [
          ColorVariant('Navy', 0xFF2F3A66, secondary: 0xFFFFFFFF),
          ColorVariant('White', 0xFFFAFAFA, secondary: 0xFFF6B3C9),
          ColorVariant('Argyle Pink', 0xFFF6B3C9, secondary: 0xFFFFFFFF),
        ],
        build: (c) => _socks(c, top: -0.03),
      ),
    ];

List<Part> _belt(GarmentBuildContext c, {required bool chain}) {
  const y = 0.0;
  final r = Body.profileRadius(Body.torsoProfile, y) + 0.024;
  return [
    Part(Bones.spine,
        Prim.torus(r, 0.012, sz: Body.torsoDepth * 1.02, segments: 30, sides: 4)
            .transformed(Affine.scale(const Vec3(1, 1.4, 1))),
        color: c.primary,
        bias: Layer.outer - 0.002,
        gloss: 0.4),
    Part(
        Bones.spine,
        (chain ? heartBadge(0.05) : Prim.roundedBox(0.042, 0.032, 0.01, e: 0.3))
            .transformed(Affine.translation(Body.torsoFront(0, y, offset: 0.034))),
        color: c.accent,
        bias: Layer.outer + 0.004,
        gloss: 0.9,
        decal: true),
  ];
}

List<Part> _socks(GarmentBuildContext c, {required double top}) {
  final argyle = c.variant.name.startsWith('Argyle');
  int paint(Vec3 p, Vec3 n) {
    if (argyle) {
      return (math.sin(p.y * 90 + math.atan2(p.x, p.z) * 4).abs() < 0.3) ? c.secondary : c.primary;
    }
    return (p.y > top - 0.04 && p.y < top - 0.025) || (p.y > top - 0.06 && p.y < top - 0.05)
        ? c.secondary
        : c.primary;
  }

  return [
    for (final l in [true, false]) ...[
      Part(
          Bones.side('shin', l),
          Prim.lathe([
            P2(Body.shinR1 + 0.004, -Body.shinLen - 0.01),
            P2(lerpDouble(Body.shinR0, Body.shinR1, (-top) / Body.shinLen) + 0.005, top),
          ], segments: 16)
              .doubleSided()
              .painted(paint),
          bias: Layer.socks),
      Part(
          Bones.side('foot', l),
          Prim.ellipsoid(0.044, 0.036, 0.086, center: const Vec3(0, -0.03, 0.035), segments: 12).solid(c.primary),
          bias: Layer.socks),
    ],
  ];
}
