import 'garment.dart';

/// Immutable snapshot of what a character is wearing and how she is shown.
class OutfitState {
  final String characterId;
  final Map<GarmentSlot, String> items;
  final Map<GarmentSlot, int> variants;
  final String poseId;
  final String backgroundId;

  const OutfitState({
    required this.characterId,
    this.items = const {},
    this.variants = const {},
    this.poseId = 'casual',
    this.backgroundId = 'pastel_studio',
  });

  String? operator [](GarmentSlot slot) => items[slot];
  int variantOf(GarmentSlot slot) => variants[slot] ?? 0;
  bool isEquipped(String garmentId) => items.values.contains(garmentId);

  OutfitState copyWith({
    String? characterId,
    Map<GarmentSlot, String>? items,
    Map<GarmentSlot, int>? variants,
    String? poseId,
    String? backgroundId,
  }) =>
      OutfitState(
        characterId: characterId ?? this.characterId,
        items: Map.unmodifiable(items ?? this.items),
        variants: Map.unmodifiable(variants ?? this.variants),
        poseId: poseId ?? this.poseId,
        backgroundId: backgroundId ?? this.backgroundId,
      );

  Map<String, dynamic> toJson() => {
        'characterId': characterId,
        'items': {for (final e in items.entries) e.key.name: e.value},
        'variants': {for (final e in variants.entries) e.key.name: e.value},
        'pose': poseId,
        'background': backgroundId,
      };

  /// Parses JSON leniently: unknown slots are dropped (they are reported by
  /// the wardrobe when the look is applied).
  factory OutfitState.fromJson(Map<String, dynamic> json) {
    GarmentSlot? slot(String n) {
      for (final s in GarmentSlot.values) {
        if (s.name == n) return s;
      }
      return null;
    }

    final items = <GarmentSlot, String>{};
    (json['items'] as Map? ?? {}).forEach((k, v) {
      final s = slot(k as String);
      if (s != null && v is String) items[s] = v;
    });
    final variants = <GarmentSlot, int>{};
    (json['variants'] as Map? ?? {}).forEach((k, v) {
      final s = slot(k as String);
      if (s != null && v is num) variants[s] = v.toInt();
    });
    return OutfitState(
      characterId: json['characterId'] as String? ?? 'mia',
      items: items,
      variants: variants,
      poseId: json['pose'] as String? ?? 'casual',
      backgroundId: json['background'] as String? ?? 'pastel_studio',
    );
  }
}
