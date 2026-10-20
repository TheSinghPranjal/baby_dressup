import 'dart:math' as math;

import '../../character/body_builder.dart';
import '../../character/body_metrics.dart';
import '../../character/part.dart';
import '../../character/skeleton.dart';
import '../../engine/math3d.dart';
import '../../engine/mesh.dart';
import '../../engine/primitives.dart';
import '../garment.dart';
import 'outfits.dart' show bow;

const _footCenter = Vec3(0, -0.03, 0.035);

/// Builds a pair: [one] receives `left` and returns the parts for that foot.
/// Foot-bone parts are scaled up slightly for the doll look.
List<Part> _pair(List<Part> Function(bool left, String foot, String shin) one) => [
      for (final l in [true, false])
        for (final p in one(l, Bones.side('foot', l), Bones.side('shin', l)))
          p.bone.startsWith('foot')
              ? Part(p.bone, p.mesh.transformed(_footScale),
                  color: p.color, gloss: p.gloss, bias: p.bias, tag: p.tag, decal: p.decal)
              : p
    ];

final _footScale = Affine.translation(const Vec3(0, 0, 0.01)) *
    Affine.scale(const Vec3(1.1, 1.08, 1.1));

Mesh _upper({double grow = 0.008, double top = math.pi, double lift = 0}) =>
    Prim.ellipsoid(0.036 + grow, 0.03 + grow + lift, 0.075 + grow,
        center: _footCenter + Vec3(0, lift * 0.5, 0), segments: 16, rings: 10, p1: top);

Mesh _sole(double thickness, {double extraLength = 0.012, double width = 0.088}) =>
    Prim.roundedBox(width, thickness, 0.15 + extraLength * 2, e: 0.35, center: Vec3(0, -0.06 + thickness * 0.15, 0.035));

Part _shaft(String shin, int color,
        {double top = -0.25, double r = 0.048, double gloss = 0.1}) =>
    Part(
        shin,
        Prim.lathe([
          P2(r - 0.004, -Body.shinLen + 0.01),
          P2(r, -Body.shinLen + 0.05),
          P2(r + 0.002, top),
        ], segments: 16)
            .doubleSided(),
        color: color,
        bias: Layer.shoes + 0.004,
        gloss: gloss);

List<GarmentDefinition> buildShoes() => [
      GarmentDefinition(
        id: 'shoes_classic_sneakers',
        name: 'Classic Sneakers',
        subtype: 'Sneakers',
        category: GarmentCategory.shoes,
        slot: GarmentSlot.shoes,
        variants: const [
          ColorVariant('White', 0xFFF7F7F7, secondary: 0xFFFFFFFF, accent: 0xFFF08DB0),
          ColorVariant('Pink', 0xFFF6B3C9, secondary: 0xFFFFFFFF, accent: 0xFFFFFFFF),
          ColorVariant('Lilac', 0xFFC9B8F0, secondary: 0xFFFFFFFF, accent: 0xFFFFFFFF),
          ColorVariant('Black', 0xFF2E2C33, secondary: 0xFFFFFFFF, accent: 0xFFFFFFFF),
        ],
        hides: BodyTags.feet,
        build: (c) => _pair((l, foot, shin) => _sneaker(c, foot)),
      ),
      GarmentDefinition(
        id: 'shoes_hightops',
        name: 'High-Top Sneakers',
        subtype: 'Sneakers',
        category: GarmentCategory.shoes,
        slot: GarmentSlot.shoes,
        variants: const [
          ColorVariant('Cherry', 0xFFD8435E, secondary: 0xFFF3EFE6, accent: 0xFFFFFFFF),
          ColorVariant('Navy', 0xFF2F3A66, secondary: 0xFFF3EFE6, accent: 0xFFFFFFFF),
          ColorVariant('Mint', 0xFFA6E0C8, secondary: 0xFFF3EFE6, accent: 0xFFFFFFFF),
        ],
        hides: BodyTags.feet,
        build: (c) => _pair((l, foot, shin) => [
              ..._sneaker(c, foot),
              _shaft(shin, c.primary, top: -0.28, r: 0.046),
              Part(
                  shin,
                  Prim.torus(0.047, 0.006, segments: 16, sides: 6)
                      .transformed(Affine.translation(const Vec3(0, -0.28, 0))),
                  color: c.secondary,
                  bias: Layer.shoes + 0.006),
            ]),
      ),
      GarmentDefinition(
        id: 'shoes_chunky_trainers',
        name: 'Chunky Trainers',
        subtype: 'Fashion Trainers',
        category: GarmentCategory.shoes,
        slot: GarmentSlot.shoes,
        variants: const [
          ColorVariant('Cloud', 0xFFF4F2F7, secondary: 0xFFC9B8F0, accent: 0xFFF6B3C9),
          ColorVariant('Sunset', 0xFFFFE2C2, secondary: 0xFFFF8F7A, accent: 0xFFFFD25E),
          ColorVariant('Ocean', 0xFFDDEBFA, secondary: 0xFF5B8ED6, accent: 0xFF9FE3D8),
          ColorVariant('Blossom', 0xFFFBF8F9, secondary: 0xFFFFFFFF, accent: 0xFFF6A9C2),
        ],
        hides: BodyTags.feet,
        build: (c) => _pair((l, foot, shin) => [
              Part(foot, _upper(grow: 0.012), color: c.primary, bias: Layer.shoes),
              // Accent side panels and a sole stripe.
              Part(
                  foot,
                  Mesh.merge([
                    for (final s in [1.0, -1.0])
                      Prim.ellipsoid(0.008, 0.02, 0.05, center: Vec3(s * 0.046, -0.03, 0.03), segments: 10),
                    Prim.torus(0.05, 0.004, segments: 24, sides: 4, sz: 1.9)
                        .transformed(Affine.translation(const Vec3(0, -0.052, 0.035))),
                  ]),
                  color: c.accent,
                  bias: Layer.shoes + 0.005),
              Part(foot, _sole(0.045, extraLength: 0.016, width: 0.1), color: c.secondary, bias: Layer.shoes + 0.002),
              Part(
                  foot,
                  Prim.ellipsoid(0.05, 0.02, 0.06, center: const Vec3(0, -0.02, -0.005), segments: 14),
                  color: c.accent,
                  bias: Layer.shoes + 0.004),
              _laces(foot, 0xFFFFFFFF),
            ]),
      ),
      GarmentDefinition(
        id: 'shoes_slip_on',
        name: 'Checker Slip-Ons',
        subtype: 'Sneakers',
        category: GarmentCategory.shoes,
        slot: GarmentSlot.shoes,
        variants: const [
          ColorVariant('Black Check', 0xFF2E2C33, secondary: 0xFFFFFFFF),
          ColorVariant('Pink Check', 0xFFF29BB6, secondary: 0xFFFFFFFF),
          ColorVariant('Lavender Check', 0xFFB39DEB, secondary: 0xFFFFFFFF),
        ],
        hides: BodyTags.feet,
        build: (c) => _pair((l, foot, shin) => [
              Part(
                  foot,
                  _upper().painted((p, _) =>
                      ((p.x * 90).floor() + (p.z * 90).floor()).isEven ? c.primary : c.secondary),
                  bias: Layer.shoes),
              Part(foot, _sole(0.024), color: 0xFFFFFFFF, bias: Layer.shoes + 0.002),
            ]),
      ),
      GarmentDefinition(
        id: 'shoes_ankle_boots',
        name: 'Ankle Boots',
        subtype: 'Boots',
        category: GarmentCategory.shoes,
        slot: GarmentSlot.shoes,
        variants: const [
          ColorVariant('Cognac', 0xFFA8643A, secondary: 0xFF5A3A26),
          ColorVariant('Black', 0xFF2B2830, secondary: 0xFF1C1A20),
          ColorVariant('Cream', 0xFFEDE3D2, secondary: 0xFF8A7560),
        ],
        hides: BodyTags.feet,
        build: (c) => _pair((l, foot, shin) => [
              Part(foot, _upper(grow: 0.01), color: c.primary, bias: Layer.shoes, gloss: 0.3),
              Part(foot, _sole(0.022), color: c.secondary, bias: Layer.shoes + 0.002),
              Part(foot, Prim.roundedBox(0.05, 0.035, 0.04, e: 0.4, center: const Vec3(0, -0.055, -0.03)),
                  color: c.secondary, bias: Layer.shoes + 0.002),
              _shaft(shin, c.primary, top: -0.24, gloss: 0.3),
            ]),
      ),
      GarmentDefinition(
        id: 'shoes_rain_boots',
        name: 'Glossy Rain Boots',
        subtype: 'Boots',
        category: GarmentCategory.shoes,
        slot: GarmentSlot.shoes,
        variants: const [
          ColorVariant('Sunny Yellow', 0xFFFFD34D),
          ColorVariant('Bubblegum', 0xFFF58DB3),
          ColorVariant('Frog Green', 0xFF7CCB7A),
          ColorVariant('Clear Sky', 0xFF8EC5F2),
        ],
        hides: {...BodyTags.feet, 'shin_L', 'shin_R'},
        build: (c) => _pair((l, foot, shin) => [
              Part(foot, _upper(grow: 0.014), color: c.primary, bias: Layer.shoes, gloss: 0.8),
              Part(foot, _sole(0.024, width: 0.1), color: shadeArgb(c.primary, 0.75), bias: Layer.shoes + 0.002),
              Part(
                  shin,
                  Prim.lathe([
                    const P2(0.05, -Body.shinLen + 0.01),
                    const P2(0.052, -0.2),
                    const P2(0.06, -0.08),
                    const P2(0.062, -0.07),
                  ], segments: 18)
                      .doubleSided(),
                  color: c.primary,
                  bias: Layer.shoes + 0.004,
                  gloss: 0.8),
            ]),
      ),
      GarmentDefinition(
        id: 'shoes_strappy_sandals',
        name: 'Strappy Sandals',
        subtype: 'Sandals',
        category: GarmentCategory.shoes,
        slot: GarmentSlot.shoes,
        variants: const [
          ColorVariant('Tan', 0xFFC89A6A),
          ColorVariant('White', 0xFFF7F4EE),
          ColorVariant('Rose Gold', 0xFFE7B0A0),
        ],
        build: (c) => _pair((l, foot, shin) => [
              Part(foot, _sole(0.018), color: c.primary, bias: Layer.shoes),
              Part(
                  foot,
                  Mesh.merge([
                    for (final z in [0.075, 0.03])
                      Prim.torus(0.038, 0.0045, segments: 16, sides: 5, a0: -1.7, a1: 1.7, sz: 0.9)
                          .transformed(Affine.translation(Vec3(0, -0.04, z)) * Affine.rotX(math.pi / 2) * Affine.rotY(math.pi / 2)),
                    Prim.torus(0.034, 0.0045, segments: 16, sides: 5)
                        .transformed(Affine.translation(const Vec3(0, 0.005, -0.005))),
                  ]),
                  color: c.primary,
                  bias: Layer.shoes + 0.002),
            ]),
      ),
      GarmentDefinition(
        id: 'shoes_slides',
        name: 'Puffy Slides',
        subtype: 'Sandals',
        category: GarmentCategory.shoes,
        slot: GarmentSlot.shoes,
        variants: const [
          ColorVariant('Lilac', 0xFFC7B5F0),
          ColorVariant('Peach', 0xFFFFC3A8),
          ColorVariant('Mint', 0xFFAEE6CF),
        ],
        build: (c) => _pair((l, foot, shin) => [
              Part(foot, _sole(0.026, width: 0.095), color: c.primary, bias: Layer.shoes),
              Part(
                  foot,
                  Prim.ellipsoid(0.05, 0.03, 0.045, center: const Vec3(0, -0.035, 0.065), segments: 14, p0: 0.5),
                  color: c.primary,
                  bias: Layer.shoes + 0.002),
            ]),
      ),
      GarmentDefinition(
        id: 'shoes_ballet_flats',
        name: 'Ballet Flats',
        subtype: 'Flats',
        category: GarmentCategory.shoes,
        slot: GarmentSlot.shoes,
        variants: const [
          ColorVariant('Blush', 0xFFF4B9C6, accent: 0xFFFFFFFF),
          ColorVariant('Silver', 0xFFD7D9E0, accent: 0xFF9AA0B5),
          ColorVariant('Black', 0xFF2E2C33, accent: 0xFFF4B9C6),
        ],
        build: (c) => _pair((l, foot, shin) => [
              Part(foot, _upper(grow: 0.005, top: math.pi * 0.48), color: c.primary, bias: Layer.shoes, gloss: 0.4),
              Part(foot, _sole(0.014), color: shadeArgb(c.primary, 0.8), bias: Layer.shoes + 0.001),
              bow(c.accent, const Vec3(0, -0.035, 0.105), 0.016, bone: foot, bias: Layer.shoes + 0.006),
            ]),
      ),
      GarmentDefinition(
        id: 'shoes_mary_janes',
        name: 'Mary Janes',
        subtype: 'Flats',
        category: GarmentCategory.shoes,
        slot: GarmentSlot.shoes,
        variants: const [
          ColorVariant('Patent Black', 0xFF26232B),
          ColorVariant('Cherry', 0xFFC7364F),
          ColorVariant('Cream', 0xFFF3E9DA),
        ],
        build: (c) => _pair((l, foot, shin) => [
              Part(foot, _upper(grow: 0.007, top: math.pi * 0.5), color: c.primary, bias: Layer.shoes, gloss: 0.9),
              Part(foot, _sole(0.02), color: shadeArgb(c.primary, 0.7), bias: Layer.shoes + 0.001),
              Part(
                  foot,
                  Prim.torus(0.04, 0.005, segments: 16, sides: 5, a0: -1.6, a1: 1.6)
                      .transformed(Affine.translation(const Vec3(0, -0.035, 0.01)) * Affine.rotX(math.pi / 2) * Affine.rotY(math.pi / 2)),
                  color: c.primary,
                  bias: Layer.shoes + 0.003,
                  gloss: 0.9),
            ]),
      ),
    ];

List<Part> _sneaker(GarmentBuildContext c, String foot) => [
      Part(foot, _upper(), color: c.primary, bias: Layer.shoes, gloss: 0.15),
      Part(foot, _sole(0.026), color: c.secondary, bias: Layer.shoes + 0.002),
      Part(foot, Prim.ellipsoid(0.04, 0.022, 0.03, center: const Vec3(0, -0.04, 0.095), segments: 12),
          color: c.secondary, bias: Layer.shoes + 0.003),
      Part(
          foot,
          Prim.tube([
            const Vec3(0.046, -0.04, 0.0),
            const Vec3(0.047, -0.025, 0.04),
            const Vec3(0.044, -0.045, 0.075),
          ], radius: 0.005, sides: 5)
              .transformed(foot.endsWith('R') ? Affine.scale(const Vec3(-1, 1, 1)) : Affine.identity),
          color: c.accent,
          bias: Layer.shoes + 0.006),
      _laces(foot, c.secondary),
    ];

Part _laces(String foot, int color) => Part(
    foot,
    Mesh.merge([
      for (final z in [0.035, 0.055, 0.075])
        Prim.rod(Vec3(-0.018, 0.0 - (z - 0.035) * 0.35, z), Vec3(0.018, 0.0 - (z - 0.035) * 0.35, z), 0.0035, sides: 5)
    ]),
    color: color,
    bias: Layer.shoes + 0.006);
