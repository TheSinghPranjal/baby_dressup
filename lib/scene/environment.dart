import 'dart:math' as math;

import '../engine/math3d.dart';
import '../engine/mesh.dart';
import '../engine/primitives.dart';
import '../engine/renderer.dart';

/// A 3D dressing-room backdrop. Props live in world space around the
/// turntable at the origin; the character is always drawn on top of them.
class BackgroundTheme {
  final String id;
  final String name;
  final String emoji;
  final int skyTop, skyBottom;
  final int floor;
  final int pedestal;
  final List<RenderItem> Function() _build;

  BackgroundTheme({
    required this.id,
    required this.name,
    required this.emoji,
    required this.skyTop,
    required this.skyBottom,
    required this.floor,
    required this.pedestal,
    required List<RenderItem> Function() build,
  }) : _build = build;

  late final List<RenderItem> props = [..._base(), ..._build()];

  List<RenderItem> _base() => [
        RenderItem(
            Prim.lathe(const [P2(6, -0.06), P2(0, -0.06)], segments: 40)
                .transformed(Affine.scale(const Vec3(1, 1, 1))),
            Affine.identity,
            color: floor,
            gloss: 0.05),
        RenderItem(
            Prim.lathe(const [P2(0, -0.05), P2(0.5, -0.05), P2(0.52, -0.02), P2(0.5, 0.0), P2(0, 0.0)],
                segments: 40),
            Affine.identity,
            color: pedestal,
            gloss: 0.4),
        RenderItem(Prim.torus(0.5, 0.012, segments: 48, sides: 5), Affine.translation(const Vec3(0, 0.0, 0)),
            color: 0xFFFFFFFF, gloss: 0.8),
      ];
}

RenderItem _item(Mesh m, int color, {Affine? at, double gloss = 0.1}) =>
    RenderItem(m, at ?? Affine.identity, color: color, gloss: gloss);

/// Curved backdrop wall (we see its inner face).
RenderItem _backdrop(int color, {double r = 3.2, double h = 3.6}) => _item(
    Prim.lathe([P2(r, -0.06), P2(r, h)], segments: 36, a0: math.pi * 0.62, a1: math.pi * 1.38)
        .doubleSided(innerShade: 1.0),
    color);

List<RenderItem> _rack(Vec3 at, List<int> colors, {double rot = 0}) {
  final place = Affine.translation(at) * Affine.rotY(rot);
  final items = <RenderItem>[
    _item(Prim.rod(const Vec3(-0.45, 1.35, 0), const Vec3(0.45, 1.35, 0), 0.015), 0xFFE9C46A, at: place, gloss: 0.8),
    for (final x in [-0.45, 0.45])
      _item(Prim.rod(Vec3(x, -0.05, 0), Vec3(x, 1.38, 0), 0.016), 0xFFE9C46A, at: place, gloss: 0.8),
  ];
  for (var k = 0; k < colors.length; k++) {
    final x = -0.36 + 0.72 * k / math.max(1, colors.length - 1);
    final long = k.isEven;
    items.add(_item(
        Mesh.merge([
          Prim.torus(0.02, 0.004, segments: 10, sides: 4, a0: -2.5, a1: 2.5)
              .transformed(Affine.translation(const Vec3(0, 1.36, 0)) * Affine.rotX(math.pi / 2) * Affine.rotY(math.pi / 2)),
          Prim.roundedBox(0.04, long ? 0.62 : 0.42, 0.24, e: 0.3, center: Vec3(0, long ? 1.0 : 1.1, 0)),
        ]),
        colors[k],
        at: place * Affine.translation(Vec3(x, 0, 0))));
  }
  return items;
}

List<RenderItem> _shelf(Vec3 at, int wood, List<int> colors, {double rot = 0}) {
  final place = Affine.translation(at) * Affine.rotY(rot);
  final items = <RenderItem>[
    _item(Prim.roundedBox(0.75, 1.6, 0.32, e: 0.12, center: const Vec3(0, 0.75, -0.02)), shadeArgb(wood, 0.85), at: place),
  ];
  for (var row = 0; row < 3; row++) {
    final y = 0.18 + row * 0.5;
    items.add(_item(Prim.roundedBox(0.7, 0.03, 0.3, e: 0.2, center: Vec3(0, y, 0.02)), wood, at: place));
    for (var k = 0; k < 3; k++) {
      final c = colors[(row * 3 + k) % colors.length];
      final x = -0.22 + k * 0.22;
      final m = row == 1
          ? Prim.roundedBox(0.15, 0.13, 0.08, e: 0.35, center: Vec3(x, y + 0.08, 0.04))
          : Mesh.merge([
              Prim.ellipsoid(0.04, 0.035, 0.085, center: Vec3(x - 0.03, y + 0.04, 0.05), segments: 10),
              Prim.ellipsoid(0.04, 0.035, 0.085, center: Vec3(x + 0.03, y + 0.04, 0.05), segments: 10),
            ]);
      items.add(_item(m, c, at: place, gloss: 0.3));
    }
  }
  return items;
}

List<RenderItem> _plant(Vec3 at, {double scale = 1}) => [
      _item(Prim.lathe(const [P2(0, 0), P2(0.12, 0.0), P2(0.15, 0.26), P2(0.13, 0.27)], segments: 18)
          .transformed(Affine.translation(at) * Affine.scale(Vec3.one * scale)), 0xFFF2EDE6),
      for (var k = 0; k < 7; k++)
        _item(
            Prim.ellipsoid(0.06, 0.2, 0.025, center: const Vec3(0, 0.2, 0), segments: 8)
                .transformed(Affine.translation(at + Vec3(0, 0.25 * scale, 0)) *
                    Affine.scale(Vec3.one * scale) *
                    Affine.rotY(k * 0.9) *
                    Affine.rotZ(0.35 + (k % 3) * 0.15)),
            0xFF7DBE8C),
    ];

RenderItem _mirror(Vec3 at, int frame) => _item(
    Mesh.merge([
      Prim.torus(0.42, 0.04, segments: 40, sides: 6, sx: 0.7)
          .transformed(Affine.rotX(math.pi / 2) * Affine.scale(const Vec3(1, 1, 1.8)))
          .solid(frame),
      Prim.disc(0.29, 0.75, dome: 0.02, segments: 30, center: const Vec3(0, 0, -0.01)).painted(
          (p, _) => mixArgb(0xFFDDEAF7, 0xFFFFFFFF, ((p.x + p.y) * 2 + 0.5).clamp(0, 1) * 0.6)),
    ]).transformed(Affine.translation(at) * Affine.rotY(0.45)),
    0xFFFFFFFF,
    gloss: 0.9);

List<RenderItem> _tree(Vec3 at, double s, int leaf) => [
      _item(Prim.capsule(0.9 * s, 0.07 * s, 0.09 * s).transformed(Affine.translation(at + Vec3(0, 0.9 * s, 0))), 0xFF9C6B4A),
      _item(Prim.sphere(0.45 * s, center: at + Vec3(0, 1.15 * s, 0), segments: 16), leaf),
      _item(Prim.sphere(0.32 * s, center: at + Vec3(0.3 * s, 0.95 * s, 0.1 * s), segments: 12), shadeArgb(leaf, 1.08)),
      _item(Prim.sphere(0.3 * s, center: at + Vec3(-0.3 * s, 1.0 * s, 0.05 * s), segments: 12), shadeArgb(leaf, 0.94)),
    ];

final List<BackgroundTheme> kBackgrounds = [
  BackgroundTheme(
    id: 'pastel_studio',
    name: 'Pastel Studio',
    emoji: '🎀',
    skyTop: 0xFFFBE4EE,
    skyBottom: 0xFFF3E6FB,
    floor: 0xFFF6E9EE,
    pedestal: 0xFFF7C6D9,
    build: () => [
      _backdrop(0xFFFBE7F0),
      _mirror(const Vec3(-1.15, 1.05, -1.3), 0xFFE9C46A),
      ..._rack(const Vec3(1.25, 0, -1.35), [0xFFF7B6C8, 0xFFC9B6F2, 0xFFAEE6CF, 0xFFFFE7A3, 0xFFA8D4F5, 0xFFF29BB6], rot: -0.4),
      ..._plant(const Vec3(-0.85, -0.05, -0.55), scale: 0.9),
    ],
  ),
  BackgroundTheme(
    id: 'bedroom_closet',
    name: 'Bedroom Closet',
    emoji: '🛏️',
    skyTop: 0xFFEDE3FA,
    skyBottom: 0xFFFFF1E6,
    floor: 0xFFE8D2BE,
    pedestal: 0xFFC9B6F2,
    build: () => [
      _backdrop(0xFFEFE4FA),
      _item(Prim.lathe(const [P2(1.1, -0.055), P2(0, -0.055)], segments: 40)
          .transformed(Affine.scale(const Vec3(1.3, 1, 0.8))), 0xFFF7C6D9),
      ..._shelf(const Vec3(-1.3, -0.05, -1.25), 0xFFF3E9DC,
          [0xFFF48FB1, 0xFFFFFFFF, 0xFF9ACBF0, 0xFFE9C46A, 0xFFC9B6F2, 0xFF2E2C33, 0xFFAEE6CF, 0xFFF7B6C8, 0xFFD8435E],
          rot: 0.45),
      ..._rack(const Vec3(1.3, 0, -1.25), [0xFF6E8FC2, 0xFFF1E8D8, 0xFFC7364F, 0xFF9DBFA6, 0xFFF4C2CF], rot: -0.45),
      _item(Prim.capsule(1.1, 0.012, 0.012).transformed(Affine.translation(const Vec3(0.55, 2.1, -1.8))), 0xFFE9C46A),
      _item(Prim.lathe(const [P2(0.0, -0.12), P2(0.13, -0.1), P2(0.09, 0.02), P2(0, 0.03)], segments: 16)
          .transformed(Affine.translation(const Vec3(0.55, 1.0, -1.8))), 0xFFFFF4C2, gloss: 0.6),
    ],
  ),
  BackgroundTheme(
    id: 'city_studio',
    name: 'City Studio',
    emoji: '🌆',
    skyTop: 0xFF2B2C5E,
    skyBottom: 0xFFE98FB0,
    floor: 0xFF3B3552,
    pedestal: 0xFFE8D2F7,
    build: () {
      final rng = math.Random(4);
      final items = <RenderItem>[];
      for (var k = 0; k < 16; k++) {
        final a = math.pi * (0.68 + 0.64 * k / 15);
        final h = 0.9 + rng.nextDouble() * 1.6;
        final w = 0.35 + rng.nextDouble() * 0.3;
        final x = 4.2 * math.sin(a), z = 4.2 * math.cos(a);
        final col = [0xFF4B3F7A, 0xFF5E4C8F, 0xFF3D3468, 0xFF6C5AA0][k % 4];
        items.add(_item(
            Prim.roundedBox(w, h, 0.4, e: 0.08, center: Vec3(0, h / 2, 0)).painted((p, _) {
              final win = math.sin(p.y * 60) > 0.3 && math.sin(p.x * 50 + k.toDouble()) > 0.2;
              return win && rng.nextDouble() > 0.3 ? 0xFFFFE6A8 : col;
            }),
            0xFFFFFFFF,
            at: Affine.translation(Vec3(x, -0.06, z)) * Affine.rotY(a)));
      }
      for (final s in [1.0, -1.0]) {
        items.add(_item(Prim.rod(Vec3(s * 1.3, -0.05, -0.9), Vec3(s * 1.3, 1.9, -0.9), 0.02), 0xFF2B2830, gloss: 0.6));
        items.add(_item(
            Prim.lathe(const [P2(0.0, -0.1), P2(0.09, -0.1), P2(0.12, 0.08), P2(0.0, 0.1)], segments: 14)
                .transformed(Affine.translation(Vec3(s * 1.3, 1.95, -0.9)) * Affine.rotX(0.7) * Affine.rotZ(-s * 0.6)),
            0xFF2B2830,
            gloss: 0.8));
      }
      items.add(_item(
          Prim.roundedBox(0.7, 0.01, 4, e: 0.1, center: const Vec3(0, -0.055, -2)), 0xFFF7C6D9, gloss: 0.5));
      return items;
    },
  ),
  BackgroundTheme(
    id: 'garden',
    name: 'Garden Party',
    emoji: '🌷',
    skyTop: 0xFFA8D8F5,
    skyBottom: 0xFFFFEFF4,
    floor: 0xFF9ED38E,
    pedestal: 0xFFFFFFFF,
    build: () {
      final rng = math.Random(9);
      final items = <RenderItem>[
        ..._tree(const Vec3(-1.6, -0.06, -2.0), 1.1, 0xFF6DB57A),
        ..._tree(const Vec3(1.7, -0.06, -2.3), 1.3, 0xFF7CC48A),
        ..._tree(const Vec3(0.4, -0.06, -3.4), 1.0, 0xFF5FA86E),
      ];
      // Rose arch behind the pedestal.
      items.add(_item(
          Prim.torus(0.95, 0.05, segments: 40, sides: 6, a0: math.pi / 2, a1: math.pi * 1.5)
              .transformed(Affine.translation(const Vec3(0, 0.9, -1.2)) * Affine.rotX(math.pi / 2) * Affine.rotY(math.pi)),
          0xFFFFFFFF));
      for (final s in [1.0, -1.0]) {
        items.add(_item(Prim.rod(Vec3(s * 0.95, -0.05, -1.2), Vec3(s * 0.95, 0.9, -1.2), 0.05), 0xFFFFFFFF));
      }
      for (var k = 0; k < 14; k++) {
        final a = math.pi * (k / 13);
        items.add(_item(Prim.sphere(0.07, center: Vec3(0.95 * math.cos(a), 0.9 + 0.95 * math.sin(a), -1.15), segments: 8),
            k.isEven ? 0xFFF48FB1 : 0xFFFFFFFF));
      }
      for (var k = 0; k < 40; k++) {
        final a = rng.nextDouble() * math.pi * 2;
        final r = 0.75 + rng.nextDouble() * 2.2;
        final pos = Vec3(r * math.sin(a), -0.03, r * math.cos(a) - 0.4);
        if (pos.z > 0.6) continue;
        final col = [0xFFF48FB1, 0xFFFFE680, 0xFFC4A8F0, 0xFFFFFFFF, 0xFFFF9F7A][k % 5];
        items.add(_item(
            Mesh.merge([
              Prim.rod(pos, pos + const Vec3(0, 0.12, 0), 0.006, sides: 4).solid(0xFF5FA86E),
              Prim.sphere(0.035, center: pos + const Vec3(0, 0.14, 0), segments: 8).solid(col),
            ]),
            0xFFFFFFFF));
      }
      return items;
    },
  ),
];

BackgroundTheme backgroundById(String id) =>
    kBackgrounds.firstWhere((b) => b.id == id, orElse: () => kBackgrounds.first);
