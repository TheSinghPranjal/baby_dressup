import 'dart:math' as math;

import 'math3d.dart';
import 'mesh.dart';

/// A point on a lathe profile: radius from the Y axis at height [y].
class P2 {
  final double r, y;
  const P2(this.r, this.y);
}

/// Procedural primitive generators. Azimuth 0 faces +Z (towards the viewer
/// when the character faces forward); +PI/2 points to +X.
class Prim {
  /// Generic parametric surface. u runs around, v runs bottom -> top.
  /// When [wrapU] the first and last columns are shared (closed seam).
  static Mesh surface(int nu, int nv, Vec3 Function(double u, double v) f,
      {bool wrapU = false}) {
    final cols = wrapU ? nu : nu + 1;
    final verts = <Vec3>[];
    for (var j = 0; j <= nv; j++) {
      for (var i = 0; i < cols; i++) {
        verts.add(f(i / nu, j / nv));
      }
    }
    final tris = <int>[];
    for (var j = 0; j < nv; j++) {
      for (var i = 0; i < nu; i++) {
        final i1 = wrapU ? (i + 1) % nu : i + 1;
        final a = j * cols + i, b = j * cols + i1;
        final c = (j + 1) * cols + i1, d = (j + 1) * cols + i;
        tris.addAll([a, b, c, a, c, d]);
      }
    }
    return Mesh.fromLists(verts, tris);
  }

  /// Surface of revolution. [profile] is ordered bottom -> top along the
  /// outside. [sx]/[sz] squash the cross-section into an ellipse; [a0]/[a1]
  /// limit the azimuth for open shapes (e.g. jackets with an open front).
  static Mesh lathe(List<P2> profile,
      {int segments = 20,
      double sx = 1,
      double sz = 1,
      double a0 = 0,
      double a1 = 2 * math.pi,
      double inflate = 0,
      double Function(double angle, double v)? radiusMod}) {
    final full = (a1 - a0) >= 2 * math.pi - 1e-6;
    final n = profile.length - 1;
    return surface(segments, n, (u, v) {
      final k = (v * n).round().clamp(0, n);
      final p = profile[k];
      final ang = a0 + (a1 - a0) * u;
      final r = p.r * (radiusMod?.call(ang, v) ?? 1);
      return Vec3((r * sx + inflate) * math.sin(ang), p.y,
          (r * sz + inflate) * math.cos(ang));
    }, wrapU: full);
  }

  /// Smoothly resamples a coarse profile with Catmull-Rom interpolation.
  static List<P2> smooth(List<P2> pts, {int steps = 4}) {
    if (pts.length < 3) return pts;
    final out = <P2>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[math.max(0, i - 1)], p1 = pts[i];
      final p2 = pts[i + 1], p3 = pts[math.min(pts.length - 1, i + 2)];
      for (var s = 0; s < steps; s++) {
        final t = s / steps, t2 = t * t, t3 = t2 * t;
        double cr(double a, double b, double c, double d) =>
            0.5 *
            (2 * b +
                (-a + c) * t +
                (2 * a - 5 * b + 4 * c - d) * t2 +
                (-a + 3 * b - 3 * c + d) * t3);
        out.add(P2(math.max(0, cr(p0.r, p1.r, p2.r, p3.r)),
            cr(p0.y, p1.y, p2.y, p3.y)));
      }
    }
    out.add(pts.last);
    return out;
  }

  static Mesh ellipsoid(double rx, double ry, double rz,
      {int segments = 18,
      int rings = 12,
      Vec3 center = Vec3.zero,
      double a0 = 0,
      double a1 = 2 * math.pi,
      double p0 = 0,
      double p1 = math.pi}) {
    final full = (a1 - a0) >= 2 * math.pi - 1e-6;
    return surface(segments, rings, (u, v) {
      final ang = a0 + (a1 - a0) * u;
      final phi = p0 + (p1 - p0) * v;
      final s = math.sin(phi);
      return Vec3(center.x + rx * s * math.sin(ang),
          center.y - ry * math.cos(phi), center.z + rz * s * math.cos(ang));
    }, wrapU: full);
  }

  static Mesh sphere(double r, {Vec3 center = Vec3.zero, int segments = 14}) =>
      ellipsoid(r, r, r,
          center: center, segments: segments, rings: (segments * 0.7).round());

  /// Rounded box ("superellipsoid"). Smaller [e] gives sharper corners.
  static Mesh roundedBox(double w, double h, double d,
      {double e = 0.25, Vec3 center = Vec3.zero, int segments = 16}) {
    double sp(double v, double p) => v.sign * math.pow(v.abs(), p).toDouble();
    return surface(segments, segments ~/ 2 + 2, (u, v) {
      final ang = 2 * math.pi * u;
      final phi = math.pi * v;
      final s = sp(math.sin(phi), e);
      return Vec3(center.x + w / 2 * s * sp(math.sin(ang), e),
          center.y - h / 2 * sp(math.cos(phi), e),
          center.z + d / 2 * s * sp(math.cos(ang), e));
    }, wrapU: true);
  }

  /// Capsule hanging down from the origin along -Y, tapering r0 -> r1.
  static Mesh capsule(double length, double r0, double r1,
      {int segments = 14, double sx = 1, double sz = 1}) {
    final prof = <P2>[];
    const capSteps = 4;
    for (var k = 0; k <= capSteps; k++) {
      final a = -math.pi / 2 + (math.pi / 2) * k / capSteps;
      prof.add(P2(r1 * math.cos(a), -length + r1 * math.sin(a)));
    }
    for (var k = 1; k < 4; k++) {
      final t = k / 4;
      prof.add(P2(lerpDouble(r1, r0, t), -length * (1 - t)));
    }
    for (var k = 0; k <= capSteps; k++) {
      final a = (math.pi / 2) * k / capSteps;
      prof.add(P2(r0 * math.cos(a), r0 * math.sin(a)));
    }
    return lathe(prof, segments: segments, sx: sx, sz: sz);
  }

  /// Open tube from y=top down to y=bottom with radii; double-sided.
  static Mesh sleeve(double top, double bottom, double rTop, double rBottom,
      {int segments = 16, double sx = 1, double sz = 1}) {
    return lathe([P2(rBottom, bottom), P2(rTop, top)],
            segments: segments, sx: sx, sz: sz)
        .doubleSided();
  }

  /// Torus around the Y axis. [a0]/[a1] restrict the major arc.
  static Mesh torus(double major, double minor,
      {int segments = 24,
      int sides = 8,
      double a0 = 0,
      double a1 = 2 * math.pi,
      double sx = 1,
      double sz = 1}) {
    final prof = <P2>[];
    for (var k = 0; k <= sides; k++) {
      final a = -math.pi / 2 + 2 * math.pi * k / sides;
      prof.add(P2(major + minor * math.cos(a), minor * math.sin(a)));
    }
    return lathe(prof, segments: segments, sx: sx, sz: sz, a0: a0, a1: a1);
  }

  /// Tube swept along [path] with per-point radii (or constant [radius]).
  static Mesh tube(List<Vec3> path,
      {double radius = 0.01, List<double>? radii, int sides = 8}) {
    final verts = <Vec3>[];
    var prevN = const Vec3(0, 0, 1);
    for (var k = 0; k < path.length; k++) {
      final t = (path[math.min(k + 1, path.length - 1)] -
              path[math.max(k - 1, 0)])
          .normalized();
      var n = prevN - t * prevN.dot(t);
      if (n.length < 1e-4) {
        n = (t.cross(const Vec3(1, 0, 0)));
      }
      n = n.normalized();
      prevN = n;
      final b = t.cross(n);
      final r = radii?[k] ?? radius;
      for (var i = 0; i < sides; i++) {
        final a = 2 * math.pi * i / sides;
        verts.add(path[k] + (n * math.cos(a) + b * math.sin(a)) * r);
      }
    }
    final tris = <int>[];
    for (var k = 0; k < path.length - 1; k++) {
      for (var i = 0; i < sides; i++) {
        final i1 = (i + 1) % sides;
        final a = k * sides + i, bb = k * sides + i1;
        final c = (k + 1) * sides + i1, d = (k + 1) * sides + i;
        // Winding chosen so normals point away from the path.
        tris.addAll([a, bb, c, a, c, d]);
      }
    }
    final body = Mesh.fromLists(verts, tris);
    final caps = [
      sphere(radii?.first ?? radius, center: path.first, segments: sides),
      sphere(radii?.last ?? radius, center: path.last, segments: sides),
    ];
    return Mesh.merge([body, ...caps]);
  }

  /// Cylinder between two points.
  static Mesh rod(Vec3 a, Vec3 b, double r, {int sides = 10}) {
    final len = (b - a).length;
    return capsule(len, r, r, segments: sides)
        .transformed(Affine.translation(a) * Affine.alignDown(b - a));
  }

  /// Flat disc facing +Z (e.g. eyes, buttons), slightly domed.
  static Mesh disc(double rx, double ry,
      {double dome = 0.15, int segments = 16, Vec3 center = Vec3.zero}) {
    return ellipsoid(rx, ry, math.max(rx, ry) * dome,
        segments: segments, rings: 6, center: center, p0: 0, p1: math.pi);
  }
}
