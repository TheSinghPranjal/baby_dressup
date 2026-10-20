import 'dart:ui' as ui;

import 'package:baby_dressup/character/characters.dart';
import 'package:baby_dressup/doll/doll_art.dart';
import 'package:baby_dressup/engine/math3d.dart';
import 'package:baby_dressup/engine/mesh.dart';
import 'package:baby_dressup/models/mia_availability.dart';
import 'package:baby_dressup/models/mia_looks.dart';
import 'package:baby_dressup/models/mia_model_library.dart';
import 'package:baby_dressup/scene/character_assembler.dart';
import 'package:baby_dressup/scene/dressing_scene.dart';
import 'package:baby_dressup/wardrobe/catalog.dart';
import 'package:baby_dressup/wardrobe/garment.dart';
import 'package:baby_dressup/wardrobe/outfit_state.dart';
import 'package:baby_dressup/wardrobe/wardrobe_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = GarmentCatalog.starter();

  GltfModel stub(String path) {
    final mesh = Mesh.fromLists(
      const [Vec3(0, 0, 0), Vec3(0.2, 0, 0), Vec3(0, 0.4, 0.1)],
      [0, 1, 2],
    );
    return GltfModel(path, [GltfPrimitive(mesh, null, 0xFFFFFFFF)]);
  }

  MiaModelLibrary library() => MiaModelLibrary.test({
    for (final path in MiaLooks.allAssets) path: stub(path),
  });

  test(
    'each mapped top resolves to its GLB, and taking it off returns to default',
    () {
      final w = WardrobeManager(catalog: catalog, initialCharacter: 'mia');
      expect(w.state[GarmentSlot.top], 'top_sport_tank');
      expect(MiaLooks.assetFor(w.state), MiaLooks.defaultAsset);

      const expected = {
        'top_basic_tee': 'assets/models/mia/tee_white.glb',
        'top_heart_tee': 'assets/models/mia/tee_heart.glb',
        'top_hoodie': 'assets/models/mia/hoodie.glb',
        'outer_denim_jacket': 'assets/models/mia/denim_jacket.glb',
      };
      for (final entry in expected.entries) {
        expect(w.toggle(entry.key), EquipResult.equipped, reason: entry.key);
        expect(MiaLooks.assetFor(w.state), entry.value, reason: entry.key);
        final removed = w.toggle(entry.key);
        expect(removed, isNot(EquipResult.equipped), reason: entry.key);
        expect(
          MiaLooks.assetFor(w.state),
          MiaLooks.defaultAsset,
          reason: '${entry.key} toggled off',
        );
      }
    },
  );

  test(
    'outerwear wins over the tee, and a (top, bottom) combo wins over the top-only file',
    () {
      final w = WardrobeManager(catalog: catalog, initialCharacter: 'mia');
      w.toggle('top_heart_tee');
      w.toggle('outer_denim_jacket');
      expect(w.state[GarmentSlot.top], 'top_heart_tee');
      expect(w.state[GarmentSlot.outerwear], 'outer_denim_jacket');
      expect(
        MiaLooks.assetFor(w.state),
        MiaLooks.topAssets['outer_denim_jacket'],
      );

      w.toggle('outer_denim_jacket');
      expect(w.state[GarmentSlot.outerwear], isNull);
      expect(MiaLooks.assetFor(w.state), MiaLooks.topAssets['top_heart_tee']);

      final skirt = OutfitState(
        characterId: 'mia',
        items: const {
          GarmentSlot.top: 'top_hoodie',
          GarmentSlot.bottom: 'bottom_pleated_skirt',
        },
      );
      expect(MiaLooks.assetFor(skirt), MiaLooks.topAssets['top_hoodie']);
      expect(
        MiaLooks.assetFor(
          skirt,
          combos: const {
            'top_hoodie|bottom_pleated_skirt':
                'assets/models/mia/hoodie_skirt.glb',
          },
        ),
        'assets/models/mia/hoodie_skirt.glb',
      );
      // A combo for a different bottom does not steal the top-only file.
      expect(
        MiaLooks.assetFor(
          skirt,
          combos: const {
            'top_hoodie|bottom_flare_jeans':
                'assets/models/mia/hoodie_jeans.glb',
          },
        ),
        MiaLooks.topAssets['top_hoodie'],
      );
    },
  );

  test('unmapped tops are hidden for Mia only while her models are loaded', () {
    final models = library();
    final dolls = DollLibrary.empty();
    bool available(String id, GarmentDefinition g) => characterItemAvailable(
      dolls: dolls,
      models: models,
      characterId: id,
      garment: g,
    );

    final mia = WardrobeManager(
      catalog: catalog,
      initialCharacter: 'mia',
      available: available,
    );
    expect(mia.toggle('top_hoodie'), EquipResult.equipped);
    expect(mia.toggle('top_striped_tee'), EquipResult.incompatible);
    expect(mia.toggle('bottom_cargo'), isNot(EquipResult.incompatible));

    final ava = WardrobeManager(
      catalog: catalog,
      initialCharacter: 'ava',
      available: available,
    );
    expect(ava.toggle('top_striped_tee'), EquipResult.equipped);

    final bare = WardrobeManager(
      catalog: catalog,
      initialCharacter: 'mia',
      available: (id, g) => characterItemAvailable(
        dolls: dolls,
        models: MiaModelLibrary.empty(),
        characterId: id,
        garment: g,
      ),
    );
    expect(bare.toggle('top_striped_tee'), EquipResult.equipped);
  });

  test('swapping Mia\'s top cross-fades without moving the camera', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final w = WardrobeManager(catalog: catalog, initialCharacter: 'mia');
    final scene = DressingScene(
      CharacterAssembler(catalog),
      models: library(),
      showEnvironment: false,
    )..show(w.state, w.character);
    expect(scene.isModel, isTrue);
    expect(scene.isFlat, isFalse);
    expect(scene.activeModelAsset, MiaLooks.defaultAsset);

    scene.pitch = 0.33;
    scene.zoom = 1.7;
    scene.animator.turntable = 0.55;

    expect(w.toggle('top_hoodie'), EquipResult.equipped);
    scene.show(w.state, w.character);
    expect(scene.activeModelAsset, MiaLooks.topAssets['top_hoodie']);
    expect(scene.swapActive, isTrue);
    expect(scene.pitch, 0.33);
    expect(scene.zoom, 1.7);
    expect(scene.animator.turntable, 0.55);

    final rec = ui.PictureRecorder();
    scene.paint(ui.Canvas(rec), const ui.Size(180, 320));
    rec.endRecording().dispose();
    expect(scene.triangleCount, greaterThan(0));

    scene.tick(0.30);
    expect(scene.swapActive, isFalse);
    expect(scene.pitch, 0.33);
    expect(scene.animator.turntable, 0.55);

    expect(w.toggle('top_hoodie'), EquipResult.restoredDefault);
    scene.show(w.state, w.character);
    expect(scene.activeModelAsset, MiaLooks.defaultAsset);
    expect(scene.swapActive, isTrue);
    expect(w.state[GarmentSlot.top], 'top_sport_tank');

    // Another character never picks up Mia's models.
    w.switchCharacter('ava');
    scene.show(w.state, characterById('ava')!);
    expect(scene.isModel, isFalse);
    expect(scene.activeModelAsset, isNull);
    scene.dispose();
    w.dispose();
  });
}
