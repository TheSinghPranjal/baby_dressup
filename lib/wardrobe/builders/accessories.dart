import 'dart:math' as math;

import '../../character/body_metrics.dart';
import '../../character/part.dart';
import '../../character/skeleton.dart';
import '../../engine/math3d.dart';
import '../../engine/mesh.dart';
import '../../engine/primitives.dart';
import '../garment.dart';
import 'hair.dart';
import 'kit.dart';
import 'outfits.dart' show bow;

const _metals = [
  ColorVariant('Gold', 0xFFE9C46A, accent: 0xFFFFFFFF),
  ColorVariant('Silver', 0xFFD5D9E2, accent: 0xFFFFFFFF),
  ColorVariant('Rose Gold', 0xFFEFB4A2, accent: 0xFFFFFFFF),
];

const _acc = Layer.accessory;

Part _p(String bone, Mesh m, int color, {double gloss = 0.2, double bias = _acc, String? tag}) =>
    Part(bone, m, color: color, gloss: gloss, bias: bias, tag: tag);

/// Ring in the XY plane (facing +Z) built from a Y-axis torus.
Mesh _ringXY(double r, double thick, {double a0 = 0, double a1 = Kit.tau, double sx = 1}) =>
    Prim.torus(r, thick, a0: a0, a1: a1, segments: 22, sides: 6, sx: sx)
        .transformed(Affine.rotX(math.pi / 2));

Mesh _flower(double size, {Vec3 at = Vec3.zero}) => Mesh.merge([
      for (var k = 0; k < 5; k++)
        Prim.ellipsoid(size * 0.5, size * 0.5, size * 0.25,
            center: Vec3(math.sin(k * Kit.tau / 5) * size * 0.6, math.cos(k * Kit.tau / 5) * size * 0.6, 0),
            segments: 8,
            rings: 6),
    ]).transformed(Affine.translation(at));

Mesh _star(double size) => Mesh.merge([
      for (var k = 0; k < 5; k++)
        Prim.ellipsoid(size * 0.22, size * 0.62, size * 0.15,
                center: Vec3(0, size * 0.45, 0), segments: 6, rings: 5)
            .transformed(Affine.rotZ(k * Kit.tau / 5)),
    ]);

/// Path around the base of the neck, dipping to [drop] at the front.
List<Vec3> _necklacePath({double drop = 0.07, double width = 0.075, double offset = 0.016}) {
  final pts = <Vec3>[];
  const n = 24;
  for (var k = 0; k <= n; k++) {
    final a = Kit.tau * k / n;
    final x = width * math.sin(a);
    final front = math.cos(a);
    if (front >= 0) {
      final y = 0.345 - drop * front * front;
      pts.add(Body.torsoFront(x, y, offset: offset + 0.01 * (1 - front)));
    } else {
      pts.add(Vec3(x, 0.352, -0.045 + 0.02 * front));
    }
  }
  return pts;
}

List<GarmentDefinition> buildAccessories() => [
      // --- Headwear --------------------------------------------------------
      GarmentDefinition(
        id: 'head_headband',
        name: 'Padded Headband',
        subtype: 'Headband',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.headwear,
        variants: const [
          ColorVariant('Pink', 0xFFF48FB1),
          ColorVariant('Pearl', 0xFFF6F1EA),
          ColorVariant('Velvet Navy', 0xFF2F3A66),
          ColorVariant('Leopard', 0xFFD9A35E, secondary: 0xFF4A3424),
        ],
        build: (c) => [
          _p(
              Bones.head,
              _ringXY(0.172, 0.016, a0: math.pi - 1.75, a1: math.pi + 1.75, sx: 1.0)
                  .transformed(Affine.translation(const Vec3(0, 0.17, 0.035)) * Affine.rotX(-0.35))
                  .painted((p, _) => c.variant.name == 'Leopard' &&
                          math.sin(p.x * 220) * math.sin(p.z * 220 + p.y * 90) > 0.6
                      ? c.secondary
                      : c.primary),
              0xFFFFFFFF,
              gloss: 0.3),
        ],
      ),
      GarmentDefinition(
        id: 'head_hair_clips',
        name: 'Pastel Hair Clips',
        subtype: 'Hair Clips',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.headwear,
        variants: const [
          ColorVariant('Candy', 0xFFF7A6C6, secondary: 0xFFA8D4F5, accent: 0xFFFFE680),
          ColorVariant('Pearl', 0xFFFFFFFF, secondary: 0xFFF3EDE2, accent: 0xFFFFFFFF),
          ColorVariant('Gold', 0xFFE9C46A, secondary: 0xFFE9C46A, accent: 0xFFE9C46A),
        ],
        build: (c) => [
          for (var k = 0; k < 3; k++)
            _p(
                Bones.head,
                Prim.roundedBox(0.045, 0.011, 0.012, e: 0.4).transformed(
                    Affine.translation(Body.faceSurface(-0.098 - k * 0.012, 0.25 - k * 0.028, offset: 0.03)) *
                        Affine.rotZ(-0.5 - k * 0.1) *
                        Affine.rotY(-0.5)),
                [c.primary, c.secondary, c.accent][k],
                gloss: 0.6),
        ],
      ),
      GarmentDefinition(
        id: 'head_bow_clip',
        name: 'Big Satin Bow',
        subtype: 'Hair Clips',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.headwear,
        variants: const [
          ColorVariant('Pink', 0xFFF48FB1),
          ColorVariant('Red', 0xFFD8435E),
          ColorVariant('Black', 0xFF26232B),
          ColorVariant('Baby Blue', 0xFFA8D4F5),
        ],
        build: (c) => [
          bow(c.primary, const Vec3(0.11, 0.285, -0.07), 0.065, bone: Bones.head, bias: _acc),
        ],
      ),
      GarmentDefinition(
        id: 'head_flower_crown',
        name: 'Flower Crown',
        subtype: 'Headband',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.headwear,
        variants: const [
          ColorVariant('Spring', 0xFFF7A6C6, secondary: 0xFFFFF0A0, accent: 0xFFB8E0A0),
          ColorVariant('Lavender Field', 0xFFC4A8F0, secondary: 0xFFFFFFFF, accent: 0xFFA0CFA0),
        ],
        build: (c) => [
          for (var k = 0; k < 9; k++)
            () {
              final a = -2.2 + 4.4 * k / 8;
              final pos = Vec3(0.168 * math.sin(a), 0.255 + 0.03 * math.cos(a), 0.158 * math.cos(a) - 0.02);
              return _p(
                  Bones.head,
                  _flower(0.024).transformed(Affine.translation(pos) * Affine.lookDir(Vec3(math.sin(a), 0.6, math.cos(a)))),
                  k.isEven ? c.primary : c.secondary,
                  gloss: 0.15);
            }(),
          _p(
              Bones.head,
              Prim.torus(0.165, 0.006, segments: 28, sides: 5, a0: -2.3, a1: 2.3, sz: 0.94)
                  .transformed(Affine.translation(const Vec3(0, 0.255, -0.012)) * Affine.rotX(-0.15)),
              c.accent,
              bias: _acc - 0.002),
        ],
      ),
      GarmentDefinition(
        id: 'head_beanie',
        name: 'Pom-Pom Beanie',
        subtype: 'Hat',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.headwear,
        variants: const [
          ColorVariant('Cream', 0xFFF1E8D8, accent: 0xFFF7A6C6),
          ColorVariant('Mustard', 0xFFE5B547, accent: 0xFFFFFFFF),
          ColorVariant('Berry', 0xFFB4486B, accent: 0xFFF6D6E0),
          ColorVariant('Sky', 0xFFA8D4F5, accent: 0xFFFFFFFF),
        ],
        hides: {HairTags.top},
        build: (c) => [
          _p(
              Bones.head,
              Prim.ellipsoid(0.178, 0.165, 0.172, center: const Vec3(0, 0.19, -0.008), p0: math.pi * 0.42, segments: 26)
                  .doubleSided()
                  .painted(Kit.knit(c.primary)),
              0xFFFFFFFF,
              gloss: 0.02),
          _p(
              Bones.head,
              Prim.torus(0.174, 0.02, sz: 0.97, segments: 28, sides: 6)
                  .transformed(Affine.translation(const Vec3(0, 0.235, -0.008)))
                  .painted(Kit.knit(shadeArgb(c.primary, 0.93))),
              0xFFFFFFFF,
              bias: _acc + 0.002,
              gloss: 0.02),
          _p(Bones.head, Prim.sphere(0.05, center: const Vec3(0, 0.36, -0.01), segments: 12), c.accent,
              gloss: 0.0),
        ],
      ),
      GarmentDefinition(
        id: 'head_sun_hat',
        name: 'Straw Sun Hat',
        subtype: 'Hat',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.headwear,
        variants: const [
          ColorVariant('Straw', 0xFFE8D29A, accent: 0xFFF48FB1),
          ColorVariant('Ivory', 0xFFF6F0E2, accent: 0xFF2F3A66),
          ColorVariant('Lilac', 0xFFD8C8F2, accent: 0xFFFFFFFF),
        ],
        hides: {HairTags.top},
        build: (c) {
          int weave(Vec3 p, Vec3 n) =>
              shadeArgb(c.primary, math.sin(p.x * 260) * math.sin(p.z * 260) > 0 ? 1.0 : 0.92);
          final hat = Mesh.merge([
            Prim.ellipsoid(0.172, 0.11, 0.168, center: const Vec3(0, 0.255, 0), p0: math.pi * 0.5, segments: 26)
                .doubleSided(),
            Prim.lathe(const [P2(0.34, 0.222), P2(0.27, 0.242), P2(0.2, 0.254), P2(0.168, 0.258)], segments: 32)
                .doubleSided(),
          ]).painted(weave);
          return [
            _p(Bones.head, hat.transformed(Affine.translation(const Vec3(0, 0.0, -0.01)) * Affine.rotX(-0.12)), 0xFFFFFFFF,
                gloss: 0.02),
            _p(
                Bones.head,
                Prim.torus(0.172, 0.014, segments: 28, sides: 6)
                    .transformed(Affine.translation(const Vec3(0, 0.272, -0.01)) * Affine.rotX(-0.12)),
                c.accent,
                bias: _acc + 0.003,
                gloss: 0.4),
          ];
        },
      ),
      GarmentDefinition(
        id: 'head_cap',
        name: 'Baseball Cap',
        subtype: 'Hat',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.headwear,
        variants: const [
          ColorVariant('Pink', 0xFFF6B3C9, accent: 0xFFFFFFFF),
          ColorVariant('Navy', 0xFF2F3A66, accent: 0xFFFFFFFF),
          ColorVariant('White', 0xFFF7F7F7, accent: 0xFF5B8ED6),
        ],
        hides: {HairTags.top},
        build: (c) => [
          _p(
              Bones.head,
              Prim.ellipsoid(0.174, 0.14, 0.172, center: const Vec3(0, 0.215, -0.006), p0: math.pi * 0.5, segments: 26)
                  .doubleSided(),
              c.primary,
              gloss: 0.08),
          _p(
              Bones.head,
              Prim.ellipsoid(0.12, 0.012, 0.11, center: const Vec3(0, 0.0, 0.0), segments: 18)
                  .transformed(Affine.translation(const Vec3(0, 0.235, 0.2)) * Affine.rotX(0.12)),
              c.primary,
              bias: _acc + 0.004,
              gloss: 0.08),
          _p(Bones.head, Prim.sphere(0.012, center: const Vec3(0, 0.356, -0.006), segments: 8), c.accent),
          _p(Bones.head, _heartBadge(0.04).transformed(Affine.translation(Body.faceSurface(0, 0.29, offset: 0.034)) * Affine.rotX(-0.55)),
              c.accent,
              bias: _acc + 0.01),
        ],
      ),
      GarmentDefinition(
        id: 'head_beret',
        name: 'Parisian Beret',
        subtype: 'Hat',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.headwear,
        variants: const [
          ColorVariant('Red', 0xFFC7364F),
          ColorVariant('Black', 0xFF26232B),
          ColorVariant('Camel', 0xFFC9A27A),
          ColorVariant('Lavender', 0xFFC4A8F0),
        ],
        hides: {HairTags.top},
        build: (c) => [
          _p(
              Bones.head,
              Mesh.merge([
                Prim.ellipsoid(0.2, 0.07, 0.19, center: const Vec3(0, 0.0, 0), segments: 24),
                Prim.capsule(0.02, 0.006, 0.006, segments: 6).transformed(Affine.translation(const Vec3(0, 0.085, 0))),
              ]).transformed(Affine.translation(const Vec3(0.03, 0.29, -0.02)) * Affine.rotZ(-0.28) * Affine.rotX(-0.15)),
              c.primary,
              gloss: 0.03),
        ],
      ),
      // --- Earrings ----------------------------------------------------------
      GarmentDefinition(
        id: 'ear_pearl_studs',
        name: 'Pearl Studs',
        subtype: 'Earrings',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.earrings,
        variants: const [
          ColorVariant('Pearl', 0xFFFBF6EE),
          ColorVariant('Pink Pearl', 0xFFF9D9E2),
        ],
        build: (c) => [
          _p(
              Bones.head,
              Mesh.merge([
                for (final s in [1.0, -1.0])
                  Prim.sphere(0.011, center: Vec3(s * 0.158, 0.108, -0.004), segments: 10)
              ]),
              c.primary,
              gloss: 0.9),
        ],
      ),
      GarmentDefinition(
        id: 'ear_gold_hoops',
        name: 'Hoop Earrings',
        subtype: 'Earrings',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.earrings,
        variants: _metals,
        build: (c) => [
          _p(
              Bones.head,
              Mesh.merge([
                for (final s in [1.0, -1.0])
                  _ringXY(0.024, 0.0035).transformed(
                      Affine.translation(Vec3(s * 0.158, 0.088, -0.004)) * Affine.rotY(math.pi / 2))
              ]),
              c.primary,
              gloss: 0.9),
        ],
      ),
      GarmentDefinition(
        id: 'ear_star_drops',
        name: 'Star Drop Earrings',
        subtype: 'Earrings',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.earrings,
        variants: _metals,
        build: (c) => [
          _p(
              Bones.head,
              Mesh.merge([
                for (final s in [1.0, -1.0]) ...[
                  Prim.rod(Vec3(s * 0.158, 0.108, -0.004), Vec3(s * 0.16, 0.08, -0.004), 0.002, sides: 4),
                  _star(0.03).transformed(Affine.translation(Vec3(s * 0.161, 0.068, -0.004)) * Affine.rotY(s * math.pi / 2)),
                ]
              ]),
              c.primary,
              gloss: 0.9),
        ],
      ),
      // --- Necklaces ---------------------------------------------------------
      GarmentDefinition(
        id: 'neck_heart_pendant',
        name: 'Heart Pendant',
        subtype: 'Necklace',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.necklace,
        variants: const [
          ColorVariant('Gold + Pink', 0xFFE9C46A, accent: 0xFFF48FB1),
          ColorVariant('Silver + Blue', 0xFFD5D9E2, accent: 0xFF7FB6F0),
          ColorVariant('Gold + Red', 0xFFE9C46A, accent: 0xFFD8435E),
        ],
        build: (c) => [
          _p(Bones.spine, Prim.tube(_necklacePath(drop: 0.08), radius: 0.0025, sides: 4), c.primary, gloss: 0.9),
          _p(
              Bones.spine,
              _heartBadge(0.034).transformed(Affine.translation(Body.torsoFront(0, 0.255, offset: 0.024))),
              c.accent,
              gloss: 0.8,
              bias: _acc + 0.004),
        ],
      ),
      GarmentDefinition(
        id: 'neck_pearls',
        name: 'Pearl Strand',
        subtype: 'Necklace',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.necklace,
        variants: const [
          ColorVariant('Pearl', 0xFFFBF6EE),
          ColorVariant('Pastel Beads', 0xFFF7A6C6, secondary: 0xFFA8D4F5, accent: 0xFFFFE680),
        ],
        build: (c) {
          final path = _necklacePath(drop: 0.06);
          final beads = <Mesh>[];
          for (var k = 0; k < path.length - 1; k++) {
            for (var j = 0; j < 3; j++) {
              final p = path[k].lerp(path[k + 1], j / 3);
              final col = c.variant.name == 'Pearl' ? c.primary : [c.primary, c.secondary, c.accent][(k * 3 + j) % 3];
              beads.add(Prim.sphere(0.0065, center: p, segments: 6).solid(col));
            }
          }
          return [_p(Bones.spine, Mesh.merge(beads), 0xFFFFFFFF, gloss: 0.9)];
        },
      ),
      GarmentDefinition(
        id: 'neck_layered_chain',
        name: 'Layered Star Chain',
        subtype: 'Necklace',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.necklace,
        variants: _metals,
        build: (c) => [
          _p(
              Bones.spine,
              Mesh.merge([
                Prim.tube(_necklacePath(drop: 0.045, width: 0.07), radius: 0.0022, sides: 4),
                Prim.tube(_necklacePath(drop: 0.1, width: 0.08, offset: 0.018), radius: 0.0022, sides: 4),
                _star(0.03).transformed(Affine.translation(Body.torsoFront(0, 0.243, offset: 0.024))),
              ]),
              c.primary,
              gloss: 0.9),
        ],
      ),
      // --- Wrist ---------------------------------------------------------------
      GarmentDefinition(
        id: 'wrist_charm_bracelet',
        name: 'Charm Bracelet',
        subtype: 'Bracelet',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.wrist,
        variants: const [
          ColorVariant('Gold', 0xFFE9C46A, secondary: 0xFFF48FB1, accent: 0xFF7FB6F0),
          ColorVariant('Silver', 0xFFD5D9E2, secondary: 0xFFC4A8F0, accent: 0xFF9FE3D8),
        ],
        build: (c) => [
          for (final b in [Bones.forearmL, Bones.forearmR]) ...[
            _p(b, Prim.torus(0.028, 0.003, segments: 16, sides: 5).transformed(Affine.translation(const Vec3(0, -0.2, 0))),
                c.primary,
                gloss: 0.9),
            _p(
                b,
                Mesh.merge([
                  Prim.sphere(0.006, center: const Vec3(0.02, -0.21, 0.02), segments: 6).solid(c.secondary),
                  _heartBadge(0.014).transformed(Affine.translation(const Vec3(-0.02, -0.21, 0.02))).solid(c.accent),
                ]),
                0xFFFFFFFF,
                gloss: 0.6),
          ],
        ],
      ),
      GarmentDefinition(
        id: 'wrist_beaded',
        name: 'Rainbow Bead Bracelets',
        subtype: 'Bracelet',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.wrist,
        variants: const [
          ColorVariant('Rainbow', 0xFFF48FB1),
          ColorVariant('Ocean', 0xFF7FB6F0),
        ],
        build: (c) {
          final cols = c.variant.name == 'Rainbow'
              ? [0xFFF48FB1, 0xFFFFD166, 0xFF9FE3A0, 0xFF7FB6F0, 0xFFC4A8F0]
              : [0xFF7FB6F0, 0xFFFFFFFF, 0xFF9FE3D8, 0xFF5B8ED6];
          Mesh ring(double y) => Mesh.merge([
                for (var k = 0; k < 14; k++)
                  Prim.sphere(0.0055,
                          center: Vec3(0.029 * math.sin(k * Kit.tau / 14), y, 0.029 * math.cos(k * Kit.tau / 14)),
                          segments: 6)
                      .solid(cols[k % cols.length])
              ]);
          return [
            for (final b in [Bones.forearmL, Bones.forearmR])
              _p(b, Mesh.merge([ring(-0.2), ring(-0.185)]), 0xFFFFFFFF, gloss: 0.5),
          ];
        },
      ),
      GarmentDefinition(
        id: 'wrist_smart_watch',
        name: 'Smart Watch',
        subtype: 'Watch',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.wrist,
        variants: const [
          ColorVariant('Blush Band', 0xFFF6B3C9, accent: 0xFF2B2830),
          ColorVariant('Mint Band', 0xFFAEE6CF, accent: 0xFF2B2830),
          ColorVariant('Black Band', 0xFF2B2830, accent: 0xFF3A3640),
        ],
        build: (c) => [
          _p(Bones.forearmL,
              Prim.torus(0.028, 0.006, segments: 16, sides: 6).transformed(Affine.translation(const Vec3(0, -0.195, 0))),
              c.primary,
              gloss: 0.2),
          _p(
              Bones.forearmL,
              Prim.roundedBox(0.012, 0.03, 0.026, e: 0.35).transformed(Affine.translation(const Vec3(0.03, -0.195, 0.0))),
              c.accent,
              gloss: 0.9,
              bias: _acc + 0.003),
          _p(
              Bones.forearmL,
              Prim.roundedBox(0.004, 0.022, 0.018, e: 0.4).transformed(Affine.translation(const Vec3(0.036, -0.195, 0.0))),
              0xFF7FB6F0,
              gloss: 1,
              bias: _acc + 0.006),
        ],
      ),
      GarmentDefinition(
        id: 'wrist_classic_watch',
        name: 'Classic Watch',
        subtype: 'Watch',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.wrist,
        variants: const [
          ColorVariant('Gold + Tan', 0xFFC89A6A, accent: 0xFFE9C46A),
          ColorVariant('Silver + Black', 0xFF2B2830, accent: 0xFFD5D9E2),
        ],
        build: (c) => [
          _p(Bones.forearmL,
              Prim.torus(0.028, 0.005, segments: 16, sides: 6).transformed(Affine.translation(const Vec3(0, -0.195, 0))),
              c.primary,
              gloss: 0.2),
          _p(
              Bones.forearmL,
              Prim.lathe(const [P2(0.0, -0.004), P2(0.016, -0.004), P2(0.017, 0.004), P2(0.0, 0.006)], segments: 16)
                  .transformed(Affine.translation(const Vec3(0.031, -0.195, 0)) * Affine.rotZ(-math.pi / 2)),
              c.accent,
              gloss: 0.9,
              bias: _acc + 0.003),
        ],
      ),
      // --- Sunglasses ----------------------------------------------------------
      GarmentDefinition(
        id: 'eye_heart_sunnies',
        name: 'Heart Sunglasses',
        subtype: 'Sunglasses',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.eyewear,
        variants: const [
          ColorVariant('Pink Tint', 0xFFF06292, secondary: 0xFFFFFFFF),
          ColorVariant('Red Tint', 0xFFD8435E, secondary: 0xFF2B2830),
          ColorVariant('Lilac Tint', 0xFFB39DEB, secondary: 0xFFFFFFFF),
        ],
        build: (c) => _glasses(c, heart: true),
      ),
      GarmentDefinition(
        id: 'eye_cat_eye',
        name: 'Cat-Eye Sunglasses',
        subtype: 'Sunglasses',
        category: GarmentCategory.accessories,
        slot: GarmentSlot.eyewear,
        variants: const [
          ColorVariant('Tortoise', 0xFF3A2A26, secondary: 0xFF9C6A3A),
          ColorVariant('Black', 0xFF26232B, secondary: 0xFF26232B),
          ColorVariant('White', 0xFF4A4552, secondary: 0xFFF7F7F7),
        ],
        build: (c) => _glasses(c, catEye: true),
      ),
    ];

/// Small heart shape facing +Z.
Mesh _heartBadge(double size) => Mesh.merge([
      Prim.disc(size * 0.3, size * 0.3, dome: 0.35, center: Vec3(-size * 0.22, size * 0.12, 0), segments: 10),
      Prim.disc(size * 0.3, size * 0.3, dome: 0.35, center: Vec3(size * 0.22, size * 0.12, 0), segments: 10),
      Prim.disc(size * 0.34, size * 0.34, dome: 0.35, segments: 4)
          .transformed(Affine.translation(Vec3(0, -size * 0.12, 0)) * Affine.rotZ(math.pi / 4)),
    ]);

Mesh heartBadge(double size) => _heartBadge(size);

List<Part> _glasses(GarmentBuildContext c, {bool heart = false, bool catEye = false, bool clear = false}) {
  const eyeY = 0.128;
  final lensMeshes = <Mesh>[];
  final frameMeshes = <Mesh>[];
  for (final s in [1.0, -1.0]) {
    final at = Body.faceSurface(s * 0.06, eyeY, offset: 0.034);
    final face = Affine.translation(at) * Affine.lookDir(Vec3(s * 0.25, 0, 1));
    if (heart) {
      lensMeshes.add(_heartBadge(0.08).transformed(face));
    } else {
      lensMeshes.add(Prim.disc(0.046, 0.036, dome: 0.15, segments: 18).transformed(face * Affine.rotZ(s * (catEye ? 0.18 : 0))));
      frameMeshes.add(_ringXY(0.046, 0.0045, sx: 1).transformed(face * Affine.scale(const Vec3(1, 0.8, 1)) * Affine.rotZ(s * (catEye ? 0.18 : 0))));
      if (catEye) {
        frameMeshes.add(Prim.ellipsoid(0.012, 0.007, 0.005).transformed(face * Affine.translation(Vec3(s * 0.045, 0.024, 0))));
      }
    }
    // Temple arm back to the ear.
    frameMeshes.add(Prim.rod(Body.faceSurface(s * 0.105, eyeY + 0.01, offset: 0.025), Vec3(s * 0.152, 0.15, -0.02), 0.003, sides: 4));
  }
  frameMeshes.add(Prim.rod(Body.faceSurface(-0.016, eyeY + 0.008, offset: 0.036), Body.faceSurface(0.016, eyeY + 0.008, offset: 0.036), 0.003, sides: 4));
  return [
    if (!clear)
      Part(Bones.head, Mesh.merge(lensMeshes), color: c.primary, gloss: 1, bias: 0.04, decal: true, tag: 'glasses'),
    Part(Bones.head, Mesh.merge(frameMeshes), color: c.secondary, gloss: 0.6, bias: 0.045, tag: 'glasses'),
  ];
}

List<Part> roundGlasses(GarmentBuildContext c) => _glasses(c, clear: true);
