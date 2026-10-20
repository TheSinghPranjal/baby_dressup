import 'package:baby_dressup/engine/math3d.dart';
import 'package:baby_dressup/engine/mesh.dart';
import 'package:baby_dressup/engine/primitives.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fraction of vertices whose normal points away from [center].
double outwardRatio(Mesh m, Vec3 center) {
  var ok = 0;
  for (var i = 0; i < m.vertexCount; i++) {
    final p = m.vertex(i);
    final n = Vec3(m.normals[i * 3], m.normals[i * 3 + 1], m.normals[i * 3 + 2]);
    if (n.dot(p - center) > 0) ok++;
  }
  return ok / m.vertexCount;
}

void main() {
  test('closed primitives have outward normals', () {
    expect(outwardRatio(Prim.sphere(1), Vec3.zero), greaterThan(0.95));
    expect(outwardRatio(Prim.ellipsoid(1, 2, 0.5), Vec3.zero), greaterThan(0.95));
    expect(outwardRatio(Prim.roundedBox(1, 1, 1), Vec3.zero), greaterThan(0.95));
    expect(outwardRatio(Prim.capsule(1, 0.2, 0.1), const Vec3(0, -0.5, 0)),
        greaterThan(0.9));
    expect(
        outwardRatio(
            Prim.lathe([const P2(0, 0), const P2(1, 0.5), const P2(0, 1)]),
            const Vec3(0, 0.5, 0)),
        greaterThan(0.9));
  });

  test('tube normals point away from its path', () {
    final m = Prim.tube([for (var k = 0; k <= 20; k++) Vec3(0, k / 20, 0)], radius: 0.1);
    var ok = 0;
    for (var i = 0; i < m.vertexCount; i++) {
      final p = m.vertex(i);
      final n = Vec3(m.normals[i * 3], m.normals[i * 3 + 1], m.normals[i * 3 + 2]);
      if (n.dot(Vec3(p.x, 0, p.z)) > 0) ok++;
    }
    expect(ok / m.vertexCount, greaterThan(0.8));
  });

  test('torus normals point away from its core ring', () {
    final m = Prim.torus(1, 0.2);
    var ok = 0;
    for (var i = 0; i < m.vertexCount; i++) {
      final p = m.vertex(i);
      final n = Vec3(m.normals[i * 3], m.normals[i * 3 + 1], m.normals[i * 3 + 2]);
      final core = Vec3(p.x, 0, p.z).normalized();
      if (n.dot(p - core) > 0) ok++;
    }
    expect(ok / m.vertexCount, greaterThan(0.9));
  });

  test('mirroring transform keeps normals outward', () {
    final m = Prim.sphere(1).transformed(Affine.scale(const Vec3(-1, 1, 1)));
    expect(outwardRatio(m, Vec3.zero), greaterThan(0.95));
  });

  test('alignDown maps -Y onto the requested direction', () {
    const d = Vec3(1, 2, -0.5);
    final r = Affine.alignDown(d).dir(const Vec3(0, -1, 0));
    expect((r - d.normalized()).length, lessThan(1e-9));
  });
}
