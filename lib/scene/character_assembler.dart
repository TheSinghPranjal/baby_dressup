import 'package:flutter/foundation.dart';

import '../character/body_builder.dart';
import '../character/character_definition.dart';
import '../character/part.dart';
import '../engine/math3d.dart';
import '../engine/renderer.dart';
import '../wardrobe/catalog.dart';
import '../wardrobe/garment.dart';
import '../wardrobe/outfit_state.dart';

/// Turns an [OutfitState] into renderable parts. Body and garment meshes are
/// cached (LRU) because building them is the expensive step; switching
/// outfits back and forth is then instant.
class CharacterAssembler {
  final GarmentCatalog catalog;
  final int maxCachedGarments;
  final _bodies = <String, List<Part>>{};
  final _garments = <String, List<Part>>{}; // insertion-ordered (LRU)

  /// Garment ids that failed to build (bad asset); they are skipped.
  final Set<String> failed = {};

  CharacterAssembler(this.catalog, {this.maxCachedGarments = 160});

  List<Part> body(CharacterDefinition c) =>
      _bodies.putIfAbsent(c.id, () => BodyBuilder.build(c));

  List<Part> garment(GarmentDefinition g, int variant, CharacterDefinition c) {
    final v = g.variants[variant.clamp(0, g.variants.length - 1)];
    final key = '${g.id}@${g.assetVersion}#$variant${v.natural ? '|${c.id}' : ''}';
    final hit = _garments.remove(key);
    if (hit != null) {
      _garments[key] = hit; // move to most-recent
      return hit;
    }
    List<Part> parts;
    try {
      parts = g.build(GarmentBuildContext(c, v));
    } catch (e, st) {
      debugPrint('Garment ${g.id} failed to build: $e\n$st');
      failed.add(g.id);
      parts = const [];
    }
    _garments[key] = parts;
    while (_garments.length > maxCachedGarments) {
      _garments.remove(_garments.keys.first);
    }
    return parts;
  }

  /// All visible parts for [state], with covered body regions masked out.
  List<Part> assemble(OutfitState state, CharacterDefinition c) {
    final hidden = <String>{};
    final garmentParts = <Part>[];
    for (final entry in state.items.entries) {
      final g = catalog.byId(entry.value);
      if (g == null) continue;
      hidden.addAll(g.hides);
      garmentParts.addAll(garment(g, state.variantOf(entry.key), c));
    }
    return [
      for (final p in body(c))
        if (p.tag == null || !hidden.contains(p.tag)) p,
      for (final p in garmentParts)
        if (p.tag == null || !hidden.contains(p.tag)) p,
    ];
  }

  static List<RenderItem> toRenderItems(
          List<Part> parts, Map<String, Affine> bones) =>
      [
        for (final p in parts)
          RenderItem(p.mesh, bones[p.bone] ?? Affine.identity,
              color: p.color,
              gloss: p.gloss,
              depthBias: p.bias,
              decal: p.decal)
      ];

  void clear() {
    _bodies.clear();
    _garments.clear();
  }
}
