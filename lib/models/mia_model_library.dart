import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/gltf.dart';
import '../engine/mesh.dart';
import '../wardrobe/outfit_state.dart';
import 'mia_looks.dart';

/// One drawable primitive: mesh plus its decoded albedo, if the file had one.
class GltfPrimitive {
  final Mesh mesh;
  final ui.Image? albedo;
  final int tint;
  final bool doubleSided;

  const GltfPrimitive(
    this.mesh,
    this.albedo,
    this.tint, {
    this.doubleSided = false,
  });
}

/// A parsed, texture-decoded GLB kept so outfit swaps do not hit the disk.
class GltfModel {
  final String assetPath;
  final List<GltfPrimitive> primitives;

  const GltfModel(this.assetPath, this.primitives);

  int get triangleCount {
    var n = 0;
    for (final p in primitives) {
      n += p.mesh.triangleCount;
    }
    return n;
  }
}

/// Loads and caches Mia's whole-body models.
///
/// [load] reads every file in [MiaLooks.allAssets] up front. The dressing
/// room then swaps by picking a cached [GltfModel]; it does not parse during
/// the cross-fade.
class MiaModelLibrary extends ChangeNotifier {
  final Map<String, GltfModel> _models;

  MiaModelLibrary._(this._models);

  /// No models: Mia keeps the paper-doll / procedural path.
  MiaModelLibrary.empty() : this._({});

  /// Injected models for tests. Keys are asset paths from [MiaLooks].
  MiaModelLibrary.test(Map<String, GltfModel> models)
    : _models = Map.of(models);

  /// True when Mia should be dressed from GLBs. Other characters are unchanged.
  bool drives(String characterId) =>
      characterId == MiaLooks.characterId &&
      _models.containsKey(MiaLooks.defaultAsset);

  /// The cached model for [state], or null when this character is not Mia
  /// (or the default file failed to load). A missing combo file falls back
  /// to [MiaLooks.defaultAsset] so the view never goes blank.
  GltfModel? modelFor(OutfitState state) {
    if (!drives(state.characterId)) return null;
    final path = MiaLooks.assetFor(state);
    return _models[path] ?? _models[MiaLooks.defaultAsset];
  }

  static Future<MiaModelLibrary> load(
    AssetBundle bundle, {
    List<String>? assets,
  }) async {
    final models = <String, GltfModel>{};
    for (final path in assets ?? MiaLooks.allAssets) {
      try {
        final data = await bundle.load(path);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        models[path] = await _decode(path, bytes);
      } catch (e, st) {
        debugPrint('Mia model $path failed to load: $e\n$st');
      }
    }
    return MiaModelLibrary._(models);
  }

  static Future<GltfModel> _decode(String path, Uint8List bytes) async {
    final doc = parseGlb(bytes);
    final primitives = <GltfPrimitive>[];
    for (final prim in doc.primitives) {
      ui.Image? image;
      final raw = prim.imageBytes;
      if (raw != null && raw.isNotEmpty) {
        final codec = await ui.instantiateImageCodec(raw);
        image = (await codec.getNextFrame()).image;
        codec.dispose();
      }
      primitives.add(
        GltfPrimitive(
          prim.mesh,
          image,
          prim.tint,
          doubleSided: prim.doubleSided,
        ),
      );
    }
    return GltfModel(path, primitives);
  }

  @override
  void dispose() {
    for (final model in _models.values) {
      for (final prim in model.primitives) {
        prim.albedo?.dispose();
      }
    }
    super.dispose();
  }
}
