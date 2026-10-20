import 'dart:math' as math;

import '../engine/math3d.dart';
import '../engine/primitives.dart';

/// Standard body proportions shared by every character. Garments are authored
/// against these numbers (plus a small offset) so they fit any character.
abstract final class Body {
  // Torso, in spine-bone space (y up from the spine bone).
  static const torsoProfile = [
    P2(0.122, -0.07),
    P2(0.118, 0.0),
    P2(0.108, 0.08),
    P2(0.11, 0.15),
    P2(0.118, 0.21),
    P2(0.124, 0.26),
    P2(0.122, 0.295),
    P2(0.104, 0.325),
    P2(0.066, 0.345),
    P2(0.042, 0.356),
  ];
  static const torsoDepth = 0.7; // z-scale of the torso cross-section

  // Pelvis, in hips-bone space.
  static const pelvisProfile = [
    P2(0.0, -0.06),
    P2(0.06, -0.058),
    P2(0.1, -0.045),
    P2(0.118, -0.035),
    P2(0.122, 0.01),
    P2(0.12, 0.06),
  ];
  static const pelvisDepth = 0.72;

  static const upperArmLen = 0.25, upperArmR0 = 0.043, upperArmR1 = 0.035;
  static const forearmLen = 0.225, forearmR0 = 0.034, forearmR1 = 0.026;
  static const thighLen = 0.37, thighR0 = 0.076, thighR1 = 0.052;
  static const shinLen = 0.37, shinR0 = 0.051, shinR1 = 0.035;

  // Head, in head-bone space. Lathe profile from chin to crown.
  static const headProfile = [
    P2(0.0, 0.02),
    P2(0.05, 0.026),
    P2(0.095, 0.05),
    P2(0.128, 0.09),
    P2(0.146, 0.14),
    P2(0.15, 0.18),
    P2(0.142, 0.23),
    P2(0.115, 0.275),
    P2(0.065, 0.302),
    P2(0.0, 0.31),
  ];
  static const headDepth = 0.93;
  static const headCenter = Vec3(0, 0.165, 0);

  /// Radius of a lathe profile at height [y] (linear interpolation).
  static double profileRadius(List<P2> profile, double y) {
    if (y <= profile.first.y) return profile.first.r;
    for (var i = 0; i < profile.length - 1; i++) {
      final a = profile[i], b = profile[i + 1];
      if (y >= a.y && y <= b.y) {
        return a.r + (b.r - a.r) * ((y - a.y) / (b.y - a.y));
      }
    }
    return profile.last.r;
  }

  /// A point on the front surface of the torso (spine space), pushed out by
  /// [offset]. Used to route straps, necklaces and buttons over the body.
  static Vec3 torsoFront(double x, double y, {double offset = 0.0}) {
    final r = profileRadius(torsoProfile, y) + offset;
    final rz = r * torsoDepth;
    final t = (x / r).clamp(-0.98, 0.98);
    return Vec3(x, y, rz * math.sqrt(1 - t * t));
  }

  static Vec3 torsoBack(double x, double y, {double offset = 0.0}) {
    final p = torsoFront(x, y, offset: offset);
    return Vec3(p.x, p.y, -p.z);
  }

  /// A point on the face surface (head space), for placing features.
  static Vec3 faceSurface(double x, double y, {double offset = 0.0}) {
    final r = profileRadius(headProfile, y) + offset;
    final rz = r * headDepth;
    final t = (x / r).clamp(-0.98, 0.98);
    return Vec3(x, y, rz * math.sqrt(1 - t * t));
  }

  /// Outward surface normal of the face at (x, y), approximated.
  static Vec3 faceNormal(double x, double y) {
    final p = faceSurface(x, y);
    final r = profileRadius(headProfile, y);
    return Vec3(p.x / r, (y - 0.17) * 1.2, p.z / (r * headDepth * headDepth))
        .normalized();
  }

  /// Scales a profile radially by [grow] (absolute) for garment layers.
  static List<P2> inflate(List<P2> profile, double grow,
          {double from = -1e9, double to = 1e9}) =>
      [
        for (final p in profile)
          if (p.y >= from - 1e-9 && p.y <= to + 1e-9) P2(p.r + grow, p.y)
      ];
}
