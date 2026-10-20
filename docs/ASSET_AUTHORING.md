# Asset authoring guide

## Coordinate system and rig

- Units are roughly metres. The character stands on y = 0 and is about 1.6 tall. She faces **+Z**, and **+X** is her left side.
- Bones are listed in `lib/character/skeleton.dart` (`Bones`). Each mesh is authored in its **bone's local space**:
  - `spine` begins at the waist; the shoulders are at y ≈ 0.3.
  - `hips` sits at the pelvis centre.
  - Limb bones hang downward along −Y. The upper arm is 0.25 long and the thigh is 0.37.
  - `foot` sits at the ankle; the sole is at y ≈ −0.06.
  - `head` sits at the base of the skull; the face surface is described by `Body.faceSurface()`.
- Body measurements (`Body.torsoProfile`, `Body.thighR0`, …) are the shared fit standard. To build a garment that fits, inflate those profiles (`Kit.torso(grow: …)`, `Kit.legs`, `Kit.sleeves`, `Kit.skirt`).

## Adding a garment

1. Choose a builder file in `lib/wardrobe/builders/` (or create one and register it in `GarmentCatalog.starter()`).
2. Add a `GarmentDefinition` with these fields:

| field | purpose |
|---|---|
| `id` | unique and stable. Saved looks reference it, so never rename a shipped id. |
| `slot` | one of `GarmentSlot`. Defines which item it replaces. |
| `category` | the closet tab it appears in. |
| `variants` | one or more `ColorVariant`s (`primary`, `secondary`, `accent`). For hair, `natural: true` uses the character's own hair colour. |
| `hides` | body or hair tags this item fully covers, e.g. `BodyTags.torso` or `Kit.sleeveHides(len)`. |
| `compatibleCharacters` | empty means everyone. Otherwise the item is a signature piece for the listed characters. |
| `unlockAtSavedLooks` | locks the item until the player has saved this many looks. |
| `blocksSlots` | slots that cannot be worn together with this item. |
| `assetVersion` | bump this when the geometry changes. |
| `build` | `(GarmentBuildContext) → List<Part>`. Each `Part` gives a bone, a mesh, a colour, gloss and a layer bias. |

3. Use the layer constants in `Layer`. A garment that sits on top of another needs a larger `grow` **and** a larger bias.
4. Run `flutter test test/wardrobe/catalog_test.dart`. It builds every variant of every item and checks the bones, triangle counts and that no vertex is NaN.
5. Run `SCREENSHOT_DIR=/tmp/s flutter test test/visual` to see the new item on a character.

## Adding a character

Add a `CharacterDefinition` to `kCharacters`. Give her a skin tone, eye, hair, brow and lip colours, and a `FaceStyle` (eye size and tilt, brows, freckles, blush, smile). Also give her a `defaultOutfit` that covers at least `top`, `bottom`, `hair` and `shoes`. The catalogue test checks these entries.

## Mia's whole-body GLBs

`assets/models/mia/` holds one GLB per look. The loader is `lib/engine/gltf.dart`; the closet mapping is `lib/models/mia_looks.dart`.

- Y-up, facing +Z, feet at y = 0, 1.0 unit tall, centred on X/Z. The dressing room scales her by `MiaLooks.worldScale` (1.6) so she matches the other characters. Do not bake that scale into the file.
- One material, one embedded base-color image. No skeleton. A rigged file would be drawn in its bind pose.
- UVs use the glTF bottom-left origin; the loader flips V.

To add a top, export `some_top.glb` into that folder, add the path under `assets/models/mia/` (the directory entry in `pubspec.yaml` already includes it) and map the garment id in `MiaLooks.topAssets`.

To add a bottom later, do not replace the top-only file. Add a combo instead:

```dart
static const comboAssets = <String, String>{
  'top_hoodie|bottom_flare_jeans': 'assets/models/mia/hoodie_flare.glb',
};
```

`MiaLooks.assetFor` checks `topOrOuterId|bottomId` first, then the top-only file, then `default.glb`. Outerwear is chosen over the tee when both ids have a model.

Tops with no entry are hidden for Mia while the models are loaded. Other characters never consult this map.

## Replacing placeholders with real models

Gameplay code only deals with `Part`s: a mesh bound to a bone. To use real art:

1. In your DCC tool (Blender, Maya, …), model each garment piece on the shared rig and split it by the bone it should follow. The torso piece follows `spine`, the sleeve pieces follow `upperArm_L/R` and `forearm_L/R`, and so on.
2. Export every piece in bone-local space with the units and axes described above. Positions, normals and optional vertex colours are enough.
3. Write a loader for your chosen format (OBJ or glTF) that produces `Mesh(positions, normals, indices, colors)`. The `build` function can then return `Part`s made from the loaded meshes. Nothing in `WardrobeManager`, the closet UI, saving or the renderer needs to change.
4. Keep the `id`, slot and `hides` tags the same, so saved looks and masking keep working.

Procedural garments still use vertex colours. Textured meshes (Mia's GLBs) go through the same `SoftRenderer`: it depth-sorts triangles, then draws each run that shares an image with `ImageShader` and `Vertices.raw(textureCoordinates:)`, modulating the texture by a soft wrap light. UVs are stored on `Mesh.uvs` with V = 0 at the top of the image.

## Paper-doll (2D) characters

A character listed in `kDollArt` (`lib/doll/doll_art.dart`) whose `base.png` ships is drawn as a flat paper doll everywhere: on the menu, in the character select, in the dressing room, in saved looks and in the avatar. The other characters stay 3D. A paper doll stands on the same 3D set and keeps hops, spins and the camera zoom. It has one painted pose, so the turntable and pose picker are hidden for her.

Each character gets her own folder, `assets/doll/<characterId>/`, which is also listed under `assets:` in `pubspec.yaml`. **Every PNG in the folder has exactly the same pixel size as `base.png`.** Paint the layers on top of the base in your art tool and export each one with the rest of the canvas transparent, without cropping. The bottom edge of the canvas is the soles of the feet.

| file | what it is |
|---|---|
| `base.png` | the body. Drawn first. |
| `<garmentId>.png` | the garment in colour variant 0, e.g. `top_hoodie.png` |
| `<garmentId>.<n>.png` | colour variant *n* (matching `variants[n]` in the catalogue), e.g. `top_hoodie.2.png` |
| `<garmentId>.back.png` / `<garmentId>.<n>.back.png` | the part drawn **behind** the body, e.g. the back of long hair or a cape |
| `<garmentId>.icon.png` | optional closet icon (any size). Without it, the card shows the 3D thumbnail. |

- Layers are stacked in `kDollLayerOrder`: socks, shoes, bottom, top, full outfit, belt, outerwear, necklace, scarf, wrist, bag, hair, earrings, eyewear, headwear.
- The closet only offers items that have art for that character, and only colour variants that have their own file. Adding a PNG is enough; no code changes are needed.
- `bakedIntoBase` lists garments that are already painted into `base.png`. Mia's base is currently cut from her character sheet *with her signature outfit on*, so those five items are baked in and are the only ones in her closet. Once there is a bare base (a body in a plain bodysuit), replace `base.png`, add the five garments as layers and empty `bakedIntoBase`.
- `worldHeight` sets how tall the canvas is on the set (in metres; the 3D girls are about 1.6). `headRect` is the normalised face crop used for the avatar.
- Run `flutter test test/doll`. It checks that every file is named after a real garment and matches the size of `base.png`. `SCREENSHOT_DIR=/tmp/s flutter test test/doll` also writes `doll_scene.png`.

## Performance budget

- Aim for about 400–1,500 triangles per garment piece. The whole dressed character is about 14k triangles before back-face culling.
- Meshes are built once and cached (`CharacterAssembler`, an LRU cache of 160 entries). Backdrops are drawn once into a cached picture and only redrawn when the camera's pitch or zoom changes.
