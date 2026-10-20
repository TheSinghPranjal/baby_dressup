import '../wardrobe/garment.dart';
import '../wardrobe/outfit_state.dart';

/// Whole-body GLB looks for Mia.
///
/// Every file shipped today is Mia head to toe: a different top, the same
/// grey shorts and the same sneakers. She has no skeleton, so a look is one
/// model rather than a stack of garment meshes.
///
/// Bottoms are not selectable yet. When they are, add an entry to
/// [comboAssets] keyed `topOrOuterId|bottomId`. That file wins over the
/// top-only model in [topAssets], so existing tops keep working.
abstract final class MiaLooks {
  static const characterId = 'mia';

  /// Grey tee, grey shorts. Shown until a mapped top is equipped, and again
  /// when that top is taken off.
  static const defaultAsset = 'assets/models/mia/default.glb';

  /// Source models are 1.0 tall with feet on y = 0. The dressing room and the
  /// other characters are about 1.6, so Mia is scaled up to stand on the set.
  static const worldScale = 1.6;

  /// Tops tab → whole-body file. The denim jacket lives in that tab too
  /// (`outerwear` slot) and replaces the tee while it is worn.
  static const topAssets = <String, String>{
    'top_basic_tee': 'assets/models/mia/tee_white.glb',
    'top_heart_tee': 'assets/models/mia/tee_heart.glb',
    'top_hoodie': 'assets/models/mia/hoodie.glb',
    'outer_denim_jacket': 'assets/models/mia/denim_jacket.glb',
  };

  /// Exact `(top or outerwear, bottom)` files. Empty until bottoms ship.
  /// Pass [assetFor]'s `combos` in tests to try a pair before adding it here.
  static const comboAssets = <String, String>{};

  static bool isModelledTop(String garmentId) =>
      topAssets.containsKey(garmentId);

  static List<String> get allAssets => <String>[
    defaultAsset,
    ...topAssets.values,
  ];

  /// Which file to show for [state].
  ///
  /// Order: a registered (piece, bottom) combo, then the piece's top-only
  /// file, then [defaultAsset]. Outerwear wins over the tee when both are
  /// mapped, because the jacket model already includes the shirt underneath.
  static String assetFor(OutfitState state, {Map<String, String>? combos}) {
    final table = combos ?? comboAssets;
    final outer = state.items[GarmentSlot.outerwear];
    final top = state.items[GarmentSlot.top];
    final bottom = state.items[GarmentSlot.bottom];
    final piece = _piece(outer, table) ?? _piece(top, table);
    if (piece != null && bottom != null) {
      final exact = table['$piece|$bottom'];
      if (exact != null) return exact;
    }
    if (piece != null) {
      final topOnly = topAssets[piece];
      if (topOnly != null) return topOnly;
    }
    return defaultAsset;
  }

  static String? _piece(String? id, Map<String, String> combos) {
    if (id == null) return null;
    if (topAssets.containsKey(id)) return id;
    final prefix = '$id|';
    for (final key in combos.keys) {
      if (key.startsWith(prefix)) return id;
    }
    return null;
  }
}
