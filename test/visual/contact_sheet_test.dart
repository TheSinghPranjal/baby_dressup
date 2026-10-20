import 'dart:io';
import 'dart:ui' as ui;
import 'package:baby_dressup/character/characters.dart';
import 'package:baby_dressup/character/pose.dart';
import 'package:baby_dressup/engine/renderer.dart';
import 'package:baby_dressup/scene/character_assembler.dart';
import 'package:baby_dressup/wardrobe/catalog.dart';
import 'package:baby_dressup/wardrobe/garment.dart';
import 'package:baby_dressup/wardrobe/wardrobe_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders contact sheets of every character and catalogue category.
/// Run with SCREENSHOT_DIR=/some/dir to write PNGs; otherwise it only checks
/// that everything renders.
final out = Platform.environment['SCREENSHOT_DIR'];

Future<ui.Image> shot(List<RenderItem> items, OrbitCamera cam, ui.Size size) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.drawRect(ui.Offset.zero & size, ui.Paint()..color = const ui.Color(0xFFF6E8F0));
  SoftRenderer().render(canvas, size, cam, items);
  return rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
}

Future<void> sheet(String name, List<ui.Image> imgs, int w, int h) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  for (var i = 0; i < imgs.length; i++) {
    canvas.drawImage(imgs[i], ui.Offset((i * w).toDouble(), 0), ui.Paint());
  }
  final img = await rec.endRecording().toImage(w * imgs.length, h);
  if (out == null) return;
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  final catalog = GarmentCatalog.starter();
  final asm = CharacterAssembler(catalog);
  test('characters', () async {
    final imgs = <ui.Image>[];
    for (final c in kCharacters) {
      final w = WardrobeManager(catalog: catalog, initialCharacter: c.id);
      final anim = CharacterAnimator()..update(0.016);
      final items = CharacterAssembler.toRenderItems(asm.assemble(w.state, c), anim.solve());
      imgs.add(await shot(items, OrbitCamera(distance: 3.1), const ui.Size(260, 420)));
    }
    await sheet('chars', imgs, 260, 420);
    final faces = <ui.Image>[];
    for (final c in kCharacters) {
      final w = WardrobeManager(catalog: catalog, initialCharacter: c.id);
      final anim = CharacterAnimator()..update(0.016);
      final items = CharacterAssembler.toRenderItems(asm.assemble(w.state, c), anim.solve());
      faces.add(await shot(items, OrbitCamera(distance: 1.0, targetY: 1.4, pitch: 0.05), const ui.Size(260, 300)));
    }
    await sheet('faces', faces, 260, 300);
    // back + side views of aria and mia
    final views = <ui.Image>[];
    for (final id in ['aria', 'mia', 'sofia']) {
      final c = kCharacters.firstWhere((e) => e.id == id);
      final w = WardrobeManager(catalog: catalog, initialCharacter: id);
      for (final tt in [1.4, 3.14]) {
        final anim = CharacterAnimator()..update(0.016)..turntable = tt;
        final items = CharacterAssembler.toRenderItems(asm.assemble(w.state, c), anim.solve());
        views.add(await shot(items, OrbitCamera(distance: 3.1), const ui.Size(220, 420)));
      }
    }
    await sheet('views', views, 220, 420);
  });

  test('category sheets', () async {
    final c = kCharacters[0];
    for (final cat in GarmentCategory.values) {
      final imgs = <ui.Image>[];
      for (final g in catalog.inCategory(cat)) {
        final w = WardrobeManager(catalog: catalog, initialCharacter: c.id, savedLookCount: 9);
        if (!g.isCompatibleWith(c.id)) w.switchCharacter(g.compatibleCharacters.first);
        w.equip(g.id);
        final ch = kCharacters.firstWhere((e) => e.id == w.state.characterId);
        final anim = CharacterAnimator()..update(0.016)..turntable = 0.5;
        final items = CharacterAssembler.toRenderItems(asm.assemble(w.state, ch), anim.solve());
        final isHead = cat == GarmentCategory.hair || (cat == GarmentCategory.accessories && (g.slot == GarmentSlot.headwear || g.slot == GarmentSlot.earrings || g.slot == GarmentSlot.eyewear));
        final isFeet = cat == GarmentCategory.shoes;
        final cam = isHead ? OrbitCamera(distance: 1.3, targetY: 1.38) : isFeet ? OrbitCamera(distance: 1.0, targetY: 0.15, pitch: 0.3) : OrbitCamera(distance: 3.1);
        imgs.add(await shot(items, cam, const ui.Size(200, 320)));
      }
      await sheet('cat_${cat.name}', imgs, 200, 320);
    }
  });
}
