import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../character/character_definition.dart';
import '../wardrobe/garment.dart';
import '../wardrobe/outfit_state.dart';

/// Paper-doll (2D) art for one character. Every PNG in [folder] shares the
/// canvas of `base.png`, so layers line up when drawn on top of each other.
///
/// File names inside the folder (see docs/ASSET_AUTHORING.md):
/// - `base.png`                body (drawn first; the bottom edge is the soles)
/// - `<garmentId>.png`         the garment, colour variant 0
/// - `<garmentId>.<n>.png`     colour variant n
/// - `<garmentId>.back.png`    optional part drawn behind the body (long hair)
/// - `<garmentId>.<n>.back.png`
/// - `<garmentId>.icon.png`    optional closet icon (else the 3D thumbnail)
class DollArt {
  final String characterId;
  final String folder;

  /// World height of the canvas (soles to top edge), so the doll stands on
  /// the 3D pedestal at the same scale as the backdrop.
  final double worldHeight;

  /// Normalised region of the canvas framing the face, for avatars.
  final ui.Rect headRect;

  /// Garments already painted into `base.png`. They count as available and
  /// draw nothing of their own. Empty once the base is a bare body.
  final Set<String> bakedIntoBase;

  const DollArt({
    required this.characterId,
    required this.folder,
    required this.worldHeight,
    required this.headRect,
    this.bakedIntoBase = const {},
  });

  String get base => '${folder}base.png';
}

/// Characters drawn as paper dolls. Anyone not listed (or whose `base.png`
/// is missing) stays 3D.
const List<DollArt> kDollArt = [
  // Cut out of the "Choose Your Stylist" reference. Her signature outfit is
  // part of the base until separate garment layers are painted.
  DollArt(
    characterId: 'mia',
    folder: 'assets/doll/mia/',
    worldHeight: 1.68,
    headRect: ui.Rect.fromLTWH(0.12, 0.0, 0.56, 0.2),
    bakedIntoBase: {
      'hair_messy_bun',
      'top_sport_tank',
      'bottom_cargo',
      'shoes_chunky_trainers',
      'wrist_smart_watch',
    },
  ),
];

/// Draw order of garment layers in front of the body (behind-the-body
/// `.back.png` layers use the same order).
const List<GarmentSlot> kDollLayerOrder = [
  GarmentSlot.socks,
  GarmentSlot.shoes,
  GarmentSlot.bottom,
  GarmentSlot.top,
  GarmentSlot.fullOutfit,
  GarmentSlot.belt,
  GarmentSlot.outerwear,
  GarmentSlot.necklace,
  GarmentSlot.scarf,
  GarmentSlot.wrist,
  GarmentSlot.bag,
  GarmentSlot.hair,
  GarmentSlot.earrings,
  GarmentSlot.eyewear,
  GarmentSlot.headwear,
];

/// Knows which paper-doll PNGs ship with the app and decodes them on demand.
/// Listeners are notified whenever an image finishes loading.
class DollLibrary extends ChangeNotifier {
  final Map<String, DollArt> _art;
  final Set<String> _assets;
  final AssetBundle? _bundle;
  final Map<String, ui.Image> _images = {};
  final Set<String> _loading = {};

  DollLibrary._(this._art, this._assets, this._bundle);

  /// No paper dolls: every character is 3D.
  DollLibrary.empty() : this._({}, {}, null);

  static Future<DollLibrary> load(AssetBundle bundle, {List<DollArt> art = kDollArt}) async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final assets = manifest.listAssets().toSet();
    return DollLibrary._(
      {for (final a in art) if (assets.contains(a.base)) a.characterId: a},
      assets,
      bundle,
    );
  }

  DollArt? artFor(String characterId) => _art[characterId];

  /// Whether [g] can be shown on [character]. Always true for 3D characters.
  bool supports(String characterId, GarmentDefinition g) {
    final art = _art[characterId];
    if (art == null) return true;
    return art.bakedIntoBase.contains(g.id) || _assets.contains('${art.folder}${g.id}.png');
  }

  /// Colour variants of [g] with art, or null when every variant is fine.
  List<int>? variantsFor(CharacterDefinition c, GarmentDefinition g) {
    final art = _art[c.id];
    if (art == null) return null;
    if (art.bakedIntoBase.contains(g.id)) return [c.defaultVariants[g.slot.name] ?? 0];
    return [
      for (var v = 0; v < g.variants.length; v++)
        if (_variantPath(art, g.id, v, '.png') != null) v
    ];
  }

  String? iconFor(String characterId, String garmentId) {
    final art = _art[characterId];
    final path = art == null ? null : '${art.folder}$garmentId.icon.png';
    return path != null && _assets.contains(path) ? path : null;
  }

  /// Asset paths to draw, back to front.
  List<String> layersFor(OutfitState look, DollArt art) {
    final front = <String>[], back = <String>[];
    for (final slot in kDollLayerOrder) {
      final id = look.items[slot];
      if (id == null || art.bakedIntoBase.contains(id)) continue;
      final v = look.variantOf(slot);
      final f = _front(art, id, v);
      if (_assets.contains(f)) front.add(f);
      final b = _variantPath(art, id, v, '.back.png');
      if (b != null) back.add(b);
    }
    return [...back, art.base, ...front];
  }

  String _front(DollArt art, String id, int v) => _variantPath(art, id, v, '.png') ?? '${art.folder}$id.png';

  String? _variantPath(DollArt art, String id, int v, String suffix) {
    for (final p in ['${art.folder}$id.$v$suffix', if (v == 0) '${art.folder}$id$suffix']) {
      if (_assets.contains(p)) return p;
    }
    return null;
  }

  /// The decoded image, or null while it loads (listeners are notified).
  ui.Image? image(String path) {
    final img = _images[path];
    if (img != null || _bundle == null || !_loading.add(path)) return img;
    _decode(path).then((_) => notifyListeners(), onError: (Object e) => debugPrint('Doll art $path: $e'));
    return null;
  }

  Future<void> _decode(String path) async {
    final data = await _bundle!.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    _images[path] = (await codec.getNextFrame()).image;
  }

  /// Decodes every layer of [look] (used before screenshots and in tests).
  Future<void> precache(OutfitState look) async {
    final art = _art[look.characterId];
    if (art == null || _bundle == null) return;
    for (final p in layersFor(look, art)) {
      if (!_images.containsKey(p)) await _decode(p);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final i in _images.values) {
      i.dispose();
    }
    super.dispose();
  }
}

/// Draws [layers] stacked, scaled to fit [dst] (they share one canvas).
/// Returns false if any layer is still loading.
bool paintDollLayers(ui.Canvas canvas, ui.Rect dst, List<String> layers, DollLibrary lib) {
  var complete = true;
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
  for (final p in layers) {
    final img = lib.image(p);
    if (img == null) {
      complete = false;
      continue;
    }
    canvas.drawImageRect(
        img, ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, paint);
  }
  return complete;
}
