import '../engine/math3d.dart';

/// Bone names of the shared humanoid skeleton. Every character and every
/// garment uses these names, which is what lets clothing be reused.
abstract final class Bones {
  static const root = 'root';
  static const hips = 'hips';
  static const spine = 'spine';
  static const neck = 'neck';
  static const head = 'head';
  static const eyeL = 'eye_L', eyeR = 'eye_R';
  static const upperArmL = 'upperArm_L', upperArmR = 'upperArm_R';
  static const forearmL = 'forearm_L', forearmR = 'forearm_R';
  static const handL = 'hand_L', handR = 'hand_R';
  static const fingersR = 'fingers_R';
  static const thighL = 'thigh_L', thighR = 'thigh_R';
  static const shinL = 'shin_L', shinR = 'shin_R';
  static const footL = 'foot_L', footR = 'foot_R';

  static String side(String base, bool left) => '${base}_${left ? 'L' : 'R'}';
}

class BoneDef {
  final String name;
  final String? parent;
  final Vec3 offset; // rest translation relative to the parent
  const BoneDef(this.name, this.parent, this.offset);
}

/// Shared rig. Character faces +Z; the character's left side is +X.
/// Units are metres-ish; the standing character is ~1.6 tall.
class Skeleton {
  static const List<BoneDef> bones = [
    BoneDef(Bones.root, null, Vec3(0, 0, 0)),
    BoneDef(Bones.hips, Bones.root, Vec3(0, 0.84, 0)),
    BoneDef(Bones.spine, Bones.hips, Vec3(0, 0.04, 0)),
    BoneDef(Bones.neck, Bones.spine, Vec3(0, 0.355, 0)),
    BoneDef(Bones.head, Bones.neck, Vec3(0, 0.028, 0)),
    BoneDef(Bones.eyeL, Bones.head, Vec3(0.058, 0.128, 0.121)),
    BoneDef(Bones.eyeR, Bones.head, Vec3(-0.058, 0.128, 0.121)),
    BoneDef(Bones.upperArmL, Bones.spine, Vec3(0.162, 0.3, 0)),
    BoneDef(Bones.forearmL, Bones.upperArmL, Vec3(0, -0.25, 0)),
    BoneDef(Bones.handL, Bones.forearmL, Vec3(0, -0.225, 0)),
    BoneDef(Bones.upperArmR, Bones.spine, Vec3(-0.162, 0.3, 0)),
    BoneDef(Bones.forearmR, Bones.upperArmR, Vec3(0, -0.25, 0)),
    BoneDef(Bones.handR, Bones.forearmR, Vec3(0, -0.225, 0)),
    BoneDef(Bones.fingersR, Bones.handR, Vec3(0, -0.07, 0)),
    BoneDef(Bones.thighL, Bones.hips, Vec3(0.074, -0.04, 0)),
    BoneDef(Bones.shinL, Bones.thighL, Vec3(0, -0.37, 0)),
    BoneDef(Bones.footL, Bones.shinL, Vec3(0, -0.37, 0)),
    BoneDef(Bones.thighR, Bones.hips, Vec3(-0.074, -0.04, 0)),
    BoneDef(Bones.shinR, Bones.thighR, Vec3(0, -0.37, 0)),
    BoneDef(Bones.footR, Bones.shinR, Vec3(0, -0.37, 0)),
  ];

  static final Set<String> names = {for (final b in bones) b.name};

  /// Animated state of the rig: per-bone euler rotations, scales and a root
  /// translation (used for hops and bounces).
  static Map<String, Affine> solve(
      {Map<String, Vec3> rotations = const {},
      Map<String, Vec3> scales = const {},
      Vec3 rootOffset = Vec3.zero,
      double turntable = 0}) {
    final world = <String, Affine>{};
    for (final b in bones) {
      final local = Affine.translation(
              b.parent == null ? b.offset + rootOffset : b.offset) *
          (b.parent == null ? Affine.rotY(turntable) : Affine.identity) *
          Affine.euler(rotations[b.name] ?? Vec3.zero) *
          Affine.scale(scales[b.name] ?? Vec3.one);
      world[b.name] =
          b.parent == null ? local : world[b.parent]! * local;
    }
    return world;
  }

  static final Map<String, Affine> rest = solve();
}
