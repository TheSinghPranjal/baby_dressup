import 'dart:ui' as ui;

import 'package:baby_dressup/character/characters.dart';
import 'package:baby_dressup/engine/math3d.dart';
import 'package:baby_dressup/engine/primitives.dart';
import 'package:baby_dressup/engine/renderer.dart';
import 'package:baby_dressup/scene/character_assembler.dart';
import 'package:baby_dressup/scene/dressing_scene.dart';
import 'package:baby_dressup/scene/environment.dart';
import 'package:baby_dressup/wardrobe/catalog.dart';
import 'package:baby_dressup/wardrobe/wardrobe_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('back faces are culled', () {
    final r = SoftRenderer();
    final rec = ui.PictureRecorder();
    r.render(ui.Canvas(rec), const ui.Size(200, 200), OrbitCamera(distance: 3, targetY: 0),
        [RenderItem(Prim.sphere(0.5, segments: 16), Affine.identity)]);
    rec.endRecording();
    // Roughly half of a closed sphere faces the camera.
    final total = Prim.sphere(0.5, segments: 16).triangleCount;
    expect(r.lastTriangleCount, inInclusiveRange(total * 0.35, total * 0.65));
  });

  test('full dressing-room frame renders and reports its cost', () {
    final catalog = GarmentCatalog.starter();
    final asm = CharacterAssembler(catalog);
    for (final bg in kBackgrounds) {
      final w = WardrobeManager(catalog: catalog, initialCharacter: 'aria');
      final scene = DressingScene(asm)..show(w.state.copyWith(backgroundId: bg.id), kCharacters.last);
      const size = ui.Size(400, 600);
      // Warm up (mesh building, env picture).
      final warm = ui.PictureRecorder();
      scene.paint(ui.Canvas(warm), size);
      warm.endRecording();
      final sw = Stopwatch()..start();
      const frames = 30;
      for (var i = 0; i < frames; i++) {
        scene.tick(1 / 60);
        final rec = ui.PictureRecorder();
        scene.paint(ui.Canvas(rec), size);
        rec.endRecording().dispose();
      }
      final ms = sw.elapsedMicroseconds / frames / 1000;
      // ignore: avoid_print
      print('${bg.id}: ${ms.toStringAsFixed(2)} ms/frame, ${scene.triangleCount} character triangles');
      expect(scene.triangleCount, greaterThan(1000));
      scene.dispose();
      w.dispose();
    }
  });
}
