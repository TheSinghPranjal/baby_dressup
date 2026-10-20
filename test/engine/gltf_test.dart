import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:baby_dressup/engine/gltf.dart';
import 'package:baby_dressup/engine/math3d.dart';
import 'package:baby_dressup/engine/mesh.dart';
import 'package:baby_dressup/engine/renderer.dart';
import 'package:baby_dressup/models/mia_looks.dart';
import 'package:baby_dressup/models/mia_model_library.dart';
import 'package:baby_dressup/scene/character_assembler.dart';
import 'package:baby_dressup/scene/dressing_scene.dart';
import 'package:baby_dressup/wardrobe/catalog.dart';
import 'package:baby_dressup/wardrobe/garment.dart';
import 'package:baby_dressup/wardrobe/outfit_state.dart';
import 'package:baby_dressup/wardrobe/wardrobe_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every Mia GLB is a 1.0 whole-body mesh with an embedded texture',
    () async {
      for (final path in MiaLooks.allAssets) {
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final doc = parseGlb(bytes);
        expect(doc.primitives, hasLength(1), reason: path);
        final prim = doc.primitives.single;
        final mesh = prim.mesh;
        expect(
          mesh.triangleCount,
          inInclusiveRange(20000, 40000),
          reason: path,
        );
        expect(mesh.uvs, isNotNull, reason: path);
        expect(mesh.uvs!.length, mesh.vertexCount * 2, reason: path);
        expect(prim.imageBytes, isNotNull, reason: path);
        expect(prim.imageBytes!.length, greaterThan(10000), reason: path);
        final b = mesh.bounds();
        expect(b[0].y, closeTo(0, 0.002), reason: '$path feet');
        expect(b[1].y, closeTo(1, 0.002), reason: '$path height');
        expect(
          (b[0].x + b[1].x) * 0.5,
          closeTo(0, 0.03),
          reason: '$path x centre',
        );
        expect(
          (b[0].z + b[1].z) * 0.5,
          closeTo(0, 0.08),
          reason: '$path z centre',
        );
        for (var i = 0; i < mesh.positions.length; i += 97) {
          expect(mesh.positions[i], isNotNaN);
          expect(mesh.normals[i], isNotNaN);
        }
      }
    },
  );

  testWidgets('textured triangles sample the albedo the right way up', (
    tester,
  ) async {
    final image = await tester.runAsync(() => _swatch());
    final mesh = Mesh(
      Float32List.fromList(const [
        -0.55, -0.55, 0, //
        0.55, -0.55, 0, //
        0.55, 0.55, 0, //
        -0.55, 0.55, 0,
      ]),
      Float32List.fromList(const [
        0, 0, 1, //
        0, 0, 1, //
        0, 0, 1, //
        0, 0, 1,
      ]),
      Uint32List.fromList(const [0, 1, 2, 0, 2, 3]),
      null,
      // V = 0 is the top of the image, which is the green band.
      Float32List.fromList(const [0, 1, 1, 1, 1, 0, 0, 0]),
    );
    const size = ui.Size(240, 240);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()..color = const ui.Color(0xFFFF00FF),
    );
    SoftRenderer().render(
      canvas,
      size,
      OrbitCamera(distance: 2.4, targetY: 0, pitch: 0, fovY: 0.7),
      [
        RenderItem(
          mesh,
          Affine.identity,
          albedo: image,
          gloss: 0,
          color: 0xFFFFFFFF,
        ),
      ],
    );
    final png = await tester.runAsync(() async {
      final shot = await rec.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      return shot.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final bytes = png!.buffer.asUint8List();
    int at(int x, int y) {
      final i = (y * size.width.toInt() + x) * 4;
      return (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
    }

    final top = at(120, 70);
    final left = at(80, 160);
    final right = at(160, 160);
    expect(
      (top >> 8) & 255,
      greaterThan(140),
      reason: 'top band should be green, got ${_hex(top)}',
    );
    expect(
      (left >> 16) & 255,
      greaterThan((left) & 255),
      reason: 'lower left should be red, got ${_hex(left)}',
    );
    expect(
      right & 255,
      greaterThan((right >> 16) & 255),
      reason: 'lower right should be blue, got ${_hex(right)}',
    );
    image!.dispose();
  });

  testWidgets('Mia renders from the preloaded GLB on the dressing-room set', (
    tester,
  ) async {
    final lib = await tester.runAsync(() => MiaModelLibrary.load(rootBundle));
    expect(lib!.drives('mia'), isTrue);
    expect(
      lib.modelFor(_state(null))!.triangleCount,
      inInclusiveRange(20000, 40000),
    );

    final catalog = GarmentCatalog.starter();
    final w = WardrobeManager(catalog: catalog, initialCharacter: 'mia');
    final scene = DressingScene(CharacterAssembler(catalog), models: lib)
      ..show(w.state, w.character);
    const size = ui.Size(540, 960);
    final dir = Platform.environment['SCREENSHOT_DIR'];

    Future<ui.Image> frame() async {
      final rec = ui.PictureRecorder();
      scene.paint(ui.Canvas(rec), size);
      return rec.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
    }

    final first = await tester.runAsync(frame);
    expect(scene.triangleCount, greaterThan(8000));
    if (dir != null) {
      await _write(tester, first!, '$dir/mia_default.png');
      scene.animator.turntable = 2.6;
      final back = await tester.runAsync(frame);
      await _write(tester, back!, '$dir/mia_default_back.png');
      back.dispose();
      scene.animator.turntable = 0;
    }

    final sw = Stopwatch()..start();
    const frames = 20;
    for (var i = 0; i < frames; i++) {
      scene.tick(1 / 60);
      final rec = ui.PictureRecorder();
      scene.paint(ui.Canvas(rec), size);
      rec.endRecording().dispose();
    }
    final ms = sw.elapsedMicroseconds / frames / 1000;
    // ignore: avoid_print
    print(
      'mia glb: ${ms.toStringAsFixed(2)} ms/frame, ${scene.triangleCount} triangles',
    );
    // Debug is slower than a release build; this catches an accidental O(n^2) path.
    expect(ms, lessThan(40));
    first!.dispose();

    for (final entry in MiaLooks.topAssets.entries) {
      w.equip(entry.key);
      scene.show(w.state, w.character);
      // Let the cross-fade finish so the shot is the new top, not a blend.
      scene.tick(0.35);
      expect(scene.activeModelAsset, entry.value);
      final img = await tester.runAsync(frame);
      expect(scene.triangleCount, greaterThan(8000), reason: entry.key);
      if (dir != null) await _write(tester, img!, '$dir/mia_${entry.key}.png');
      img!.dispose();
    }
    scene.dispose();
    w.dispose();
    lib.dispose();
  });
}

OutfitState _state(String? top) => OutfitState(
  characterId: 'mia',
  items: {
    GarmentSlot.top: top ?? 'top_sport_tank',
    GarmentSlot.bottom: 'bottom_cargo',
  },
);

Future<ui.Image> _swatch() {
  const n = 32;
  final pixels = Uint8List(n * n * 4);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final i = (y * n + x) * 4;
      if (y < n ~/ 2) {
        pixels[i] = 0;
        pixels[i + 1] = 220;
        pixels[i + 2] = 40;
      } else if (x < n ~/ 2) {
        pixels[i] = 220;
        pixels[i + 1] = 30;
        pixels[i + 2] = 40;
      } else {
        pixels[i] = 30;
        pixels[i + 1] = 40;
        pixels[i + 2] = 220;
      }
      pixels[i + 3] = 255;
    }
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    n,
    n,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future;
}

String _hex(int rgb) => '#${rgb.toRadixString(16).padLeft(6, '0')}';

Future<void> _write(WidgetTester tester, ui.Image image, String path) async {
  final png = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}
