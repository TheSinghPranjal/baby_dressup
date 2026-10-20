import 'dart:io';
import 'dart:ui' as ui;

import 'package:baby_dressup/app.dart';
import 'package:baby_dressup/persistence/outfit_save_service.dart';
import 'package:baby_dressup/persistence/settings_service.dart';
import 'package:baby_dressup/wardrobe/catalog.dart';
import 'package:baby_dressup/wardrobe/garment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Set SCREENSHOT_DIR to dump PNGs of each screen for manual review.
final _shotDir = Platform.environment['SCREENSHOT_DIR'];

Future<void> _shot(WidgetTester tester, String name) async {
  if (_shotDir == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('app-root')));
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _tapCard(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.scrollUntilVisible(f, 150,
      scrollable: find.descendant(of: find.byType(GridView), matching: find.byType(Scrollable)).first);
  await tester.pump();
  await tester.tap(f);
}

Future<void> _tapTab(WidgetTester tester, String name) async {
  final f = find.byKey(Key('tab-$name'));
  await tester.scrollUntilVisible(f, 120,
      scrollable: find.descendant(of: find.byKey(const Key('closet-tabs')), matching: find.byType(Scrollable)).first);
  await tester.pump();
  await tester.tap(f);
}

Future<void> _frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory dir;
  late AppServices services;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('app');
    final saves = OutfitSaveService(() async => dir);
    final settings = SettingsService(() async => dir);
    services = AppServices(catalog: GarmentCatalog.starter(), saves: saves, settings: settings);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> boot(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await services.saves.load();
      await services.settings.load();
    });
    await tester.pumpWidget(RepaintBoundary(key: const Key('app-root'), child: DressUpApp(services: services)));
    await _frames(tester);
  }

  testWidgets('play flow: choose a character, dress her, save the look', (tester) async {
    await boot(tester, const Size(400, 860));
    await _shot(tester, '01_menu');

    await tester.tap(find.byKey(const Key('play')));
    await _frames(tester, 12);
    await _shot(tester, '02_select');

    // Swipe to the next character and pick her.
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await _frames(tester, 12);
    await tester.tap(find.byKey(const Key('select-character')));
    await _frames(tester, 12);
    final w = services.wardrobe;
    expect(w.state.characterId, 'ava');
    await _shot(tester, '03_dressing_room');

    // Tops tab is open: tap the hoodie card.
    await _tapCard(tester, 'card-top_hoodie');
    await _frames(tester);
    expect(w.state[GarmentSlot.top], 'top_hoodie');
    expect(w.state[GarmentSlot.bottom], 'bottom_pleated_skirt');

    // Change its colour.
    await tester.tap(find.byKey(const Key('variant-top_hoodie-1')));
    await _frames(tester);
    expect(w.state.variantOf(GarmentSlot.top), 1);

    // Dresses tab -> party dress.
    await _tapTab(tester, 'dresses');
    await _frames(tester);
    await _tapCard(tester, 'card-dress_party_tulle');
    await _frames(tester);
    expect(w.state[GarmentSlot.fullOutfit], 'dress_party_tulle');
    expect(w.state[GarmentSlot.top], isNull);
    await _shot(tester, '04_dress');

    // Accessories.
    await _tapTab(tester, 'accessories');
    await _frames(tester);
    await _tapCard(tester, 'card-head_sun_hat');
    await _frames(tester);
    expect(w.state[GarmentSlot.headwear], 'head_sun_hat');
    await _shot(tester, '05_accessories');

    // Pose and background.
    await tester.tap(find.byKey(const Key('open-poses')));
    await _frames(tester);
    await tester.tap(find.byKey(const Key('pose-hand_on_hip')));
    await _frames(tester);
    await tester.tap(find.byKey(const Key('open-backgrounds')));
    await _frames(tester);
    await tester.tap(find.byKey(const Key('bg-garden')));
    await _frames(tester, 14);
    expect(w.state.poseId, 'hand_on_hip');
    expect(w.state.backgroundId, 'garden');
    expect(w.state[GarmentSlot.fullOutfit], 'dress_party_tulle', reason: 'background keeps outfit');
    await _shot(tester, '06_garden_pose');

    // Save.
    await tester.tap(find.byKey(const Key('save-look')));
    await _frames(tester);
    await tester.enterText(find.byKey(const Key('look-name')), 'Garden party');
    await tester.tap(find.byKey(const Key('confirm-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await _frames(tester, 10);
    expect(services.saves.looks.single.name, 'Garden party');

    // Switch character, keeping the outfit.
    await tester.tap(find.byKey(const Key('character-switcher')));
    await _frames(tester);
    await tester.tap(find.byKey(const Key('switch-zara')));
    await _frames(tester, 12);
    expect(w.state.characterId, 'zara');
    expect(w.state[GarmentSlot.fullOutfit], 'dress_party_tulle');
    await _shot(tester, '07_switched');
  });

  testWidgets('tablet layout puts the closet beside the character', (tester) async {
    await boot(tester, const Size(1280, 800));
    await tester.tap(find.byKey(const Key('play')));
    await _frames(tester, 10);
    await tester.tap(find.byKey(const Key('select-character')));
    await _frames(tester, 12);
    await _tapTab(tester, 'hair');
    await _frames(tester);
    await _tapCard(tester, 'card-hair_space_buns');
    await _frames(tester);
    expect(services.wardrobe.state[GarmentSlot.hair], 'hair_space_buns');
    await _shot(tester, '08_tablet');
  });
}
