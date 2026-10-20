import '../engine/math3d.dart';

/// Facial parameters that make each character look distinct while sharing
/// one skeleton and body.
class FaceStyle {
  final double eyeScale; // overall eye size
  final double eyeTilt; // radians; positive lifts the outer corners
  final double eyeSpacing; // horizontal offset added to the default spacing
  final double browThickness;
  final double browArch;
  final double cheekWidth; // >1 rounder face
  final bool freckles;
  final double blush; // 0..1
  final double smile; // 0..1 mouth curve

  const FaceStyle({
    this.eyeScale = 1,
    this.eyeTilt = 0,
    this.eyeSpacing = 0,
    this.browThickness = 1,
    this.browArch = 1,
    this.cheekWidth = 1,
    this.freckles = false,
    this.blush = 0.5,
    this.smile = 0.6,
  });
}

/// Data-driven description of a playable character.
class CharacterDefinition {
  final String id;
  final String name;
  final String tagline;
  final String bio;
  final int skinTone;
  final int eyeColor;
  final int hairColor;
  final int browColor;
  final int lipColor;
  final int themeColor; // used by the UI (cards, chips)
  final FaceStyle face;

  /// Default garment per slot name (see `GarmentSlot`). Removing an item
  /// restores the entry from here.
  final Map<String, String> defaultOutfit;

  /// Colour variant index per slot name for the default outfit.
  final Map<String, int> defaultVariants;

  /// Per-character bone scales (e.g. a slightly smaller head). Everything
  /// bound to a scaled bone — hair, hats, glasses — scales with it.
  final Map<String, Vec3> boneScales;

  const CharacterDefinition({
    required this.id,
    required this.name,
    required this.tagline,
    required this.bio,
    required this.skinTone,
    required this.eyeColor,
    required this.hairColor,
    required this.browColor,
    required this.lipColor,
    required this.themeColor,
    required this.face,
    required this.defaultOutfit,
    this.defaultVariants = const {},
    this.boneScales = const {},
  });
}
