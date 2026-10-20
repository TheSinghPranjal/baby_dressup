import 'dart:math' as math;

import '../engine/math3d.dart';
import 'skeleton.dart';

/// A pose is a set of bone rotations, optionally animated over time.
class PoseDef {
  final String id;
  final String name;
  final String emoji;
  final Map<String, Vec3> rotations;
  final Map<String, Vec3> scales;

  /// Adds time-varying offsets (radians) on top of [rotations].
  final void Function(double t, Map<String, Vec3> rot)? animate;
  final double bounce; // root hop amplitude for lively poses

  const PoseDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rotations,
    this.scales = const {},
    this.animate,
    this.bounce = 0,
  });
}

void _add(Map<String, Vec3> m, String bone, Vec3 d) =>
    m[bone] = (m[bone] ?? Vec3.zero) + d;

const _relaxedArms = {
  Bones.upperArmL: Vec3(0.05, 0, 0.13),
  Bones.upperArmR: Vec3(0.05, 0, -0.13),
  Bones.forearmL: Vec3(-0.15, 0, 0.04),
  Bones.forearmR: Vec3(-0.15, 0, -0.04),
};

final List<PoseDef> kPoses = [
  const PoseDef(
    id: 'casual',
    name: 'Casual',
    emoji: '🧍‍♀️',
    rotations: {
      ..._relaxedArms,
      Bones.hips: Vec3(0, 0, 0.025),
      Bones.spine: Vec3(0, 0, -0.03),
      Bones.head: Vec3(0, 0, 0.04),
      Bones.thighR: Vec3(-0.08, 0, -0.03),
      Bones.shinR: Vec3(0.16, 0, 0),
      Bones.footR: Vec3(-0.08, 0, 0),
      Bones.thighL: Vec3(0, 0, -0.02),
    },
  ),
  const PoseDef(
    id: 'hand_on_hip',
    name: 'Hand on Hip',
    emoji: '💁‍♀️',
    rotations: {
      Bones.upperArmL: Vec3(0.12, 0, 0.78),
      Bones.forearmL: Vec3(-0.2, 0, -1.78),
      Bones.handL: Vec3(0, 0, -0.3),
      Bones.upperArmR: Vec3(0.05, 0, -0.14),
      Bones.forearmR: Vec3(-0.2, 0, -0.05),
      Bones.hips: Vec3(0, 0.12, 0.05),
      Bones.spine: Vec3(0, -0.08, -0.06),
      Bones.head: Vec3(0.04, -0.1, 0.1),
      Bones.thighR: Vec3(-0.12, 0, 0.06),
      Bones.shinR: Vec3(0.2, 0, 0),
      Bones.footR: Vec3(-0.1, 0, 0),
      Bones.thighL: Vec3(0, 0, -0.05),
      Bones.footL: Vec3(0, 0, 0.05),
    },
  ),
  const PoseDef(
    id: 'peace',
    name: 'Peace Sign',
    emoji: '✌️',
    rotations: {
      Bones.upperArmL: Vec3(0.05, 0, 0.14),
      Bones.forearmL: Vec3(-0.15, 0, 0.04),
      Bones.upperArmR: Vec3(-0.35, 0.3, -0.42),
      Bones.forearmR: Vec3(-2.5, 0, 0.35),
      Bones.handR: Vec3(0.0, -0.4, 0.0),
      Bones.head: Vec3(0.05, 0.08, -0.14),
      Bones.spine: Vec3(0, 0.04, 0.03),
      Bones.hips: Vec3(0, 0, -0.03),
      Bones.thighL: Vec3(-0.06, 0, 0.03),
      Bones.shinL: Vec3(0.14, 0, 0),
    },
    scales: {Bones.fingersR: Vec3.one},
  ),
  PoseDef(
    id: 'wave',
    name: 'Wave',
    emoji: '👋',
    rotations: const {
      Bones.upperArmL: Vec3(0.05, 0, 0.14),
      Bones.forearmL: Vec3(-0.15, 0, 0.04),
      Bones.upperArmR: Vec3(-0.1, 0, -2.3),
      Bones.forearmR: Vec3(0, 0, -0.55),
      Bones.head: Vec3(0, 0, 0.06),
      Bones.spine: Vec3(0, 0, 0.03),
    },
    animate: (t, rot) {
      _add(rot, Bones.forearmR, Vec3(0, 0, 0.38 * math.sin(t * 9)));
      _add(rot, Bones.handR, Vec3(0, 0, 0.15 * math.sin(t * 9 - 0.6)));
      _add(rot, Bones.head, Vec3(0, 0, 0.03 * math.sin(t * 4.5)));
    },
  ),
  PoseDef(
    id: 'happy',
    name: 'Happy',
    emoji: '🥳',
    bounce: 0.03,
    rotations: const {
      Bones.upperArmL: Vec3(-0.1, 0, 2.45),
      Bones.forearmL: Vec3(0, 0, 0.35),
      Bones.upperArmR: Vec3(-0.1, 0, -2.45),
      Bones.forearmR: Vec3(0, 0, -0.35),
      Bones.head: Vec3(-0.08, 0, 0),
    },
    animate: (t, rot) {
      final s = math.sin(t * 7);
      _add(rot, Bones.upperArmL, Vec3(0, 0, 0.12 * s));
      _add(rot, Bones.upperArmR, Vec3(0, 0, 0.12 * s));
      _add(rot, Bones.head, Vec3(0, 0, 0.08 * s));
      _add(rot, Bones.hips, Vec3(0, 0, 0.04 * s));
    },
  ),
];

PoseDef poseById(String id) =>
    kPoses.firstWhere((p) => p.id == id, orElse: () => kPoses.first);

/// Drives the skeleton: blends between poses and layers idle breathing,
/// blinking, reaction hops, a celebratory spin and an intro wave.
class CharacterAnimator {
  PoseDef _pose = kPoses.first;
  final Map<String, Vec3> _rot = {};
  final Map<String, Vec3> _scale = {};
  final math.Random _rng;

  double time = 0;
  double _nextBlink = 2.0;
  double _blink = -1; // seconds into a blink, or <0 when not blinking
  double _hop = -1;
  double _spin = -1;
  double _waveIntro = -1;

  /// User/auto rotation in radians, added on top of the spin.
  double turntable = 0;

  /// Per-character bone scales (see `CharacterDefinition.boneScales`).
  Map<String, Vec3> baseScales = const {};

  CharacterAnimator({int seed = 7}) : _rng = math.Random(seed) {
    _snapTo(_pose);
  }

  String get poseId => _pose.id;

  void setPose(String id, {bool snap = false}) {
    _pose = poseById(id);
    if (snap) _snapTo(_pose);
  }

  void _snapTo(PoseDef p) {
    _rot
      ..clear()
      ..addAll(p.rotations);
    _scale
      ..clear()
      ..addAll({Bones.fingersR: const Vec3(0.001, 0.001, 0.001), ...p.scales});
  }

  /// Small hop + head tilt when an outfit changes.
  void react() => _hop = 0;

  /// Spin + hop when a look is saved.
  void celebrate() {
    _spin = 0;
    _hop = 0;
  }

  /// Friendly wave (e.g. when a character is selected).
  void waveHello() => _waveIntro = 0;

  void update(double dt) {
    dt = dt.clamp(0, 0.1);
    time += dt;

    // Blend towards the target pose (critically damped-ish lerp).
    final k = 1 - math.exp(-dt * 9);
    final target = Map<String, Vec3>.of(_pose.rotations);
    _pose.animate?.call(time, target);
    if (_waveIntro >= 0) {
      _waveIntro += dt;
      if (_waveIntro > 2.2) {
        _waveIntro = -1;
      } else if (_pose.id != 'wave') {
        final w = math.sin(math.min(1, _waveIntro / 0.3) * math.pi / 2) *
            (1 - smoothstep(1.8, 2.2, _waveIntro));
        target[Bones.upperArmR] = (target[Bones.upperArmR] ?? Vec3.zero)
                .lerp(const Vec3(-0.1, 0, -2.3), w);
        target[Bones.forearmR] = (target[Bones.forearmR] ?? Vec3.zero).lerp(
            Vec3(0, 0, -0.55 + 0.38 * math.sin(time * 9)), w);
      }
    }
    for (final b in {..._rot.keys, ...target.keys}) {
      final cur = _rot[b] ?? Vec3.zero;
      _rot[b] = cur.lerp(target[b] ?? Vec3.zero, k);
    }
    final targetScale = {Bones.fingersR: const Vec3(0.001, 0.001, 0.001), ..._pose.scales};
    for (final b in targetScale.keys) {
      _scale[b] = (_scale[b] ?? Vec3.one).lerp(targetScale[b]!, k);
    }

    // Blink.
    if (_blink < 0 && time >= _nextBlink) _blink = 0;
    var eyeOpen = 1.0;
    if (_blink >= 0) {
      _blink += dt;
      const dur = 0.16;
      eyeOpen = 1 - math.sin((_blink / dur).clamp(0.0, 1.0) * math.pi) * 0.92;
      if (_blink >= dur) {
        _blink = -1;
        _nextBlink = time + 2.2 + _rng.nextDouble() * 3.0;
      }
    }
    _scale[Bones.eyeL] = Vec3(1, eyeOpen, 1);
    _scale[Bones.eyeR] = Vec3(1, eyeOpen, 1);

    if (_hop >= 0) {
      _hop += dt;
      if (_hop > 0.55) _hop = -1;
    }
    if (_spin >= 0) {
      _spin += dt;
      if (_spin > 1.1) _spin = -1;
    }
  }

  /// Vertical root offset from hops and bouncy poses.
  double get lift {
    var l = _hop < 0 ? 0.0 : 0.045 * math.sin((_hop / 0.55) * math.pi);
    if (_pose.bounce > 0) l += _pose.bounce * math.sin(time * 7).abs();
    return l;
  }

  /// Motion for flat (paper-doll) characters, which have no skeleton:
  /// root lift, spin angle and a -1..1 breathing phase.
  ({double lift, double spin, double breath}) get flatMotion =>
      (lift: lift, spin: _spinAngle, breath: math.sin(time * 2.1));

  double get _spinAngle =>
      _spin < 0 ? 0 : 2 * math.pi * smoothstep(0, 1.1, _spin);

  Map<String, Affine> solve() {
    final rot = Map<String, Vec3>.of(_rot);
    // Idle breathing and sway.
    final breath = math.sin(time * 2.1);
    _add(rot, Bones.spine, Vec3(0.012 * breath, 0, 0));
    _add(rot, Bones.head, Vec3(-0.01 * breath, 0.04 * math.sin(time * 0.7), 0));
    _add(rot, Bones.upperArmL, Vec3(0, 0, 0.012 * breath));
    _add(rot, Bones.upperArmR, Vec3(0, 0, -0.012 * breath));

    if (_hop >= 0) {
      final h = math.sin((_hop / 0.55) * math.pi);
      _add(rot, Bones.head, Vec3(0, 0, 0.12 * h));
      _add(rot, Bones.upperArmL, Vec3(0, 0, 0.35 * h));
      _add(rot, Bones.upperArmR, Vec3(0, 0, -0.35 * h));
    }
    return Skeleton.solve(
      rotations: rot,
      scales: baseScales.isEmpty ? _scale : {...baseScales, ..._scale},
      rootOffset: Vec3(0, lift, 0),
      turntable: turntable + _spinAngle,
    );
  }
}
