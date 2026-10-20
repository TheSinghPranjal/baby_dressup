import 'dart:io';
import 'dart:ui' as ui;

import 'package:baby_dressup/character/characters.dart';
import 'package:baby_dressup/doll/doll_art.dart';
import 'package:baby_dressup/scene/character_assembler.dart';
import 'package:baby_dressup/scene/dressing_scene.dart';
import 'package:baby_dressup/wardrobe/catalog.dart';
import 'package:baby_dressup/wardrobe/wardrobe_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Width and height from a PNG's IHDR chunk.
(int, int) _pngSize(ByteData d) => (d.getUint32(16), d.getUint32(20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = GarmentCatalog.starter();

  test('paper-doll art follows the folder conventions', () async {
    final assets = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
    final lib = await DollLibrary.load(rootBundle);
    for (final art in kDollArt) {
      expect(lib.artFor(art.characterId), isNotNull, reason: '${art.base} is missing');
      final c = characterById(art.characterId)!;
      for (final id in art.bakedIntoBase) {
        expect(catalog.byId(id), isNotNull, reason: 'baked $id is not in the catalogue');
        expect(c.defaultOutfit.values, contains(id), reason: 'baked $id is not in ${c.name}\'s default outfit');
      }
      final size = _pngSize(await rootBundle.load(art.base));
      for (final path in assets.where((a) => a.startsWith(art.folder))) {
        final name = path.substring(art.folder.length);
        expect(name, endsWith('.png'), reason: path);
        final garmentId = name.split('.').first;
        if (garmentId != 'base') {
          expect(catalog.byId(garmentId), isNotNull, reason: '$path: no garment "$garmentId"');
        }
        if (!name.endsWith('.icon.png')) {
          expect(_pngSize(await rootBundle.load(path)), size, reason: '$path must match base.png canvas');
        }
      }
    }
  });

  test('closet only offers items with art', () async {
    final lib = await DollLibrary.load(rootBundle);
    final w = WardrobeManager(catalog: catalog, available: lib.supports);
    final shown = [for (final g in catalog.items) if (w.canWear(g)) g.id];
    expect(shown, containsAll(kDollArt.first.bakedIntoBase));
    expect(w.toggle('top_hoodie'), isNot(EquipResult.equipped));
    // 3D characters keep the whole closet.
    w.switchCharacter('zara');
    expect(w.toggle('top_heart_tee'), EquipResult.equipped);
  });

  testWidgets('renders the paper doll on the set', (tester) async {
    final lib = await tester.runAsync(() => DollLibrary.load(rootBundle));
    final w = WardrobeManager(catalog: catalog, available: lib!.supports);
    await tester.runAsync(() => lib.precache(w.state));
    final scene = DressingScene(CharacterAssembler(catalog), dolls: lib)..show(w.state, w.character);
    expect(scene.isFlat, isTrue);
    final rec = ui.PictureRecorder();
    scene.paint(ui.Canvas(rec), const ui.Size(540, 960));
    final dir = Platform.environment['SCREENSHOT_DIR'];
    if (dir != null) {
      await tester.runAsync(() async {
        final img = await rec.endRecording().toImage(540, 960);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/doll_scene.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    scene.dispose();
  });
}
