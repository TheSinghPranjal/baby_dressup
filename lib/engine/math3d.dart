import 'dart:math' as math;

/// Minimal immutable 3D vector used by the procedural mesh builders.
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);
  static const one = Vec3(1, 1, 1);
  static const up = Vec3(0, 1, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator -() => Vec3(-x, -y, -z);

  Vec3 mul(Vec3 o) => Vec3(x * o.x, y * o.y, z * o.z);
  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final l = length;
    return l < 1e-9 ? const Vec3(0, 1, 0) : Vec3(x / l, y / l, z / l);
  }

  Vec3 lerp(Vec3 o, double t) =>
      Vec3(x + (o.x - x) * t, y + (o.y - y) * t, z + (o.z - z) * t);

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Affine transform stored as a 3x3 linear part (row-major) plus translation.
class Affine {
  final double a, b, c, d, e, f, g, h, i; // rows: [a b c] [d e f] [g h i]
  final double tx, ty, tz;

  const Affine(this.a, this.b, this.c, this.d, this.e, this.f, this.g, this.h,
      this.i, this.tx, this.ty, this.tz);

  static const identity = Affine(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0);

  factory Affine.translation(Vec3 t) =>
      Affine(1, 0, 0, 0, 1, 0, 0, 0, 1, t.x, t.y, t.z);

  factory Affine.scale(Vec3 s) =>
      Affine(s.x, 0, 0, 0, s.y, 0, 0, 0, s.z, 0, 0, 0);

  factory Affine.rotX(double r) {
    final cs = math.cos(r), sn = math.sin(r);
    return Affine(1, 0, 0, 0, cs, -sn, 0, sn, cs, 0, 0, 0);
  }

  factory Affine.rotY(double r) {
    final cs = math.cos(r), sn = math.sin(r);
    return Affine(cs, 0, sn, 0, 1, 0, -sn, 0, cs, 0, 0, 0);
  }

  factory Affine.rotZ(double r) {
    final cs = math.cos(r), sn = math.sin(r);
    return Affine(cs, -sn, 0, sn, cs, 0, 0, 0, 1, 0, 0, 0);
  }

  /// Euler rotation applied in the order Z, then X, then Y (i.e. Ry * Rx * Rz).
  factory Affine.euler(Vec3 r) =>
      Affine.rotY(r.y) * Affine.rotX(r.x) * Affine.rotZ(r.z);

  /// Translation * rotation(euler) * scale.
  factory Affine.trs(
          {Vec3 t = Vec3.zero, Vec3 r = Vec3.zero, Vec3 s = Vec3.one}) =>
      Affine.translation(t) * Affine.euler(r) * Affine.scale(s);

  /// Rotation that maps +Z onto [dir] (no roll).
  factory Affine.lookDir(Vec3 dir) {
    final n = dir.normalized();
    final yaw = math.atan2(n.x, n.z);
    final pitch = -math.asin(n.y.clamp(-1.0, 1.0));
    return Affine.rotY(yaw) * Affine.rotX(pitch);
  }

  /// Rotation that maps -Y onto [dir] (used for limbs and tubes).
  factory Affine.alignDown(Vec3 dir) {
    final n = dir.normalized();
    const down = Vec3(0, -1, 0);
    final axis = down.cross(n);
    final s = axis.length;
    final cs = down.dot(n);
    if (s < 1e-8) {
      return cs > 0 ? Affine.identity : Affine.rotZ(math.pi);
    }
    return Affine.axisAngle(axis * (1 / s), math.atan2(s, cs));
  }

  factory Affine.axisAngle(Vec3 k, double angle) {
    final c = math.cos(angle), s = math.sin(angle), t = 1 - c;
    return Affine(
      t * k.x * k.x + c, t * k.x * k.y - s * k.z, t * k.x * k.z + s * k.y,
      t * k.x * k.y + s * k.z, t * k.y * k.y + c, t * k.y * k.z - s * k.x,
      t * k.x * k.z - s * k.y, t * k.y * k.z + s * k.x, t * k.z * k.z + c,
      0, 0, 0,
    );
  }

  Affine operator *(Affine o) => Affine(
        a * o.a + b * o.d + c * o.g,
        a * o.b + b * o.e + c * o.h,
        a * o.c + b * o.f + c * o.i,
        d * o.a + e * o.d + f * o.g,
        d * o.b + e * o.e + f * o.h,
        d * o.c + e * o.f + f * o.i,
        g * o.a + h * o.d + i * o.g,
        g * o.b + h * o.e + i * o.h,
        g * o.c + h * o.f + i * o.i,
        a * o.tx + b * o.ty + c * o.tz + tx,
        d * o.tx + e * o.ty + f * o.tz + ty,
        g * o.tx + h * o.ty + i * o.tz + tz,
      );

  Vec3 point(Vec3 p) => Vec3(a * p.x + b * p.y + c * p.z + tx,
      d * p.x + e * p.y + f * p.z + ty, g * p.x + h * p.y + i * p.z + tz);

  Vec3 dir(Vec3 p) => Vec3(a * p.x + b * p.y + c * p.z,
      d * p.x + e * p.y + f * p.z, g * p.x + h * p.y + i * p.z);

  Vec3 get translation => Vec3(tx, ty, tz);
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

double smoothstep(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
