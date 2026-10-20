import '../character/character_definition.dart';
import '../character/part.dart';

/// Equipment slots on the character. Each slot holds at most one item.
enum GarmentSlot {
  hair,
  headwear,
  earrings,
  necklace,
  eyewear,
  top,
  outerwear,
  bottom,
  fullOutfit,
  socks,
  shoes,
  bag,
  wrist,
  belt,
  scarf;

  /// Slots that are never empty: removing the item restores the character's
  /// default for that slot.
  bool get alwaysFilled => this == hair || this == shoes;
}

/// Closet tabs shown to the player.
enum GarmentCategory {
  tops('Tops', '👚'),
  bottoms('Bottoms', '👖'),
  dresses('Dresses', '👗'),
  shoes('Shoes', '👟'),
  hair('Hair', '💇‍♀️'),
  accessories('Accessories', '💍'),
  bags('Bags', '👜'),
  extras('Extras', '🧣');

  final String label;
  final String emoji;
  const GarmentCategory(this.label, this.emoji);
}

/// A colour option for a garment. [natural] variants (hair only) use the
/// character's own hair colour instead of [primary].
class ColorVariant {
  final String name;
  final int primary;
  final int secondary;
  final int accent;
  final bool natural;

  const ColorVariant(this.name, this.primary,
      {int? secondary, int? accent, this.natural = false})
      : secondary = secondary ?? primary,
        accent = accent ?? 0xFFFFFFFF;
}

/// Everything a builder needs to produce meshes for one character.
class GarmentBuildContext {
  final CharacterDefinition character;
  final ColorVariant variant;

  const GarmentBuildContext(this.character, this.variant);

  int get primary => variant.natural ? character.hairColor : variant.primary;
  int get secondary =>
      variant.natural ? character.hairColor : variant.secondary;
  int get accent => variant.accent;
}

typedef GarmentBuilder = List<Part> Function(GarmentBuildContext ctx);

/// Data-driven description of one closet item. Registering a new item only
/// requires adding a definition to the catalogue; the wardrobe, closet UI and
/// save system pick it up automatically.
class GarmentDefinition {
  final String id;
  final String name;
  final String subtype; // e.g. "Hoodie", "Sneakers"
  final GarmentCategory category;
  final GarmentSlot slot;
  final List<ColorVariant> variants;

  /// Character ids allowed to wear this item; empty means everyone.
  final Set<String> compatibleCharacters;

  /// Body / hair tags this garment fully covers (masked when equipped).
  final Set<String> hides;

  /// Layering: full outfits that also act as a top or bottom (e.g. a
  /// jumpsuit) may still be worn under outerwear. Items listed here cannot be
  /// equipped at the same time as this one.
  final Set<GarmentSlot> blocksSlots;

  /// Number of saved looks needed to unlock this item (0 = unlocked).
  final int unlockAtSavedLooks;

  /// Bumped when the item's geometry changes so cached thumbnails refresh.
  final int assetVersion;

  final GarmentBuilder build;

  const GarmentDefinition({
    required this.id,
    required this.name,
    required this.subtype,
    required this.category,
    required this.slot,
    required this.variants,
    required this.build,
    this.compatibleCharacters = const {},
    this.hides = const {},
    this.blocksSlots = const {},
    this.unlockAtSavedLooks = 0,
    this.assetVersion = 1,
  });

  bool isCompatibleWith(String characterId) =>
      compatibleCharacters.isEmpty || compatibleCharacters.contains(characterId);
}
