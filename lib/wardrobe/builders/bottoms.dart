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

const _denims = [
  ColorVariant('Mid Wash', 0xFF5F7FB5, accent: 0xFFD9A74A),
  ColorVariant('Light Wash', 0xFF9DB7DE, accent: 0xFFD9A74A),
  ColorVariant('Dark Rinse', 0xFF34466F, accent: 0xFFD9A74A),
  ColorVariant('Lilac Denim', 0xFFB9A6E0, accent: 0xFFFFFFFF),
];

Set<String> _pantsHides(double length) =>
    {BodyTags.pelvis, ...Kit.legHides(length)};

List<Part> _pants(int color,
    {double length = 0.72,
    double grow = 0.008,
    double flare = 0,
    Painter? paint,
    double waistTop = 0.03,
    double cuff = 0}) {
  return [
    Kit.waist(color, top: waistTop, grow: math.min(grow - 0.002, 0.007), paint: paint),
    Kit.pelvis(color, grow: math.min(grow, 0.008), paint: paint),
    ...Kit.legs(color, length: length, grow: grow, flare: flare, paint: paint, cuff: cuff),
    _waistband(shadeArgb(color, 0.92), waistTop, 0.004),
  ];
}

Part _waistband(int color, double y, double grow) => Part(
    Bones.spine,
    Prim.torus(Body.profileRadius(Body.torsoProfile, y) + grow, 0.005,
            sz: Body.torsoDepth, segments: 26, sides: 6)
        .transformed(Affine.translation(Vec3(0, y - 0.008, 0))),
    color: color,
    bias: Layer.bottom + 0.002);

/// High-waisted, straight wide-leg cargo pants with side pockets on the
/// thighs, front pockets, fly, button and belt loops.
List<Part> _cargo(GarmentBuildContext c) {
  const grow = 0.016, flare = 0.03, waistTop = 0.05, length = 0.73;
  final twill = Kit.twill(c.primary);
  final seam = shadeArgb(c.primary, 0.88);
  final parts = <Part>[
    ..._pants(c.primary, length: length, grow: grow, flare: flare, paint: twill, waistTop: waistTop, cuff: 0.014),
  ];
  // Cargo pockets with flaps, riding on the thighs so they follow the legs.
  for (final l in [true, false]) {
    final s = l ? 1.0 : -1.0;
    const y = -0.24;
    final r = lerpDouble(Body.thighR0, Body.thighR1, -y / Body.thighLen) + grow + 0.004;
    parts.add(Part(
        Bones.side('thigh', l),
        Mesh.merge([
          Prim.roundedBox(0.016, 0.11, 0.072, e: 0.25, center: Vec3(s * r, y, 0.004)).solid(shadeArgb(c.primary, 0.97)),
          Prim.roundedBox(0.02, 0.026, 0.078, e: 0.3, center: Vec3(s * (r + 0.004), y + 0.05, 0.004)).solid(seam),
        ]),
        bias: Layer.bottom + 0.006));
  }
  // Front pockets, fly stitching and belt loops on the waist (spine space).
  final lines = <Mesh>[
    for (final s in [1.0, -1.0])
      Prim.tube(Kit.frontPath([[s * 0.045, waistTop - 0.004], [s * 0.065, 0.005], [s * 0.095, -0.035], [s * 0.112, -0.06]], offset: grow + 0.002),
          radius: 0.0025, sides: 4),
    Prim.tube(Kit.frontPath([[0.014, waistTop - 0.012], [0.014, -0.04], [0.0, -0.068]], offset: grow + 0.002), radius: 0.0022, sides: 4),
    for (final x in [-0.1, -0.055, 0.055, 0.1])
      Prim.roundedBox(0.009, 0.026, 0.006, e: 0.4, center: Body.torsoFront(x, waistTop - 0.012, offset: grow + 0.004)),
  ];
  parts.add(Part(Bones.spine, Mesh.merge(lines), color: seam, bias: Layer.bottom + 0.006, decal: true));
  parts.add(Kit.buttons(c.accent, 0, [waistTop - 0.013], offset: grow + 0.006, r: 0.007, bias: Layer.bottom + 0.01));
  return parts;
}

List<GarmentDefinition> buildBottoms() => [
      GarmentDefinition(
        id: 'bottom_skinny_jeans',
        name: 'Classic Jeans',
        subtype: 'Jeans',
        category: GarmentCategory.bottoms,
        slot: GarmentSlot.bottom,
        variants: _denims,
        hides: _pantsHides(0.72),
        build: (c) => [
          ..._pants(c.primary, paint: Kit.denim(c.primary)),
          Kit.buttons(c.accent, 0, [0.012], offset: 0.014, bias: Layer.bottom + 0.006),
        ],
      ),
      GarmentDefinition(
        id: 'bottom_flare_jeans',
        name: 'Flared Jeans',
        subtype: 'Jeans',
        category: GarmentCategory.bottoms,
        slot: GarmentSlot.bottom,
        variants: _denims,
        hides: _pantsHides(0.73),
        build: (c) => _pants(c.primary,
            length: 0.73, flare: 0.04, paint: Kit.denim(c.primary)),
      ),
      GarmentDefinition(
        id: 'bottom_wide_trousers',
        name: 'Wide-Leg Trousers',
        subtype: 'Trousers',
        category: GarmentCategory.bottoms,
        slot: GarmentSlot.bottom,
        variants: const [
          ColorVariant('Camel', 0xFFD2AE82),
          ColorVariant('Cream', 0xFFF1E8D8),
          ColorVariant('Black', 0xFF2E2B33),
          ColorVariant('Pink Check', 0xFFF7D6E0, secondary: 0xFFE58AA8),
        ],
        hides: _pantsHides(0.73),
        build: (c) => _pants(c.primary,
            length: 0.73,
            flare: 0.06,
            grow: 0.014,
            waistTop: 0.06,
            paint: c.variant.name == 'Pink Check'
                ? Kit.plaid(c.primary, c.secondary, c.secondary)
                : null),
      ),
      GarmentDefinition(
        id: 'bottom_cargo',
        name: 'Utility Cargo Pants',
        subtype: 'Cargo Pants',
        category: GarmentCategory.bottoms,
        slot: GarmentSlot.bottom,
        variants: const [
          ColorVariant('Khaki', 0xFFB9AD86, accent: 0xFFD9A74A),
          ColorVariant('Olive', 0xFF7A8358, accent: 0xFFD9A74A),
          ColorVariant('Stone', 0xFFCFCAC0, accent: 0xFFD9A74A),
          ColorVariant('Black', 0xFF2F2E33, accent: 0xFFD5D9E2),
          ColorVariant('Lavender', 0xFFC9B9E8, accent: 0xFFE3B35E),
        ],
        hides: _pantsHides(0.73),
        build: (c) => _cargo(c),
      ),
      GarmentDefinition(
        id: 'bottom_joggers',
        name: 'Cloud Joggers',
        subtype: 'Joggers',
        category: GarmentCategory.bottoms,
        slot: GarmentSlot.bottom,
        variants: const [
          ColorVariant('Heather Grey', 0xFFBEBBC4),
          ColorVariant('Baby Pink', 0xFFF6C1D2),
          ColorVariant('Sky', 0xFFB4D5F1),
          ColorVariant('Black', 0xFF34313A),
        ],
        hides: _pantsHides(0.7),
        build: (c) => [
          ..._pants(c.primary, length: 0.7, grow: 0.014, cuff: 0.014),
          Part(
              Bones.hips,
              Mesh.merge([
                for (final s in [1.0, -1.0])
                  Prim.roundedBox(0.007, 0.32, 0.012, e: 0.3)
                      .transformed(Affine.translation(Vec3(s * 0.124, -0.1, 0)))
              ]).solid(0xFFFFFFFF),
              bias: Layer.bottom + 0.004),
        ],
      ),
      GarmentDefinition(
        id: 'bottom_leggings',
        name: 'Soft Leggings',
        subtype: 'Leggings',
        category: GarmentCategory.bottoms,
        slot: GarmentSlot.bottom,
        variants: const [
          ColorVariant('Black', 0xFF2B2930),
          ColorVariant('Plum', 0xFF7D4E7A),
          ColorVariant('Navy', 0xFF2F3B66),
          ColorVariant('Galaxy', 0xFF4B3C7A, secondary: 0xFFB7A4F2),
        ],
        hides: _pantsHides(0.72),
        build: (c) => _pants(c.primary,
            grow: 0.004,
            paint: c.variant.name == 'Galaxy'
                ? Kit.dots(c.primary, c.secondary, freq: 140)
                : null),
      ),
      GarmentDefinition(
        id: 'bottom_denim_shorts',
        name: 'Denim Bermuda Shorts',
        subtype: 'Shorts',
        category: GarmentCategory.bottoms,
        slot: GarmentSlot.bottom,
        variants: _denims,
        hides: {BodyTags.pelvis},
        build: (c) => _pants(c.primary,
            length: 0.2, flare: 0.012, cuff: 0.01, paint: Kit.denim(c.primary)),
      ),
      GarmentDefinition(
        id: 'bottom_pleated_skirt',
        name: 'Plaid Pleated Skirt',
        subtype: 'Skirt',
        category: GarmentCategory.bottoms,
        slot: GarmentSlot.bottom,
        variants: const [
          ColorVariant('Tartan Red', 0xFFC0394E, secondary: 0xFF2E2E4A, accent: 0xFFF2D06B),
          ColorVariant('Pastel Plaid', 0xFFF4C2D4, secondary: 0xFFFFFFFF, accent: 0xFFB59FE6),
          ColorVariant('Navy Plaid', 0xFF2E3A6B, secondary: 0xFFFFFFFF, accent: 0xFF6FA8DC),
        ],
        hides: {BodyTags.pelvis},
        build: (c) {
          final p = Kit.plaid(c.primary, c.secondary, c.accent);
          return [
            Kit.waist(c.primary, top: 0.03, paint: p),
            Kit.pelvis(shadeArgb(c.primary, 0.7), grow: 0.006),
            Kit.skirt(c.primary, hem: -0.29, rHem: 0.19, pleats: 0.06, paint: p),
            _waistband(shadeArgb(c.primary, 0.85), 0.03, 0.004),
          ];
        },
      ),
      GarmentDefinition(
        id: 'bottom_aline_skirt',
        name: 'A-Line Skirt',
        subtype: 'Skirt',
        category: GarmentCategory.bottoms,
        slot: GarmentSlot.bottom,
        variants: const [
          ColorVariant('Denim', 0xFF6E8FC2, accent: 0xFFD9A74A),
          ColorVariant('Corduroy Rust', 0xFFC0754E, accent: 0xFFF3D9A0),
          ColorVariant('Butter', 0xFFFFE7A3, accent: 0xFFFFFFFF),
        ],
        hides: {BodyTags.pelvis},
        build: (c) => [
          Kit.waist(c.primary, top: 0.04),
          Kit.pelvis(shadeArgb(c.primary, 0.7), grow: 0.006),
          Kit.skirt(c.primary, hem: -0.31, rHem: 0.175, paint: Kit.denim(c.primary)),
          Kit.buttons(c.accent, 0, [0.0, -0.06, -0.12, -0.18], offset: 0.03,
              bias: Layer.bottom + 0.008),
          _waistband(shadeArgb(c.primary, 0.9), 0.04, 0.004),
        ],
      ),
      GarmentDefinition(
        id: 'bottom_tiered_midi',
        name: 'Tiered Midi Skirt',
        subtype: 'Skirt',
        category: GarmentCategory.bottoms,
        slot: GarmentSlot.bottom,
        variants: const [
          ColorVariant('Lavender', 0xFFD6C4F5),
          ColorVariant('Sage', 0xFFC0D9B8),
          ColorVariant('Floral', 0xFFFFF1F4, secondary: 0xFFF29BB6, accent: 0xFFF7D35C),
        ],
        hides: {BodyTags.pelvis, ...BodyTags.thighs},
        build: (c) {
          final paint = c.variant.name == 'Floral'
              ? Kit.floral(c.primary, c.secondary, c.accent)
              : null;
          return [
            Kit.waist(c.primary, top: 0.04, paint: paint),
            Kit.pelvis(shadeArgb(c.primary, 0.75), grow: 0.006),
            Kit.skirt(c.primary, hem: -0.2, rHem: 0.17, paint: paint),
            Kit.skirt(c.primary, top: -0.17, hem: -0.36, rTop: 0.165, rHem: 0.22,
                bias: Layer.bottom + 0.002, paint: paint),
            Kit.skirt(c.primary, top: -0.33, hem: -0.52, rTop: 0.215, rHem: 0.27,
                bias: Layer.bottom + 0.004, paint: paint),
          ];
        },
      ),
    ];
