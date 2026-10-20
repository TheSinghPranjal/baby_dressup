import 'dart:math' as math;
import 'dart:typed_data';

import 'math3d.dart';

/// An indexed triangle mesh in a bone's local space.
///
/// Triangles are wound counter-clockwise when seen from outside, which the
/// renderer relies on for back-face culling. Optional per-vertex colors (ARGB)
/// override the material colour so builders can paint stripes, prints, etc.
class Mesh {
  final Float32List positions;
  final Float32List normals;
  final Uint32List indices;
  final Int32List? colors;

  /// Optional UV coordinates, two floats per vertex. V = 0 is the top of the
  /// texture, matching Flutter's [ImageShader] (glTF's bottom-left origin is
  /// flipped when a model is loaded).
  final Float32List? uvs;

  Mesh(this.positions, this.normals, this.indices, [this.colors, this.uvs]);

  late final Vec3 center = () {
    final b = bounds();
    return (b[0] + b[1]) * 0.5;
  }();

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;

  Vec3 vertex(int i) =>
      Vec3(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]);

  /// Builds a mesh from raw vertex/index lists and computes smooth normals.
  factory Mesh.fromLists(
    List<Vec3> verts,
    List<int> tris, {
    List<int>? colors,
  }) {
    final pos = Float32List(verts.length * 3);
    for (var i = 0; i < verts.length; i++) {
      pos[i * 3] = verts[i].x;
      pos[i * 3 + 1] = verts[i].y;
      pos[i * 3 + 2] = verts[i].z;
    }
    final idx = Uint32List.fromList(tris);
    return Mesh(
      pos,
      computeNormals(pos, idx),
      idx,
      colors == null ? null : Int32List.fromList(colors),
    );
  }

  /// Smooth normals from triangle faces. Shared by the procedural builders
  /// and the glTF loader.
  static Float32List computeNormals(Float32List pos, Uint32List idx) {
    final n = Float32List(pos.length);
    for (var t = 0; t < idx.length; t += 3) {
      final i0 = idx[t] * 3, i1 = idx[t + 1] * 3, i2 = idx[t + 2] * 3;
      final ax = pos[i1] - pos[i0], ay = pos[i1 + 1] - pos[i0 + 1];
      final az = pos[i1 + 2] - pos[i0 + 2];
      final bx = pos[i2] - pos[i0], by = pos[i2 + 1] - pos[i0 + 1];
      final bz = pos[i2 + 2] - pos[i0 + 2];
      final nx = ay * bz - az * by, ny = az * bx - ax * bz;
      final nz = ax * by - ay * bx;
      for (final i in [i0, i1, i2]) {
        n[i] += nx;
        n[i + 1] += ny;
        n[i + 2] += nz;
      }
    }
    for (var i = 0; i < n.length; i += 3) {
      final l = math.sqrt(
        n[i] * n[i] + n[i + 1] * n[i + 1] + n[i + 2] * n[i + 2],
      );
      if (l > 1e-12) {
        n[i] /= l;
        n[i + 1] /= l;
        n[i + 2] /= l;
      } else {
        n[i + 1] = 1;
      }
    }
    return n;
  }

  /// Returns a copy with positions transformed and normals recomputed.
  Mesh transformed(Affine m) {
    final pos = Float32List(positions.length);
    for (var i = 0; i < positions.length; i += 3) {
      final p = m.point(Vec3(positions[i], positions[i + 1], positions[i + 2]));
      pos[i] = p.x;
      pos[i + 1] = p.y;
      pos[i + 2] = p.z;
    }
    // A mirroring transform flips winding; restore outward orientation.
    final det =
        m.a * (m.e * m.i - m.f * m.h) -
        m.b * (m.d * m.i - m.f * m.g) +
        m.c * (m.d * m.h - m.e * m.g);
    final idx = Uint32List.fromList(indices);
    if (det < 0) {
      for (var t = 0; t < idx.length; t += 3) {
        final tmp = idx[t + 1];
        idx[t + 1] = idx[t + 2];
        idx[t + 2] = tmp;
      }
    }
    return Mesh(pos, computeNormals(pos, idx), idx, colors, uvs);
  }

  /// Adds back faces (reversed winding, flipped normals) so open surfaces such
  /// as skirts, sleeves and hat brims can be seen from inside.
  Mesh doubleSided({double innerShade = 0.78}) {
    final vc = vertexCount;
    final pos = Float32List(positions.length * 2)
      ..setRange(0, positions.length, positions)
      ..setRange(positions.length, positions.length * 2, positions);
    final nrm = Float32List(normals.length * 2)
      ..setRange(0, normals.length, normals);
    for (var i = 0; i < normals.length; i++) {
      nrm[normals.length + i] = -normals[i];
    }
    final idx = Uint32List(indices.length * 2)
      ..setRange(0, indices.length, indices);
    for (var t = 0; t < indices.length; t += 3) {
      idx[indices.length + t] = indices[t] + vc;
      idx[indices.length + t + 1] = indices[t + 2] + vc;
      idx[indices.length + t + 2] = indices[t + 1] + vc;
    }
    Int32List? cols;
    if (colors != null) {
      cols = Int32List(vc * 2)..setRange(0, vc, colors!);
      for (var i = 0; i < vc; i++) {
        cols[vc + i] = shadeArgb(colors![i], innerShade);
      }
    }
    Float32List? uv2;
    if (uvs != null) {
      uv2 = Float32List(uvs!.length * 2)
        ..setRange(0, uvs!.length, uvs!)
        ..setRange(uvs!.length, uvs!.length * 2, uvs!);
    }
    return Mesh(pos, nrm, idx, cols, uv2);
  }

  /// Paints per-vertex colours using [fn] (local position, normal) -> ARGB.
  Mesh painted(int Function(Vec3 p, Vec3 n) fn) {
    final cols = Int32List(vertexCount);
    for (var i = 0; i < vertexCount; i++) {
      cols[i] = fn(
        vertex(i),
        Vec3(normals[i * 3], normals[i * 3 + 1], normals[i * 3 + 2]),
      );
    }
    return Mesh(positions, normals, indices, cols, uvs);
  }

  /// Uniformly colours the mesh (useful before merging differently coloured
  /// pieces into one part).
  Mesh solid(int argb) => painted((_, _) => argb);

  static Mesh merge(List<Mesh> meshes) {
    final anyColors = meshes.any((m) => m.colors != null);
    var vTotal = 0, iTotal = 0;
    for (final m in meshes) {
      vTotal += m.vertexCount;
      iTotal += m.indices.length;
    }
    final pos = Float32List(vTotal * 3);
    final nrm = Float32List(vTotal * 3);
    final idx = Uint32List(iTotal);
    final cols = anyColors ? Int32List(vTotal) : null;
    final anyUv = meshes.any((m) => m.uvs != null);
    final uvs = anyUv ? Float32List(vTotal * 2) : null;
    var vo = 0, io = 0;
    for (final m in meshes) {
      pos.setRange(vo * 3, vo * 3 + m.positions.length, m.positions);
      nrm.setRange(vo * 3, vo * 3 + m.normals.length, m.normals);
      for (var k = 0; k < m.indices.length; k++) {
        idx[io + k] = m.indices[k] + vo;
      }
      if (cols != null) {
        for (var k = 0; k < m.vertexCount; k++) {
          cols[vo + k] = m.colors?[k] ?? 0xFFFFFFFF;
        }
      }
      if (uvs != null) {
        final src = m.uvs;
        if (src != null) {
          uvs.setRange(vo * 2, vo * 2 + src.length, src);
        }
      }
      vo += m.vertexCount;
      io += m.indices.length;
    }
    return Mesh(pos, nrm, idx, cols, uvs);
  }

  /// Axis-aligned bounds as [min, max].
  List<Vec3> bounds() {
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity,
        maxY = -double.infinity,
        maxZ = -double.infinity;
    for (var i = 0; i < positions.length; i += 3) {
      minX = math.min(minX, positions[i]);
      maxX = math.max(maxX, positions[i]);
      minY = math.min(minY, positions[i + 1]);
      maxY = math.max(maxY, positions[i + 1]);
      minZ = math.min(minZ, positions[i + 2]);
      maxZ = math.max(maxZ, positions[i + 2]);
    }
    return [Vec3(minX, minY, minZ), Vec3(maxX, maxY, maxZ)];
  }
}

int shadeArgb(int argb, double k) {
  final a = (argb >> 24) & 0xFF;
  final r = (((argb >> 16) & 0xFF) * k).round().clamp(0, 255);
  final g = (((argb >> 8) & 0xFF) * k).round().clamp(0, 255);
  final b = ((argb & 0xFF) * k).round().clamp(0, 255);
  return (a << 24) | (r << 16) | (g << 8) | b;
}

int mixArgb(int c1, int c2, double t) {
  int ch(int s) {
    final a = (c1 >> s) & 0xFF, b = (c2 >> s) & 0xFF;
    return (a + (b - a) * t).round().clamp(0, 255);
  }

  return (0xFF << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}
