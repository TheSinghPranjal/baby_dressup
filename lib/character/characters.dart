import '../engine/math3d.dart';
import 'character_definition.dart';

/// Starter cast. All share one skeleton and body so every garment fits.
const List<CharacterDefinition> kCharacters = [
  // Designed after "Mia: Sporty & Cheerful" character sheet.
  CharacterDefinition(
    id: 'mia',
    name: 'Mia',
    tagline: 'Sporty & cheerful',
    bio: 'Mia is a sporty, energetic and cheerful girl who loves trying new styles. '
        'She is friendly, confident and always ready for fun adventures!',
    skinTone: 0xFFF4C9A8,
    eyeColor: 0xFF2E9F58,
    hairColor: 0xFF8A5A3B,
    browColor: 0xFF6B4228,
    lipColor: 0xFFE26F7E,
    themeColor: 0xFFFF9F7A,
    face: FaceStyle(
        eyeScale: 1.0, eyeTilt: -0.02, browThickness: 1.4, browArch: 0.65, blush: 0.9, smile: 0.75, cheekWidth: 0.97),
    defaultOutfit: {
      'hair': 'hair_messy_bun',
      'top': 'top_sport_tank',
      'bottom': 'bottom_cargo',
      'shoes': 'shoes_chunky_trainers',
      'wrist': 'wrist_smart_watch',
    },
    defaultVariants: {'bottom': 4, 'shoes': 3},
    boneScales: {'head': Vec3(1.04, 1.04, 1.04)},
  ),
  CharacterDefinition(
    id: 'ava',
    name: 'Ava',
    tagline: 'Elegant pastel dreamer',
    bio: 'Ballet dancer who loves soft pinks, pearls and tea parties.',
    skinTone: 0xFFFBDCCB,
    eyeColor: 0xFF5B8FD6,
    hairColor: 0xFFEFC38A,
    browColor: 0xFFB98A5A,
    lipColor: 0xFFEC8B9E,
    themeColor: 0xFFF7A6C6,
    face: FaceStyle(eyeScale: 1.08, eyeTilt: -0.05, blush: 0.8, smile: 0.5, browThickness: 0.8),
    defaultOutfit: {
      'hair': 'hair_long_waves',
      'top': 'top_puff_blouse',
      'bottom': 'bottom_pleated_skirt',
      'shoes': 'shoes_ballet_flats',
      'necklace': 'neck_pearls',
    },
  ),
  CharacterDefinition(
    id: 'zara',
    name: 'Zara',
    tagline: 'Bold streetwear icon',
    bio: 'Dancer and sneaker collector who designs her own graphic tees.',
    skinTone: 0xFF8D5A3B,
    eyeColor: 0xFF5A3A22,
    hairColor: 0xFF231C20,
    browColor: 0xFF1E1618,
    lipColor: 0xFFB8566A,
    themeColor: 0xFFB28CFF,
    face: FaceStyle(eyeTilt: 0.1, browThickness: 1.25, smile: 0.7, blush: 0.35, cheekWidth: 1.02),
    defaultOutfit: {
      'hair': 'hair_space_buns',
      'top': 'top_hoodie',
      'bottom': 'bottom_cargo',
      'shoes': 'shoes_chunky_trainers',
      'earrings': 'ear_gold_hoops',
    },
  ),
  CharacterDefinition(
    id: 'luna',
    name: 'Luna',
    tagline: 'Artsy & colourful',
    bio: 'Paints murals, collects vinyl and dyes her hair a new colour every season.',
    skinTone: 0xFFE2B08C,
    eyeColor: 0xFF8E7CC3,
    hairColor: 0xFFB9A0E8,
    browColor: 0xFF6E5A8A,
    lipColor: 0xFFD8708C,
    themeColor: 0xFF9EDFC8,
    face: FaceStyle(eyeScale: 1.05, eyeSpacing: 0.004, smile: 0.65, blush: 0.6, browArch: 1.2),
    defaultOutfit: {
      'hair': 'hair_chin_bob',
      'top': 'top_striped_tee',
      'bottom': 'bottom_wide_trousers',
      'shoes': 'shoes_hightops',
      'headwear': 'head_beret',
    },
  ),
  CharacterDefinition(
    id: 'sofia',
    name: 'Sofia',
    tagline: 'Classic & preppy',
    bio: 'Debate club president with a planner for everything and a soft spot for plaid.',
    skinTone: 0xFFD9A57E,
    eyeColor: 0xFF7A5A2E,
    hairColor: 0xFF4A2C1E,
    browColor: 0xFF3A2216,
    lipColor: 0xFFC9606F,
    themeColor: 0xFF8EC5F2,
    face: FaceStyle(eyeScale: 0.95, browThickness: 1.1, smile: 0.55, blush: 0.45, cheekWidth: 0.98),
    defaultOutfit: {
      'hair': 'hair_twin_braids',
      'top': 'top_button_shirt',
      'bottom': 'bottom_aline_skirt',
      'shoes': 'shoes_mary_janes',
      'outerwear': 'outer_cardigan',
    },
  ),
  CharacterDefinition(
    id: 'aria',
    name: 'Aria',
    tagline: 'Trendy & modern',
    bio: 'Runs a fashion blog and always knows what is next.',
    skinTone: 0xFFF3D2B8,
    eyeColor: 0xFF3B2A26,
    hairColor: 0xFF1E1A22,
    browColor: 0xFF1E1A22,
    lipColor: 0xFFE07A8A,
    themeColor: 0xFFFFC56B,
    face: FaceStyle(eyeScale: 1.02, eyeTilt: 0.06, smile: 0.6, blush: 0.55, browThickness: 0.9),
    defaultOutfit: {
      'hair': 'hair_long_straight',
      'top': 'top_heart_tee',
      'bottom': 'bottom_flare_jeans',
      'shoes': 'shoes_classic_sneakers',
      'outerwear': 'outer_denim_jacket',
    },
  ),
];

CharacterDefinition? characterById(String id) {
  for (final c in kCharacters) {
    if (c.id == id) return c;
  }
  return null;
}
