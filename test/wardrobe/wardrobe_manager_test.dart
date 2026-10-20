import 'package:baby_dressup/character/character_definition.dart';
import 'package:baby_dressup/character/characters.dart';
import 'package:baby_dressup/wardrobe/catalog.dart';
import 'package:baby_dressup/wardrobe/garment.dart';
import 'package:baby_dressup/wardrobe/outfit_state.dart';
import 'package:baby_dressup/wardrobe/wardrobe_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = GarmentCatalog.starter();
  late WardrobeManager w;

  setUp(() => w = WardrobeManager(catalog: catalog, initialCharacter: 'mia'));
  tearDown(() => w.dispose());

  test('starts in the character default outfit', () {
    expect(w.state[GarmentSlot.top], 'top_sport_tank');
    expect(w.state[GarmentSlot.bottom], 'bottom_cargo');
    expect(w.state[GarmentSlot.hair], 'hair_messy_bun');
  });

  test('default colour variants apply and are restored', () {
    expect(w.state.variantOf(GarmentSlot.bottom), 4, reason: 'Mia wears lavender cargos');
    w.equip('bottom_skinny_jeans');
    w.toggle('bottom_skinny_jeans');
    expect(w.state[GarmentSlot.bottom], 'bottom_cargo');
    expect(w.state.variantOf(GarmentSlot.bottom), 4);
  });

  test('selecting a top keeps the bottom, hair and accessories', () {
    expect(w.equip('top_hoodie'), EquipResult.equipped);
    expect(w.state[GarmentSlot.top], 'top_hoodie');
    expect(w.state[GarmentSlot.bottom], 'bottom_cargo');
    expect(w.state[GarmentSlot.hair], 'hair_messy_bun');
    expect(w.state[GarmentSlot.wrist], 'wrist_smart_watch');
  });

  test('selecting a bottom keeps the top', () {
    w.equip('top_striped_tee');
    w.equip('bottom_pleated_skirt');
    expect(w.state[GarmentSlot.top], 'top_striped_tee');
    expect(w.state[GarmentSlot.bottom], 'bottom_pleated_skirt');
  });

  test('a full outfit clears top and bottom but keeps shoes, hair, accessories', () {
    w.equip('ear_pearl_studs');
    w.equip('dress_party_tulle');
    expect(w.state[GarmentSlot.fullOutfit], 'dress_party_tulle');
    expect(w.state[GarmentSlot.top], isNull);
    expect(w.state[GarmentSlot.bottom], isNull);
    expect(w.state[GarmentSlot.shoes], 'shoes_chunky_trainers');
    expect(w.state[GarmentSlot.hair], 'hair_messy_bun');
    expect(w.state[GarmentSlot.earrings], 'ear_pearl_studs');
  });

  test('a top over a dress removes the dress and restores the default bottom', () {
    w.equip('dress_summer_sun');
    w.equip('top_basic_tee');
    expect(w.state[GarmentSlot.fullOutfit], isNull);
    expect(w.state[GarmentSlot.top], 'top_basic_tee');
    expect(w.state[GarmentSlot.bottom], 'bottom_cargo');
  });

  test('outerwear layers over a full outfit', () {
    w.equip('dress_tee_dress');
    w.equip('outer_denim_jacket');
    expect(w.state[GarmentSlot.fullOutfit], 'dress_tee_dress');
    expect(w.state[GarmentSlot.outerwear], 'outer_denim_jacket');
  });

  test('removing a required item restores the character default', () {
    w.equip('top_hoodie');
    expect(w.toggle('top_hoodie'), EquipResult.restoredDefault);
    expect(w.state[GarmentSlot.top], 'top_sport_tank');
    // The default itself cannot be removed (she always wears a top).
    expect(w.toggle('top_sport_tank'), EquipResult.unchanged);
    expect(w.state[GarmentSlot.top], 'top_sport_tank');

    w.equip('hair_pixie');
    w.remove(GarmentSlot.hair);
    expect(w.state[GarmentSlot.hair], 'hair_messy_bun');
  });

  test('removing a full outfit restores default top and bottom', () {
    w.equip('dress_floral_maxi');
    w.remove(GarmentSlot.fullOutfit);
    expect(w.state[GarmentSlot.top], 'top_sport_tank');
    expect(w.state[GarmentSlot.bottom], 'bottom_cargo');
  });

  test('accessories can be removed entirely', () {
    w.equip('neck_heart_pendant');
    expect(w.toggle('neck_heart_pendant'), EquipResult.removed);
    expect(w.state[GarmentSlot.necklace], isNull);
    expect(w.toggle('wrist_smart_watch'), EquipResult.removed);
    expect(w.state[GarmentSlot.wrist], isNull);
  });

  test('incompatible garments are rejected', () async {
    final events = <WardrobeEvent>[];
    final sub = w.events.listen(events.add);
    w.savedLookCount = 10;
    expect(w.equip('outer_zara_signature'), EquipResult.incompatible);
    expect(w.state[GarmentSlot.outerwear], isNull);
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<EquipRejected>().single.reason, EquipResult.incompatible);
    await sub.cancel();

    w.switchCharacter('zara');
    expect(w.equip('outer_zara_signature'), EquipResult.equipped);
  });

  test('locked garments unlock after saving looks', () {
    w.switchCharacter('zara');
    w.savedLookCount = 0;
    expect(w.equip('outer_zara_signature'), EquipResult.locked);
    w.savedLookCount = 1;
    expect(w.equip('outer_zara_signature'), EquipResult.equipped);
  });

  test('unknown garment ids are handled', () {
    expect(w.equip('does_not_exist'), EquipResult.unknown);
    expect(w.toggle('does_not_exist'), EquipResult.unknown);
  });

  test('switching characters loads her defaults, or keeps the outfit', () {
    w.equip('top_hoodie');
    w.equip('bottom_pleated_skirt', variant: 2);
    w.switchCharacter('ava');
    expect(w.state.characterId, 'ava');
    expect(w.state[GarmentSlot.top], 'top_puff_blouse');

    w.equip('top_hoodie');
    w.switchCharacter('luna', keepOutfit: true);
    expect(w.state[GarmentSlot.top], 'top_hoodie');
    expect(w.state[GarmentSlot.bottom], 'bottom_pleated_skirt');
    expect(w.state[GarmentSlot.hair], 'hair_chin_bob', reason: 'hair stays with the character');
  });

  test('keepOutfit drops items the new character cannot wear', () {
    w.switchCharacter('zara');
    w.savedLookCount = 5;
    w.equip('outer_zara_signature');
    w.switchCharacter('mia', keepOutfit: true);
    expect(w.state[GarmentSlot.outerwear], isNull);
  });

  test('colour variants are clamped and preserved', () {
    w.equip('top_basic_tee', variant: 99);
    final g = catalog.byId('top_basic_tee')!;
    expect(w.state.variantOf(GarmentSlot.top), g.variants.length - 1);
    w.setVariant(GarmentSlot.top, 1);
    expect(w.state.variantOf(GarmentSlot.top), 1);
  });

  test('applyLook restores a look and skips missing assets', () {
    const look = OutfitState(
      characterId: 'sofia',
      items: {
        GarmentSlot.top: 'top_turtleneck',
        GarmentSlot.bottom: 'removed_item',
        GarmentSlot.bag: 'bag_tote',
        GarmentSlot.shoes: 'top_hoodie', // wrong slot
      },
      variants: {GarmentSlot.top: 2},
      poseId: 'peace',
      backgroundId: 'garden',
    );
    final missing = w.applyLook(look);
    expect(missing, 2);
    expect(w.state.characterId, 'sofia');
    expect(w.state[GarmentSlot.top], 'top_turtleneck');
    expect(w.state.variantOf(GarmentSlot.top), 2);
    expect(w.state[GarmentSlot.bag], 'bag_tote');
    expect(w.state[GarmentSlot.bottom], 'bottom_aline_skirt', reason: 'falls back to default');
    expect(w.state[GarmentSlot.shoes], 'shoes_mary_janes');
    expect(w.state.poseId, 'peace');
    expect(w.state.backgroundId, 'garden');
  });

  test('applyLook with an unknown character falls back safely', () {
    final missing = w.applyLook(const OutfitState(characterId: 'ghost'));
    expect(missing, 1);
    expect(kCharacters.map((CharacterDefinition c) => c.id), contains(w.state.characterId));
    expect(w.state[GarmentSlot.top], isNotNull);
  });

  test('reset restores the signature outfit but keeps pose and background', () {
    w.setPose('wave');
    w.setBackground('garden');
    w.equip('dress_party_tulle');
    w.resetOutfit();
    expect(w.state[GarmentSlot.top], 'top_sport_tank');
    expect(w.state[GarmentSlot.fullOutfit], isNull);
    expect(w.state.poseId, 'wave');
    expect(w.state.backgroundId, 'garden');
  });
}
