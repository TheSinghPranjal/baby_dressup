import 'dart:math' as math;

import '../../character/body_builder.dart';
import '../../character/body_metrics.dart';
import '../../character/part.dart';
import '../../character/skeleton.dart';
import '../../engine/math3d.dart';
import '../../engine/mesh.dart';
import '../../engine/primitives.dart';
import '../garment.dart';
import 'kit.dart';

const _pastels = [
  ColorVariant('Blush', 0xFFF7B6C8, secondary: 0xFFFFFFFF, accent: 0xFFE86A92),
  ColorVariant('Lavender', 0xFFC9B6F2, secondary: 0xFFFFFFFF, accent: 0xFF8A6AD8),
  ColorVariant('Mint', 0xFFAEE6CF, secondary: 0xFFFFFFFF, accent: 0xFF3FAE88),
  ColorVariant('Butter', 0xFFFFE7A3, secondary: 0xFFFFFFFF, accent: 0xFFE7A93B),
  ColorVariant('Sky', 0xFFA8D4F5, secondary: 0xFFFFFFFF, accent: 0xFF3E86C7),
];

Set<String> _topHides(double sleeve) => {BodyTags.torso, ...Kit.sleeveHides(sleeve)};

List<GarmentDefinition> buildTops() => [
      GarmentDefinition(
        id: 'top_basic_tee',
        name: 'Everyday Tee',
        subtype: 'T-Shirt',
        category: GarmentCategory.tops,
        slot: GarmentSlot.top,
        variants: [
          const ColorVariant('White', 0xFFF8F6F4),
          ..._pastels,
          const ColorVariant('Charcoal', 0xFF4A4552),
        ],
        hides: _topHides(0.11),
        build: (c) => [
          Kit.torso(c.primary),
          ...Kit.sleeves(c.primary, length: 0.11),
          _neckRib(c.primary),
        ],
      ),
      GarmentDefinition(
        id: 'top_striped_tee',
        name: 'Breton Stripe Tee',
        subtype: 'T-Shirt',
        category: GarmentCategory.tops,
        slot: GarmentSlot.top,
        variants: const [
          ColorVariant('Navy', 0xFFF6F3EE, secondary: 0xFF2E3A6B),
          ColorVariant('Berry', 0xFFF6F3EE, secondary: 0xFFC2477A),
          ColorVariant('Sage', 0xFFF6F3EE, secondary: 0xFF6E9C7E),
        ],
        hides: _topHides(0.2),
        build: (c) {
          final p = Kit.stripes(c.primary, c.secondary, freq: 85);
          return [
            Kit.torso(c.primary, paint: p),
            ...Kit.sleeves(c.primary, length: 0.2, paint: p),
            _neckRib(c.primary),
          ];
        },
      ),
      GarmentDefinition(
        id: 'top_heart_tee',
        name: 'Heart Graphic Tee',
        subtype: 'T-Shirt',
        category: GarmentCategory.tops,
        slot: GarmentSlot.top,
        variants: const [
          ColorVariant('Cream', 0xFFFFF6EA, accent: 0xFFE84A7F),
          ColorVariant('Lilac', 0xFFE3D6FA, accent: 0xFFFF6FA5),
          ColorVariant('Black', 0xFF34303A, accent: 0xFFFF8AB8),
        ],
        hides: _topHides(0.11),
        build: (c) => [
          Kit.torso(c.primary, flare: 0.012),
          ...Kit.sleeves(c.primary, length: 0.11, flare: 0.006),
          _neckRib(c.primary),
          _heartDecal(c.accent, Body.torsoFront(0, 0.19, offset: 0.015), 0.05),
        ],
      ),
      GarmentDefinition(
        id: 'top_sport_tank',
        name: 'Ribbed Sport Tank',
        subtype: 'Tank Top',
        category: GarmentCategory.tops,
        slot: GarmentSlot.top,
        variants: const [
          ColorVariant('Coral', 0xFFF4806F, accent: 0xFFFFFFFF),
          ColorVariant('Aqua', 0xFF7FD6D2, accent: 0xFFFFFFFF),
          ColorVariant('Lemon', 0xFFFFE680, accent: 0xFFFFFFFF),
          ColorVariant('Grape', 0xFFA383E0, accent: 0xFFFFFFFF),
        ],
        // Shoulders and upper chest stay visible between the straps, so the
        // body underneath is not masked; the shell sits on top of it.
        build: (c) => _tank(c),
      ),
      GarmentDefinition(
        id: 'top_puff_blouse',
        name: 'Puff-Sleeve Blouse',
        subtype: 'Blouse',
        category: GarmentCategory.tops,
        slot: GarmentSlot.top,
        variants: const [
          ColorVariant('Ivory', 0xFFFFFBF2, accent: 0xFFF2A7BE),
          ColorVariant('Rose', 0xFFF9C9D6, accent: 0xFFFFFFFF),
          ColorVariant('Periwinkle', 0xFFC4CCF6, accent: 0xFFFFFFFF),
        ],
        hides: _topHides(0.14),
        build: (c) => [
          Kit.torso(c.primary, flare: 0.01),
          ...Kit.sleeves(c.primary, length: 0.14, puff: 0.022, cuffColor: c.accent),
          _collar(shadeArgb(c.primary, 0.97), round: true),
          Kit.buttons(c.accent, 0, [0.27, 0.21, 0.15]),
        ],
      ),
      GarmentDefinition(
        id: 'top_button_shirt',
        name: 'Oxford Button-Up',
        subtype: 'Shirt',
        category: GarmentCategory.tops,
        slot: GarmentSlot.top,
        variants: const [
          ColorVariant('Sky Oxford', 0xFFBFD9F2, accent: 0xFFFFFFFF),
          ColorVariant('White', 0xFFF9F9F9, accent: 0xFFDADADA),
          ColorVariant('Gingham', 0xFFFFFFFF, secondary: 0xFFE57B94, accent: 0xFFFFFFFF),
        ],
        hides: _topHides(0.45),
        build: (c) {
          final paint = c.variant.name == 'Gingham'
              ? Kit.plaid(0xFFFFFFFF, c.secondary, c.secondary, freq: 90)
              : null;
          return [
            Kit.torso(c.primary, paint: paint, flare: 0.006),
            ...Kit.sleeves(c.primary, length: 0.45, paint: paint, cuffColor: c.primary),
            _collar(c.primary == 0xFFFFFFFF ? 0xFFFFFFFF : c.primary),
            Kit.buttons(c.accent, 0, [0.3, 0.24, 0.18, 0.12, 0.06, 0.0]),
          ];
        },
      ),
      GarmentDefinition(
        id: 'top_cozy_sweater',
        name: 'Cozy Knit Sweater',
        subtype: 'Sweater',
        category: GarmentCategory.tops,
        slot: GarmentSlot.top,
        variants: const [
          ColorVariant('Oatmeal', 0xFFE9DCC6),
          ColorVariant('Strawberry', 0xFFF5A3B7),
          ColorVariant('Matcha', 0xFFB7D3A0),
          ColorVariant('Cocoa', 0xFF9C7563),
        ],
        hides: _topHides(0.46),
        build: (c) {
          final k = Kit.knit(c.primary);
          return [
            Kit.torso(c.primary, grow: 0.016, flare: 0.006, paint: k),
            ...Kit.sleeves(c.primary, length: 0.46, grow: 0.013, paint: k, cuffColor: shadeArgb(c.primary, 0.93)),
            _hemBand(c.primary, -0.06, 0.016),
            _neckRib(c.primary, grow: 0.016),
          ];
        },
      ),
      GarmentDefinition(
        id: 'top_turtleneck',
        name: 'Ribbed Turtleneck',
        subtype: 'Sweater',
        category: GarmentCategory.tops,
        slot: GarmentSlot.top,
        variants: const [
          ColorVariant('Cream', 0xFFF3EBDD),
          ColorVariant('Black', 0xFF2F2C33),
          ColorVariant('Lilac', 0xFFD3C2F0),
        ],
        hides: {..._topHides(0.46), BodyTags.neck},
        build: (c) {
          final k = Kit.knit(c.primary);
          return [
            Kit.torso(c.primary, grow: 0.01, paint: k),
            ...Kit.sleeves(c.primary, length: 0.46, grow: 0.009, paint: k),
            Part(
                Bones.neck,
                Prim.lathe(const [P2(0.056, -0.03), P2(0.05, 0.03), P2(0.048, 0.075)],
                        segments: 20)
                    .doubleSided()
                    .painted(k),
                bias: Layer.top),
          ];
        },
      ),
      GarmentDefinition(
        id: 'top_hoodie',
        name: 'Comfy Hoodie',
        subtype: 'Hoodie',
        category: GarmentCategory.tops,
        slot: GarmentSlot.top,
        variants: const [
          ColorVariant('Heather', 0xFFC9C6CF, accent: 0xFFFFFFFF),
          ColorVariant('Pink', 0xFFF7A9C4, accent: 0xFFFFFFFF),
          ColorVariant('Forest', 0xFF5E8B6F, accent: 0xFFF2E9D8),
          ColorVariant('Navy', 0xFF3A4675, accent: 0xFFFFFFFF),
        ],
        hides: _topHides(0.46),
        build: (c) => [
          Kit.torso(c.primary, grow: 0.018, flare: 0.006),
          ...Kit.sleeves(c.primary, length: 0.46, grow: 0.015, cuffColor: shadeArgb(c.primary, 0.9)),
          _hemBand(c.primary, -0.06, 0.018),
          // Hood resting on the shoulders.
          Part(
              Bones.spine,
              Prim.ellipsoid(0.105, 0.075, 0.08,
                      center: const Vec3(0, 0.345, -0.07), segments: 18)
                  .solid(shadeArgb(c.primary, 0.95)),
              bias: Layer.top + 0.002),
          // Kangaroo pocket.
          Part(
              Bones.spine,
              Prim.roundedBox(0.15, 0.07, 0.012, e: 0.3)
                  .transformed(Affine.translation(Body.torsoFront(0, 0.04, offset: 0.024)) *
                      Affine.lookDir(const Vec3(0, -0.05, 1)))
                  .solid(shadeArgb(c.primary, 0.94)),
              bias: Layer.top + 0.006,
              decal: true),
          // Drawstrings.
          Part(
              Bones.spine,
              Mesh.merge([
                Prim.tube(Kit.frontPath([[0.025, 0.34], [0.028, 0.29], [0.03, 0.24]], offset: 0.024),
                    radius: 0.004, sides: 5),
                Prim.tube(Kit.frontPath([[-0.025, 0.34], [-0.028, 0.29], [-0.03, 0.25]], offset: 0.024),
                    radius: 0.004, sides: 5),
              ]),
              color: c.accent,
              bias: Layer.top + 0.008),
        ],
      ),
      GarmentDefinition(
        id: 'outer_denim_jacket',
        name: 'Denim Jacket',
        subtype: 'Jacket',
        category: GarmentCategory.tops,
        slot: GarmentSlot.outerwear,
        variants: const [
          ColorVariant('Classic', 0xFF6E8FC2, accent: 0xFFE3B35E),
          ColorVariant('Light Wash', 0xFFA9C2E6, accent: 0xFFE3B35E),
          ColorVariant('Pastel Pink', 0xFFF4B3C8, accent: 0xFFFFFFFF),
        ],
        hides: Kit.sleeveHides(0.44),
        build: (c) => _jacket(c, grow: 0.026, paint: Kit.denim(c.primary), cuff: true),
      ),
      GarmentDefinition(
        id: 'outer_bomber',
        name: 'Satin Bomber',
        subtype: 'Jacket',
        category: GarmentCategory.tops,
        slot: GarmentSlot.outerwear,
        variants: const [
          ColorVariant('Sage', 0xFF9DBFA6, accent: 0xFF2F2F35),
          ColorVariant('Blush', 0xFFF0B9C6, accent: 0xFF3B2F3A),
          ColorVariant('Midnight', 0xFF2E3550, accent: 0xFFE87F2E),
        ],
        hides: Kit.sleeveHides(0.44),
        build: (c) => _jacket(c, grow: 0.03, gloss: 0.45, band: true),
      ),
      GarmentDefinition(
        id: 'outer_cardigan',
        name: 'Button Cardigan',
        subtype: 'Cardigan',
        category: GarmentCategory.tops,
        slot: GarmentSlot.outerwear,
        variants: const [
          ColorVariant('Lavender', 0xFFCDB8EE, accent: 0xFFFFFFFF),
          ColorVariant('Cream', 0xFFF1E6D2, accent: 0xFFB08A5A),
          ColorVariant('Cherry', 0xFFE0607E, accent: 0xFFFFFFFF),
        ],
        hides: Kit.sleeveHides(0.44),
        build: (c) => _jacket(c, grow: 0.024, paint: Kit.knit(c.primary), buttons: true, open: 0.42),
      ),
      GarmentDefinition(
        id: 'outer_zara_signature',
        name: "Zara's Varsity Jacket",
        subtype: 'Jacket',
        category: GarmentCategory.tops,
        slot: GarmentSlot.outerwear,
        compatibleCharacters: const {'zara'},
        unlockAtSavedLooks: 1,
        variants: const [
          ColorVariant('Varsity', 0xFF2B2B38, secondary: 0xFFF2EFE8, accent: 0xFFE8A33B),
        ],
        hides: Kit.sleeveHides(0.44),
        build: (c) => _jacket(c, grow: 0.03, band: true, sleeveColor: c.secondary),
      ),
    ];

List<Part> _jacket(GarmentBuildContext c,
    {double grow = 0.026,
    Painter? paint,
    double gloss = 0.08,
    bool cuff = false,
    bool band = false,
    bool buttons = false,
    double open = 0.5,
    int? sleeveColor}) {
  final sc = sleeveColor ?? c.primary;
  final parts = <Part>[
    Kit.torso(c.primary,
        grow: grow,
        a0: open,
        a1: Kit.tau - open,
        bias: Layer.outer,
        paint: paint,
        gloss: gloss,
        from: -0.075,
        flare: 0.006),
    ...Kit.sleeves(sc,
        length: 0.44,
        grow: grow - 0.004,
        bias: Layer.outer,
        paint: sleeveColor == null ? paint : null,
        cuffColor: band ? c.accent : (cuff ? shadeArgb(c.primary, 0.9) : null)),
  ];
  // Lapels / plackets along the open front.
  for (final s in [1.0, -1.0]) {
    final pts = <Vec3>[];
    for (var k = 0; k <= 8; k++) {
      final y = lerpDouble(-0.07, 0.33, k / 8);
      final r = Body.profileRadius(Body.torsoProfile, y);
      final a = s * (open + 0.02);
      pts.add(Vec3((r + grow + 0.004) * math.sin(a), y,
          (r * Body.torsoDepth + grow + 0.004) * math.cos(a)));
    }
    parts.add(Part(Bones.spine, Prim.tube(pts, radius: 0.007, sides: 6),
        color: band ? c.accent : shadeArgb(c.primary, 0.9), bias: Layer.outer + 0.004));
  }
  if (band) {
    parts.add(_hemBand(c.accent, -0.07, grow + 0.002, bias: Layer.outer + 0.002, a0: open, a1: Kit.tau - open));
    parts.add(_neckRib(c.accent, grow: grow, bias: Layer.outer + 0.002));
  } else {
    parts.add(_collar(shadeArgb(c.primary, 0.95), grow: grow, bias: Layer.outer + 0.003));
  }
  if (buttons) {
    final y0 = 0.28;
    final x = math.sin(open + 0.05) * 0.1;
    parts.add(Kit.buttons(c.accent, x, [for (var k = 0; k < 5; k++) y0 - k * 0.07],
        offset: grow + 0.006, bias: Layer.outer + 0.006));
  }
  return parts;
}

/// Ribbed tank: body shell up to the underarm, wide straps and white piping
/// along the neckline and armholes.
List<Part> _tank(GarmentBuildContext c) {
  final rib = Kit.rib(c.primary);
  const top = 0.285;
  List<Vec3> strap(double s, double inset) => [
        Body.torsoFront(s * (0.058 + inset), top - 0.01, offset: 0.013),
        Body.torsoFront(s * (0.066 + inset), 0.315, offset: 0.012),
        Vec3(s * (0.078 + inset), 0.352, 0.018),
        Vec3(s * (0.08 + inset), 0.352, -0.022),
        Body.torsoBack(s * (0.066 + inset), 0.31, offset: 0.012),
        Body.torsoBack(s * (0.06 + inset), top - 0.01, offset: 0.013),
      ];
  List<Vec3> neckline({required bool front}) => [
        for (var k = 0; k <= 12; k++)
          () {
            final x = -0.058 + 0.116 * k / 12;
            final dip = front ? 0.022 : 0.008;
            final y = top - 0.008 - dip * (1 - (x / 0.058) * (x / 0.058));
            return front
                ? Body.torsoFront(x, y, offset: 0.016)
                : Body.torsoBack(x, y, offset: 0.016);
          }()
      ];
  List<Vec3> armhole(double s) => [
        for (var k = 0; k <= 12; k++)
          () {
            // Loop from the front strap edge, under the arm, to the back.
            final a = math.pi * k / 12;
            final r = Body.profileRadius(Body.torsoProfile, 0.2) + 0.016;
            final x = s * (0.072 + 0.04 * math.sin(a));
            final y = top - 0.005 - 0.075 * math.sin(a);
            final z = math.cos(a) * math.sqrt(math.max(0, r * r - x * x)) * Body.torsoDepth;
            return Vec3(x, y, z);
          }()
      ];
  return [
    Kit.torso(c.primary, from: 0.03, to: top, grow: 0.012, paint: rib),
    Part(
        Bones.spine,
        Mesh.merge([
          for (final s in [1.0, -1.0]) Prim.tube(strap(s, 0.0), radius: 0.011, sides: 6),
        ]).painted(rib),
        bias: Layer.top + 0.002),
    Part(
        Bones.spine,
        Mesh.merge([
          Prim.tube(neckline(front: true), radius: 0.0042, sides: 5),
          Prim.tube(neckline(front: false), radius: 0.0042, sides: 5),
          for (final s in [1.0, -1.0]) ...[
            Prim.tube(strap(s, 0.012), radius: 0.0038, sides: 5),
            Prim.tube(armhole(s), radius: 0.0042, sides: 5),
          ],
        ]),
        color: c.accent,
        bias: Layer.top + 0.006),
  ];
}

Part _neckRib(int color, {double grow = 0.01, double bias = Layer.top + 0.002}) => Part(
    Bones.spine,
    Prim.torus(0.052 + grow * 0.6, 0.007, sz: 0.85, segments: 22, sides: 6)
        .transformed(Affine.translation(const Vec3(0, 0.343, 0))),
    color: shadeArgb(color, 0.95),
    bias: bias);

Part _hemBand(int color, double y, double grow,
        {double bias = Layer.top + 0.002, double a0 = 0, double a1 = Kit.tau}) =>
    Part(
        Bones.spine,
        Prim.torus(Body.profileRadius(Body.torsoProfile, y) + grow + 0.004, 0.012,
                sz: Body.torsoDepth, segments: 28, sides: 6, a0: a0, a1: a1)
            .transformed(Affine.translation(Vec3(0, y + 0.01, 0))),
        color: shadeArgb(color, 0.92),
        bias: bias);

Part _collar(int color,
    {bool round = false, double grow = 0.012, double bias = Layer.top + 0.004}) {
  final flaps = <Mesh>[];
  for (final s in [1.0, -1.0]) {
    // Flat collar flaps hugging the neckline, angled outwards.
    final m = round
        ? Prim.disc(0.034, 0.02, dome: 0.2, segments: 14)
        : Prim.roundedBox(0.05, 0.03, 0.007, e: 0.4);
    final pos = Body.torsoFront(s * 0.036, 0.334, offset: grow + 0.008);
    flaps.add(m.transformed(Affine.translation(pos) *
        Affine.rotZ(s * (round ? 0.5 : 0.7)) *
        Affine.rotX(-1.15)));
  }
  return Part(Bones.spine, Mesh.merge(flaps).solid(color), bias: bias);
}

Part _heartDecal(int color, Vec3 at, double size) {
  final lobes = Mesh.merge([
    Prim.disc(size * 0.3, size * 0.3, dome: 0.2, center: Vec3(-size * 0.22, size * 0.12, 0)),
    Prim.disc(size * 0.3, size * 0.3, dome: 0.2, center: Vec3(size * 0.22, size * 0.12, 0)),
    Prim.disc(size * 0.34, size * 0.34, dome: 0.2, segments: 4)
        .transformed(Affine.translation(Vec3(0, -size * 0.12, 0)) * Affine.rotZ(math.pi / 4)),
  ]);
  return Part(Bones.spine, lobes.transformed(Affine.translation(at)),
      color: color, bias: Layer.top + 0.01, decal: true);
}

/// Exposed for other builders (dresses reuse the heart and collar).
Part heartDecal(int color, Vec3 at, double size) => _heartDecal(color, at, size);
Part neckRib(int color, {double grow = 0.01, double bias = Layer.top + 0.002}) =>
    _neckRib(color, grow: grow, bias: bias);
Part collar(int color, {bool round = false, double grow = 0.012}) =>
    _collar(color, round: round, grow: grow);
