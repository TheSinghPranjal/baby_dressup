import 'package:baby_dressup/character/characters.dart';
import 'package:baby_dressup/character/pose.dart';
import 'package:baby_dressup/character/skeleton.dart';
import 'package:baby_dressup/scene/character_assembler.dart';
import 'package:baby_dressup/scene/environment.dart';
import 'package:baby_dressup/wardrobe/catalog.dart';
import 'package:baby_dressup/wardrobe/garment.dart';
import 'package:baby_dressup/wardrobe/outfit_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = GarmentCatalog.starter();

  test('starter content meets the minimum catalogue', () {
    int count(bool Function(GarmentDefinition) f) => catalog.items.where(f).length;
    expect(kCharacters.length, greaterThanOrEqualTo(6));
    expect(count((g) => g.category == GarmentCategory.tops), greaterThanOrEqualTo(12));
    expect(count((g) => g.category == GarmentCategory.bottoms), greaterThanOrEqualTo(10));
    expect(count((g) => g.slot == GarmentSlot.fullOutfit), greaterThanOrEqualTo(8));
    expect(count((g) => g.slot == GarmentSlot.hair), greaterThanOrEqualTo(8));
    expect(count((g) => g.slot == GarmentSlot.shoes), greaterThanOrEqualTo(10));
    expect(count((g) => g.category == GarmentCategory.accessories), greaterThanOrEqualTo(20));
    expect(count((g) => g.category == GarmentCategory.bags), greaterThanOrEqualTo(8));
    expect(kBackgrounds.length, greaterThanOrEqualTo(4));
    expect(kPoses.length, greaterThanOrEqualTo(5));
  });

  test('ids are unique and every item has a colour variant', () {
    final ids = catalog.items.map((g) => g.id).toSet();
    expect(ids.length, catalog.items.length);
    for (final g in catalog.items) {
      expect(g.variants, isNotEmpty, reason: g.id);
    }
  });

  test('character defaults reference real items in the right slot', () {
    for (final c in kCharacters) {
      for (final e in c.defaultOutfit.entries) {
        final g = catalog.byId(e.value);
        expect(g, isNotNull, reason: '${c.id}: ${e.value}');
        expect(g!.slot.name, e.key, reason: '${c.id}: ${e.value}');
      }
      for (final req in ['top', 'bottom', 'hair', 'shoes']) {
        expect(c.defaultOutfit[req], isNotNull, reason: '${c.id} needs a default $req');
      }
    }
  });

  test('every garment builds non-empty meshes bound to real bones', () {
    final asm = CharacterAssembler(catalog);
    for (final g in catalog.items) {
      for (var v = 0; v < g.variants.length; v++) {
        final c = g.compatibleCharacters.isEmpty
            ? kCharacters[v % kCharacters.length]
            : characterById(g.compatibleCharacters.first)!;
        final parts = asm.garment(g, v, c);
        expect(parts, isNotEmpty, reason: '${g.id}#$v');
        for (final p in parts) {
          expect(Skeleton.names, contains(p.bone), reason: g.id);
          expect(p.mesh.triangleCount, greaterThan(0), reason: g.id);
          for (final x in p.mesh.positions) {
            expect(x.isFinite, isTrue, reason: '${g.id} has a NaN vertex');
          }
        }
      }
    }
    expect(asm.failed, isEmpty);
  });

  test('garments hide the body regions they cover', () {
    final asm = CharacterAssembler(catalog);
    final c = kCharacters.first;
    final w = asm.assemble(
        const OutfitStateFixture().withItems({GarmentSlot.top: 'top_cozy_sweater', GarmentSlot.bottom: 'bottom_skinny_jeans', GarmentSlot.hair: 'hair_pixie', GarmentSlot.shoes: 'shoes_ankle_boots'}),
        c);
    final tags = w.map((p) => p.tag).toSet();
    expect(tags, isNot(contains('torso')));
    expect(tags, isNot(contains('forearm_L')));
    expect(tags, isNot(contains('thigh_R')));
    expect(tags, isNot(contains('foot_L')));
    expect(tags, contains('head'));
  });

  test('hats hide top buns', () {
    final asm = CharacterAssembler(catalog);
    final c = kCharacters.first;
    final base = {GarmentSlot.top: 'top_basic_tee', GarmentSlot.bottom: 'bottom_joggers', GarmentSlot.hair: 'hair_top_bun', GarmentSlot.shoes: 'shoes_slides'};
    final without = asm.assemble(const OutfitStateFixture().withItems(base), c);
    final withHat = asm.assemble(const OutfitStateFixture().withItems({...base, GarmentSlot.headwear: 'head_beanie'}), c);
    expect(without.where((p) => p.tag == 'hairTop'), isNotEmpty);
    expect(withHat.where((p) => p.tag == 'hairTop'), isEmpty);
  });
}

class OutfitStateFixture {
  const OutfitStateFixture();
  OutfitState withItems(Map<GarmentSlot, String> items) =>
      OutfitState(characterId: 'mia', items: items);
}
