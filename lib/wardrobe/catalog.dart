import 'builders/accessories.dart';
import 'builders/bags.dart';
import 'builders/bottoms.dart';
import 'builders/hair.dart';
import 'builders/outfits.dart';
import 'builders/shoes.dart';
import 'builders/tops.dart';
import 'garment.dart';

/// Registry of every closet item. New collections are added by appending
/// their definitions here; nothing else in the game needs to change.
class GarmentCatalog {
  final List<GarmentDefinition> items;
  final Map<String, GarmentDefinition> _byId;

  GarmentCatalog(this.items) : _byId = {for (final g in items) g.id: g} {
    assert(_byId.length == items.length, 'Duplicate garment ids');
  }

  factory GarmentCatalog.starter() => GarmentCatalog([
        ...buildTops(),
        ...buildBottoms(),
        ...buildOutfits(),
        ...buildShoes(),
        ...buildHair(),
        ...buildAccessories(),
        ...buildBags(),
        ...buildExtras(),
      ]);

  GarmentDefinition? byId(String id) => _byId[id];

  List<GarmentDefinition> inCategory(GarmentCategory c) =>
      [for (final g in items) if (g.category == c) g];
}
