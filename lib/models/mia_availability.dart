import '../doll/doll_art.dart';
import '../wardrobe/garment.dart';
import 'mia_looks.dart';
import 'mia_model_library.dart';

/// Closet filter used by [AppServices].
///
/// When Mia's GLBs loaded, the Tops tab offers only the four tops that have
/// a model. A top with no file would not change her picture (every GLB is a
/// whole body), so it is hidden rather than shown as a no-op. Every other
/// tab keeps the previous rule: paper-doll characters only see items that
/// have art, and everyone else keeps the full procedural closet.
///
/// Saved looks that still name an unmapped top are not deleted. The dressing
/// room shows [MiaLooks.defaultAsset] for them.
bool characterItemAvailable({
  required DollLibrary dolls,
  required MiaModelLibrary models,
  required String characterId,
  required GarmentDefinition garment,
}) {
  if (models.drives(characterId) && garment.category == GarmentCategory.tops) {
    return MiaLooks.isModelledTop(garment.id);
  }
  return dolls.supports(characterId, garment);
}
