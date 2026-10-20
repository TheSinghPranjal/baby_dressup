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
import 'tops.dart' show heartDecal, neckRib, collar;

Set<String> _dressHides(double sleeve, {Set<String> extra = const {}}) =>
    {BodyTags.torso, BodyTags.pelvis, ...Kit.sleeveHides(sleeve), ...extra};

/// Bodice + skirt on the hips bone.
List<Part> _dress(int color,
    {double sleeve = 0,
    double hem = -0.3,
    double rHem = 0.2,
    double pleats = 0,
    Painter? paint,
    double puff = 0,
    double to = 0.35,
    double grow = 0.01,
    double gloss = 0.05}) {
  return [
    Kit.torso(color, from: -0.07, to: to, grow: grow, paint: paint, gloss: gloss, bias: Layer.top),
    Kit.pelvis(shadeArgb(color, 0.75), grow: 0.006),
    Kit.skirt(color,
        top: 0.07,
        hem: hem,
        rTop: 0.114 + grow,
        rHem: rHem,
        pleats: pleats,
        paint: paint,
        gloss: gloss,
        bias: Layer.top - 0.001),
    if (sleeve > 0) ...Kit.sleeves(color, length: sleeve, puff: puff, paint: paint),
  ];
}

Part _bow(int color, Vec3 at, double size, {String bone = Bones.spine, double bias = Layer.top + 0.01}) {
  final m = Mesh.merge([
    Prim.ellipsoid(size * 0.6, size * 0.38, size * 0.2, center: Vec3(-size * 0.55, 0, 0), segments: 12)
        .transformed(Affine.rotZ(0.15)),
    Prim.ellipsoid(size * 0.6, size * 0.38, size * 0.2, center: Vec3(size * 0.55, 0, 0), segments: 12)
        .transformed(Affine.rotZ(-0.15)),
    Prim.sphere(size * 0.22, segments: 10),
  ]);
  return Part(bone, m.transformed(Affine.translation(at)), color: color, bias: bias, gloss: 0.3);
}

Part bow(int color, Vec3 at, double size, {String bone = Bones.spine, double bias = Layer.top + 0.01}) =>
    _bow(color, at, size, bone: bone, bias: bias);

Part _straps(int color, {double bias = Layer.top + 0.003}) => Part(
    Bones.spine,
    Mesh.merge([
      for (final s in [1.0, -1.0])
        Prim.tube([
          Body.torsoFront(s * 0.06, 0.28, offset: 0.012),
          Vec3(s * 0.075, 0.345, 0.02),
          Vec3(s * 0.078, 0.35, -0.02),
          Body.torsoBack(s * 0.06, 0.28, offset: 0.012),
        ], radius: 0.007, sides: 6)
    ]),
    color: color,
    bias: bias);

List<GarmentDefinition> buildOutfits() => [
      GarmentDefinition(
        id: 'dress_tee_dress',
        name: 'T-Shirt Dress',
        subtype: 'Casual Dress',
        category: GarmentCategory.dresses,
        slot: GarmentSlot.fullOutfit,
        variants: const [
          ColorVariant('Heather', 0xFFC9C6CF, accent: 0xFFE95C8B),
          ColorVariant('Striped Navy', 0xFFF4F1EA, secondary: 0xFF34437A, accent: 0xFFE95C8B),
          ColorVariant('Mint', 0xFFB9E7D2, accent: 0xFFFFFFFF),
        ],
        hides: _dressHides(0.12),
        build: (c) {
          final paint = c.variant.name.startsWith('Striped')
              ? Kit.stripes(c.primary, c.secondary, freq: 80)
              : null;
          return [
            ..._dress(c.primary, sleeve: 0.12, hem: -0.32, rHem: 0.165, paint: paint),
            neckRib(c.primary),
          ];
        },
      ),
      GarmentDefinition(
        id: 'dress_party_tulle',
        name: 'Party Tulle Dress',
        subtype: 'Party Dress',
        category: GarmentCategory.dresses,
        slot: GarmentSlot.fullOutfit,
        variants: const [
          ColorVariant('Ballet Pink', 0xFFF6B8CC, secondary: 0xFFFCE0EA, accent: 0xFFFFFFFF),
          ColorVariant('Lilac Dream', 0xFFC7B3F2, secondary: 0xFFE6DCFB, accent: 0xFFFFF3B0),
          ColorVariant('Seafoam', 0xFF9FDCCB, secondary: 0xFFD7F2EA, accent: 0xFFFFFFFF),
          ColorVariant('Midnight Star', 0xFF34386B, secondary: 0xFF5A5FA0, accent: 0xFFFFE082),
        ],
        hides: _dressHides(0.1),
        build: (c) => [
          Kit.torso(c.primary, from: -0.07, gloss: 0.35, paint: Kit.dots(c.primary, c.accent, freq: 160)),
          Kit.pelvis(shadeArgb(c.primary, 0.75), grow: 0.006),
          ...Kit.sleeves(c.secondary, length: 0.1, puff: 0.028),
          Kit.skirt(c.primary, top: 0.08, hem: -0.24, rTop: 0.13, rHem: 0.24,
              gloss: 0.2, bias: Layer.top - 0.003),
          Kit.skirt(c.secondary, top: 0.075, hem: -0.3, rTop: 0.135, rHem: 0.27,
              bias: Layer.top - 0.001, pleats: 0.04, pleatCount: 12,
              paint: Kit.dots(c.secondary, c.accent, freq: 120)),
          Part(
              Bones.spine,
              Prim.torus(Body.profileRadius(Body.torsoProfile, -0.04) + 0.016, 0.012,
                      sz: Body.torsoDepth, segments: 28, sides: 6)
                  .transformed(Affine.translation(const Vec3(0, -0.035, 0))),
              color: c.accent,
              bias: Layer.top + 0.004,
              gloss: 0.5),
          bow(c.accent, Body.torsoFront(0.0, -0.035, offset: 0.03), 0.04),
        ],
      ),
      GarmentDefinition(
        id: 'dress_summer_sun',
        name: 'Polka Sundress',
        subtype: 'Summer Dress',
        category: GarmentCategory.dresses,
        slot: GarmentSlot.fullOutfit,
        variants: const [
          ColorVariant('Lemon Dot', 0xFFFFE58F, accent: 0xFFFFFFFF),
          ColorVariant('Cherry Dot', 0xFFE8506E, accent: 0xFFFFFFFF),
          ColorVariant('Sky Dot', 0xFF9ACBF0, accent: 0xFFFFFFFF),
        ],
        hides: _dressHides(0),
        build: (c) {
          final p = Kit.dots(c.primary, c.accent, freq: 90);
          return [
            ..._dress(c.primary, to: 0.3, hem: -0.36, rHem: 0.22, paint: p),
            _straps(c.primary),
            bow(c.accent, Body.torsoFront(0, 0.27, offset: 0.02), 0.026),
          ];
        },
      ),
      GarmentDefinition(
        id: 'dress_floral_maxi',
        name: 'Garden Maxi Dress',
        subtype: 'Summer Dress',
        category: GarmentCategory.dresses,
        slot: GarmentSlot.fullOutfit,
        variants: const [
          ColorVariant('Rose Garden', 0xFFFFF0F3, secondary: 0xFFF08CAB, accent: 0xFFF9D35A),
          ColorVariant('Blue Meadow', 0xFFEAF3FF, secondary: 0xFF7BA7E6, accent: 0xFFFFFFFF),
          ColorVariant('Sage Bloom', 0xFFDCEBD6, secondary: 0xFFF3F0E6, accent: 0xFFE99AB0),
        ],
        hides: _dressHides(0.14, extra: BodyTags.thighs),
        build: (c) {
          final p = Kit.floral(c.primary, c.secondary, c.accent);
          return [
            ..._dress(c.primary, sleeve: 0.14, puff: 0.018, hem: -0.64, rHem: 0.25, paint: p),
            collar(c.primary, round: true),
          ];
        },
      ),
      GarmentDefinition(
        id: 'dress_sweater',
        name: 'Knit Sweater Dress',
        subtype: 'Casual Dress',
        category: GarmentCategory.dresses,
        slot: GarmentSlot.fullOutfit,
        variants: const [
          ColorVariant('Oat', 0xFFE6D7BE),
          ColorVariant('Berry', 0xFFB4486B),
          ColorVariant('Fog', 0xFFBFC6D6),
        ],
        hides: _dressHides(0.46, extra: {BodyTags.neck}),
        build: (c) {
          final k = Kit.knit(c.primary);
          return [
            ..._dress(c.primary, sleeve: 0.46, hem: -0.3, rHem: 0.15, paint: k, grow: 0.016),
            Part(
                Bones.neck,
                Prim.lathe(const [P2(0.06, -0.03), P2(0.054, 0.03), P2(0.05, 0.07)], segments: 20)
                    .doubleSided()
                    .painted(k),
                bias: Layer.top),
          ];
        },
      ),
      GarmentDefinition(
        id: 'jumpsuit_denim',
        name: 'Denim Overalls',
        subtype: 'Jumpsuit',
        category: GarmentCategory.dresses,
        slot: GarmentSlot.fullOutfit,
        variants: const [
          ColorVariant('Classic + Tee', 0xFF6E8FC2, secondary: 0xFFFFFFFF, accent: 0xFFE3B35E),
          ColorVariant('Pink + Stripe', 0xFFF2A9C0, secondary: 0xFFFFFFFF, accent: 0xFFFFFFFF),
          ColorVariant('Lilac + Tee', 0xFFB9A6E0, secondary: 0xFFFFF4C2, accent: 0xFFFFFFFF),
        ],
        hides: {
          BodyTags.torso,
          BodyTags.pelvis,
          ...Kit.legHides(0.72),
        },
        build: (c) {
          final d = Kit.denim(c.primary);
          final tee = c.variant.name.contains('Stripe')
              ? Kit.stripes(c.secondary, 0xFF3A4675, freq: 85)
              : null;
          return [
            Kit.torso(c.secondary, paint: tee, bias: Layer.top - 0.004),
            ...Kit.sleeves(c.secondary, length: 0.11, paint: tee),
            neckRib(c.secondary, bias: Layer.top - 0.002),
            // Bib front and back.
            Kit.torso(c.primary, from: -0.07, to: 0.22, grow: 0.016, paint: d, a0: -0.75, a1: 0.75),
            Kit.torso(c.primary, from: -0.07, to: 0.1, grow: 0.016, paint: d),
            Part(
                Bones.spine,
                Mesh.merge([
                  for (final s in [1.0, -1.0])
                    Prim.tube([
                      Body.torsoFront(s * 0.055, 0.22, offset: 0.018),
                      Body.torsoFront(s * 0.062, 0.3, offset: 0.016),
                      Vec3(s * 0.07, 0.35, 0.0),
                      Body.torsoBack(s * 0.05, 0.28, offset: 0.016),
                      Body.torsoBack(s * 0.03, 0.12, offset: 0.018),
                    ], radius: 0.009, sides: 6)
                ]),
                color: c.primary,
                bias: Layer.top + 0.006),
            Kit.buttons(c.accent, 0.055, [0.22], offset: 0.024),
            Kit.buttons(c.accent, -0.055, [0.22], offset: 0.024),
            Kit.pelvis(c.primary, grow: 0.014, paint: d),
            ...Kit.legs(c.primary, grow: 0.014, flare: 0.012, paint: d, cuff: 0.012),
          ];
        },
      ),
      GarmentDefinition(
        id: 'set_track',
        name: 'Matching Track Set',
        subtype: 'Two-Piece Set',
        category: GarmentCategory.dresses,
        slot: GarmentSlot.fullOutfit,
        variants: const [
          ColorVariant('Cotton Candy', 0xFFF7B7CF, accent: 0xFFFFFFFF),
          ColorVariant('Ocean', 0xFF5B8ED6, accent: 0xFFFFFFFF),
          ColorVariant('Lime Pop', 0xFFC8E87A, accent: 0xFF35323C),
        ],
        hides: {
          BodyTags.torso,
          BodyTags.pelvis,
          ...Kit.sleeveHides(0.46),
          ...Kit.legHides(0.7),
        },
        build: (c) {
          Part stripe(String bone, double len, double r) => Part(
              bone,
              Prim.roundedBox(0.008, len, 0.012, e: 0.3)
                  .transformed(Affine.translation(Vec3(r, -len / 2, 0))),
              color: c.accent,
              bias: Layer.top + 0.004);
          return [
            Kit.torso(c.primary, grow: 0.016),
            ...Kit.sleeves(c.primary, length: 0.46, grow: 0.013, cuffColor: c.accent),
            Part(
                Bones.spine,
                Prim.lathe(const [P2(0.064, 0.33), P2(0.058, 0.38), P2(0.054, 0.41)], segments: 20,
                        sz: 0.9)
                    .doubleSided(),
                color: c.primary,
                bias: Layer.top),
            Part(
                Bones.spine,
                Prim.tube(Kit.frontPath([[0, 0.34], [0, 0.2], [0, 0.05], [0, -0.05]], offset: 0.019),
                    radius: 0.0035, sides: 5),
                color: c.accent,
                bias: Layer.top + 0.006),
            for (final l in [true, false]) ...[
              stripe(Bones.side('upperArm', l), 0.24, (l ? 1 : -1) * 0.05),
              stripe(Bones.side('forearm', l), 0.2, (l ? 1 : -1) * 0.043),
            ],
            Kit.waist(c.primary, top: 0.02, grow: 0.012),
            Kit.pelvis(c.primary, grow: 0.014),
            ...Kit.legs(c.primary, length: 0.7, grow: 0.014, cuff: 0.013),
            for (final l in [true, false]) ...[
              stripe(Bones.side('thigh', l), 0.36, (l ? 1 : -1) * 0.078),
              stripe(Bones.side('shin', l), 0.3, (l ? 1 : -1) * 0.058),
            ],
          ];
        },
      ),
      GarmentDefinition(
        id: 'set_pastel_skirt',
        name: 'Pastel Two-Piece',
        subtype: 'Two-Piece Set',
        category: GarmentCategory.dresses,
        slot: GarmentSlot.fullOutfit,
        variants: const [
          ColorVariant('Strawberry Milk', 0xFFF9C7D6, secondary: 0xFFFFFFFF, accent: 0xFFE8668F),
          ColorVariant('Blueberry', 0xFFC2D4F7, secondary: 0xFFFFFFFF, accent: 0xFF5B7FD6),
          ColorVariant('Pistachio', 0xFFD4EBC5, secondary: 0xFFFFFFFF, accent: 0xFF6FA45B),
        ],
        hides: _dressHides(0.13),
        build: (c) {
          final p = Kit.plaid(c.primary, c.secondary, c.secondary, freq: 70);
          return [
            Kit.torso(c.primary, paint: p, flare: 0.01),
            ...Kit.sleeves(c.primary, length: 0.13, puff: 0.016, paint: p),
            collar(c.secondary, round: true),
            Kit.waist(c.primary, top: 0.0, paint: p),
            Kit.pelvis(shadeArgb(c.primary, 0.75), grow: 0.006),
            Kit.skirt(c.primary, hem: -0.28, rHem: 0.2, pleats: 0.05, paint: p),
            heartDecal(c.accent, Body.torsoFront(0.055, 0.22, offset: 0.016), 0.028),
          ];
        },
      ),
      GarmentDefinition(
        id: 'dress_aria_signature',
        name: "Aria's Starlight Gown",
        subtype: 'Party Dress',
        category: GarmentCategory.dresses,
        slot: GarmentSlot.fullOutfit,
        compatibleCharacters: const {'aria'},
        unlockAtSavedLooks: 2,
        variants: const [
          ColorVariant('Starlight', 0xFF6C5BC9, secondary: 0xFFB9A8FF, accent: 0xFFFFE89A),
        ],
        hides: _dressHides(0.46, extra: BodyTags.thighs),
        build: (c) {
          int grad(Vec3 p, Vec3 n) {
            final base = Kit.gradientY(c.primary, c.secondary, -0.6, 0.3)(p, n);
            final sparkle = math.sin(p.x * 230) * math.sin(p.y * 210) * math.sin(p.z * 190);
            return sparkle > 0.82 ? c.accent : base;
          }
          return [
            ..._dress(c.primary, sleeve: 0.46, hem: -0.62, rHem: 0.3, paint: grad, gloss: 0.4),
          ];
        },
      ),
    ];
