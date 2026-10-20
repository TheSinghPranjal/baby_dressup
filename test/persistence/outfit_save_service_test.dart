import 'dart:io';

import 'package:baby_dressup/persistence/outfit_save_service.dart';
import 'package:baby_dressup/wardrobe/garment.dart';
import 'package:baby_dressup/wardrobe/outfit_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('looks'));
  tearDown(() => dir.deleteSync(recursive: true));

  const look = OutfitState(
    characterId: 'ava',
    items: {GarmentSlot.fullOutfit: 'dress_party_tulle', GarmentSlot.hair: 'hair_long_waves'},
    variants: {GarmentSlot.fullOutfit: 2},
    poseId: 'happy',
    backgroundId: 'garden',
  );

  test('save, reload, rename and delete looks', () async {
    final a = OutfitSaveService(() async => dir);
    await a.load();
    expect(a.looks, isEmpty);
    final saved = await a.save(look, name: 'Party time');

    final b = OutfitSaveService(() async => dir);
    await b.load();
    expect(b.looks, hasLength(1));
    final l = b.looks.single;
    expect(l.name, 'Party time');
    expect(l.look.characterId, 'ava');
    expect(l.look[GarmentSlot.fullOutfit], 'dress_party_tulle');
    expect(l.look.variantOf(GarmentSlot.fullOutfit), 2);
    expect(l.look.poseId, 'happy');
    expect(l.look.backgroundId, 'garden');

    await b.rename(saved.id, 'Gala');
    await b.save(look);
    final c = OutfitSaveService(() async => dir);
    await c.load();
    expect(c.looks.map((e) => e.name), containsAll(['Gala', 'Look #2']));

    await c.delete(saved.id);
    final d = OutfitSaveService(() async => dir);
    await d.load();
    expect(d.looks, hasLength(1));
  });

  test('corrupt files and unknown slots are tolerated', () async {
    File('${dir.path}/${OutfitSaveService.fileName}').writeAsStringSync('{not json');
    final s = OutfitSaveService(() async => dir);
    await s.load();
    expect(s.looks, isEmpty);

    File('${dir.path}/${OutfitSaveService.fileName}').writeAsStringSync('''
      {"version":1,"looks":[
        {"id":"1","name":"ok","createdAt":"2026-01-01T00:00:00.000","look":
          {"characterId":"mia","items":{"top":"top_hoodie","jetpack":"x"},"variants":{"top":1}}},
        {"broken":true}
      ]}''');
    await s.load();
    expect(s.looks, hasLength(1));
    expect(s.looks.single.look.items, {GarmentSlot.top: 'top_hoodie'});
  });
}
