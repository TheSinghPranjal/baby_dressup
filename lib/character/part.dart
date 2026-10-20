import '../engine/mesh.dart';

/// Depth-bias layers. A larger bias wins the painter's sort against lower
/// layers at the same depth, which is how garments sit cleanly on the body.
abstract final class Layer {
  static const body = 0.0;
  static const socks = 0.004;
  static const bottom = 0.008;
  static const top = 0.012;
  static const shoes = 0.012;
  static const outer = 0.02;
  static const hair = 0.016;
  static const accessory = 0.024;
}

/// A renderable mesh bound to one bone of the shared skeleton.
///
/// [tag] identifies a body/hair region so garments can mask what they cover
/// (e.g. long sleeves hide the arm skin underneath, hats hide a top bun).
class Part {
  final String bone;
  final Mesh mesh;
  final int color;
  final double gloss;
  final double bias;
  final String? tag;
  final bool decal;

  const Part(this.bone, this.mesh,
      {this.color = 0xFFFFFFFF,
      this.gloss = 0.08,
      this.bias = 0,
      this.tag,
      this.decal = false});

  Part withBias(double b) => Part(bone, mesh,
      color: color, gloss: gloss, bias: b, tag: tag, decal: decal);
}
