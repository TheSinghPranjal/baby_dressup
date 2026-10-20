import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'math3d.dart';
import 'mesh.dart';

/// One mesh instance placed in the world.
class RenderItem {
  final Mesh mesh;
  final Affine transform;
  final int color;

  /// 0 = matte, 1 = very shiny (hair, patent leather, sunglasses).
  final double gloss;

  /// View-space depth bias towards the camera. Layered garments use this so a
  /// garment always wins the depth sort against the body directly beneath it.
  final double depthBias;

  /// Sort every triangle at the depth of the mesh centre (decals such as
  /// eyes, brows and buttons) so stacked layers never interleave.
  final bool decal;

  const RenderItem(this.mesh, this.transform,
      {this.color = 0xFFFFFFFF,
      this.gloss = 0.1,
      this.depthBias = 0,
      this.decal = false});
}

/// Orbit camera looking at a target on the Y axis.
class OrbitCamera {
  double pitch; // radians, positive looks down on the subject
  double distance;
  double targetY;
  double targetX;
  double fovY;
  double screenOffsetY; // pixels; shifts the target on screen

  OrbitCamera(
      {this.pitch = 0.08,
      this.distance = 3.2,
      this.targetY = 0.82,
      this.targetX = 0,
      this.fovY = 0.62,
      this.screenOffsetY = 0});

  Affine get view =>
      Affine.translation(Vec3(0, 0, -distance)) *
      Affine.rotX(pitch) *
      Affine.translation(Vec3(-targetX, -targetY, 0));

  OrbitCamera copy() => OrbitCamera(
      pitch: pitch,
      distance: distance,
      targetY: targetY,
      targetX: targetX,
      fovY: fovY,
      screenOffsetY: screenOffsetY);

  /// Projects a world-space point to screen coordinates.
  ui.Offset project(Vec3 world, ui.Size size) {
    final v = view.point(world);
    final f = size.height / (2 * math.tan(fovY / 2));
    final iz = 1 / math.max(0.05, -v.z);
    return ui.Offset(size.width / 2 + f * v.x * iz,
        size.height / 2 + screenOffsetY - f * v.y * iz);
  }
}

/// Studio lighting expressed in view space so the subject is always lit
/// nicely from the front, whichever way the turntable has rotated it.
class Lighting {
  final Vec3 key;
  final Vec3 fill;
  final double keyStrength, fillStrength;
  final int skyAmbient, groundAmbient;
  final int rimColor;
  final double rimStrength;

  const Lighting({
    this.key = const Vec3(-0.45, 0.62, 0.64),
    this.fill = const Vec3(0.7, 0.05, 0.45),
    this.keyStrength = 0.72,
    this.fillStrength = 0.22,
    this.skyAmbient = 0xFFB9B4D8,
    this.groundAmbient = 0xFF9C8A8E,
    this.rimColor = 0xFFFFE6F2,
    this.rimStrength = 0.35,
  });

  static const studio = Lighting();
}

/// A small CPU rasterisation front-end: transforms, lights (Gouraud), culls
/// back faces, depth-sorts triangles (painter's algorithm with bucket sort)
/// and submits everything to Skia/Impeller as one `drawVertices` call.
class SoftRenderer {
  Float32List _vx = Float32List(0), _vy = Float32List(0), _vz = Float32List(0);
  Int32List _vc = Int32List(0);
  Float64List _triDepth = Float64List(0);
  Int32List _triV = Int32List(0); // 3 global vertex indices per triangle
  Int32List _order = Int32List(0);
  final Int32List _bucket = Int32List(_buckets + 1);
  static const _buckets = 8192;

  int lastTriangleCount = 0;

  void render(ui.Canvas canvas, ui.Size size, OrbitCamera camera,
      List<RenderItem> items,
      {Lighting light = Lighting.studio}) {
    var vTotal = 0, tTotal = 0;
    for (final it in items) {
      vTotal += it.mesh.vertexCount;
      tTotal += it.mesh.triangleCount;
    }
    if (_vx.length < vTotal) {
      _vx = Float32List(vTotal);
      _vy = Float32List(vTotal);
      _vz = Float32List(vTotal);
      _vc = Int32List(vTotal);
    }
    if (_triDepth.length < tTotal) {
      _triDepth = Float64List(tTotal);
      _triV = Int32List(tTotal * 3);
      _order = Int32List(tTotal);
    }

    final f = size.height / (2 * math.tan(camera.fovY / 2));
    final cx = size.width / 2, cy = size.height / 2 + camera.screenOffsetY;
    final view = camera.view;

    final key = light.key.normalized(), fill = light.fill.normalized();
    final hx = key.x, hy = key.y, hz = key.z + 1; // Blinn half vector
    final hl = math.sqrt(hx * hx + hy * hy + hz * hz);
    final sky = light.skyAmbient, ground = light.groundAmbient;
    final skyR = ((sky >> 16) & 255) / 255, skyG = ((sky >> 8) & 255) / 255;
    final skyB = (sky & 255) / 255;
    final grR = ((ground >> 16) & 255) / 255, grG = ((ground >> 8) & 255) / 255;
    final grB = (ground & 255) / 255;
    final rimR = ((light.rimColor >> 16) & 255) * light.rimStrength;
    final rimG = ((light.rimColor >> 8) & 255) * light.rimStrength;
    final rimB = (light.rimColor & 255) * light.rimStrength;

    var vBase = 0, tCount = 0;
    var minD = double.infinity, maxD = -double.infinity;
    for (final it in items) {
      final m = view * it.transform;
      final mesh = it.mesh;
      final pos = mesh.positions, nrm = mesh.normals, cols = mesh.colors;
      final gloss = it.gloss;
      final n = mesh.vertexCount;
      for (var i = 0; i < n; i++) {
        final px = pos[i * 3], py = pos[i * 3 + 1], pz = pos[i * 3 + 2];
        final x = m.a * px + m.b * py + m.c * pz + m.tx;
        final y = m.d * px + m.e * py + m.f * pz + m.ty;
        final z = m.g * px + m.h * py + m.i * pz + m.tz;
        final iz = 1 / math.max(0.01, -z);
        final gi = vBase + i;
        _vx[gi] = cx + f * x * iz;
        _vy[gi] = cy - f * y * iz;
        _vz[gi] = z;

        final ax = nrm[i * 3], ay = nrm[i * 3 + 1], az = nrm[i * 3 + 2];
        var nx = m.a * ax + m.b * ay + m.c * az;
        var ny = m.d * ax + m.e * ay + m.f * az;
        var nz = m.g * ax + m.h * ay + m.i * az;
        final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
        if (nl > 1e-9) {
          nx /= nl;
          ny /= nl;
          nz /= nl;
        }
        final albedo = cols != null ? _mulArgb(cols[i], it.color) : it.color;
        final ar = ((albedo >> 16) & 255).toDouble();
        final ag = ((albedo >> 8) & 255).toDouble();
        final ab = (albedo & 255).toDouble();

        final kd = ((nx * key.x + ny * key.y + nz * key.z) + 0.35) / 1.35;
        final fd = ((nx * fill.x + ny * fill.y + nz * fill.z) + 0.2) / 1.2;
        final diff = light.keyStrength * (kd < 0 ? 0 : kd) +
            light.fillStrength * (fd < 0 ? 0 : fd);
        final hemi = 0.5 + 0.5 * ny;
        final ambR = 0.42 * (grR + (skyR - grR) * hemi);
        final ambG = 0.42 * (grG + (skyG - grG) * hemi);
        final ambB = 0.42 * (grB + (skyB - grB) * hemi);
        final nh = (nx * hx + ny * hy + nz * hz) / hl;
        final spec = nh > 0 ? gloss * 190 * math.pow(nh, 28) : 0.0;
        final edge = 1 - (nz < 0 ? 0 : nz);
        final rim = edge * edge * edge;

        final r = ar * (ambR + diff) + spec + rim * rimR;
        final g = ag * (ambG + diff) + spec + rim * rimG;
        final b = ab * (ambB + diff) + spec + rim * rimB;
        _vc[gi] = 0xFF000000 |
            (r > 255 ? 255 : r.toInt()) << 16 |
            (g > 255 ? 255 : g.toInt()) << 8 |
            (b > 255 ? 255 : b.toInt());
      }

      final idx = mesh.indices;
      final bias = it.depthBias;
      double? flat;
      if (it.decal) {
        final c = mesh.center;
        flat = m.g * c.x + m.h * c.y + m.i * c.z + m.tz;
      }
      for (var t = 0; t < idx.length; t += 3) {
        final i0 = vBase + idx[t], i1 = vBase + idx[t + 1];
        final i2 = vBase + idx[t + 2];
        final z0 = _vz[i0], z1 = _vz[i1], z2 = _vz[i2];
        if (z0 > -0.05 || z1 > -0.05 || z2 > -0.05) continue; // near clip
        final area = (_vx[i1] - _vx[i0]) * (_vy[i2] - _vy[i0]) -
            (_vx[i2] - _vx[i0]) * (_vy[i1] - _vy[i0]);
        if (area >= 0) continue; // back face (screen space is y-down)
        final d = (flat ?? (z0 + z1 + z2) / 3) + bias;
        _triDepth[tCount] = d;
        _triV[tCount * 3] = i0;
        _triV[tCount * 3 + 1] = i1;
        _triV[tCount * 3 + 2] = i2;
        if (d < minD) minD = d;
        if (d > maxD) maxD = d;
        tCount++;
      }
      vBase += n;
    }
    lastTriangleCount = tCount;
    if (tCount == 0) return;

    // Counting sort far -> near (more negative z is farther away).
    _bucket.fillRange(0, _bucket.length, 0);
    final span = math.max(1e-6, maxD - minD);
    final scale = (_buckets - 1) / span;
    for (var t = 0; t < tCount; t++) {
      _bucket[((_triDepth[t] - minD) * scale).toInt() + 1]++;
    }
    for (var b = 1; b <= _buckets; b++) {
      _bucket[b] += _bucket[b - 1];
    }
    for (var t = 0; t < tCount; t++) {
      final b = ((_triDepth[t] - minD) * scale).toInt();
      _order[_bucket[b]++] = t;
    }

    final outPos = Float32List(tCount * 6);
    final outCol = Int32List(tCount * 3);
    for (var k = 0; k < tCount; k++) {
      final t = _order[k];
      for (var j = 0; j < 3; j++) {
        final vi = _triV[t * 3 + j];
        outPos[k * 6 + j * 2] = _vx[vi];
        outPos[k * 6 + j * 2 + 1] = _vy[vi];
        outCol[k * 3 + j] = _vc[vi];
      }
    }
    final vertices = ui.Vertices.raw(ui.VertexMode.triangles, outPos,
        colors: outCol);
    canvas.drawVertices(vertices, ui.BlendMode.dst, ui.Paint());
    vertices.dispose();
  }

  static int _mulArgb(int a, int b) {
    final r = (((a >> 16) & 255) * ((b >> 16) & 255)) ~/ 255;
    final g = (((a >> 8) & 255) * ((b >> 8) & 255)) ~/ 255;
    final bl = ((a & 255) * (b & 255)) ~/ 255;
    return 0xFF000000 | (r << 16) | (g << 8) | bl;
  }
}
