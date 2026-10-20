# Glam Closet 3D

A mobile-first 3D fashion dress-up game for Android and iOS, built with Flutter.
Pick one of six teen characters, browse the closet, tap clothes and accessories
to dress her instantly, choose a pose and a background, save your favourite
looks and share a picture.

Characters, clothes and rooms are drawn by a small rendering engine in
`lib/engine/`. Five of the six characters, and every garment on them, are
still generated procedurally. **Mia in the dressing room** is the exception:
she is a set of textured GLB models in `assets/models/mia/` (about 8.2 MB).
The menu and the character select still use her paper-doll portrait.

## Features

- **6 characters** (Mia, Ava, Zara, Luna, Sofia, Aria). Each one has her own face, skin tone, eye colour, hair and signature outfit. They all share one skeleton, so every garment fits everyone. In the dressing room Mia is shown from pre-made GLB models instead of the procedural body (see below).
- **Closet with 8 tabs and 86 items:** 13 tops (including outerwear), 10 bottoms, 9 dresses/sets, 10 shoes, 9 hairstyles, 20 accessories, 8 bags and 7 extras (glasses, scarves, belts, socks). Most items come in several colours.
- **Slot rules in one place** (`WardrobeManager`):
  - Changing a top keeps the bottom, and changing a bottom keeps the top.
  - A dress clears the top and bottom.
  - Tapping something you're wearing takes it off. Tops, bottoms, hair and shoes fall back to the character's default; accessories are removed.
  - Signature items (Zara's jacket, Aria's gown) only fit their owner.
  - Some items unlock after you save a set number of looks.
- **Camera:** swipe to turn the character 360°, swipe up or down to orbit, pinch or press +/- to zoom, and double-tap to reset. There's also an auto-rotate toggle. Changing clothes doesn't move the camera. Mia's models have no skeleton, so the pose button is hidden for her; the turntable, zoom and the clothing-change hop still run.
- **Animation:**
  - Idle breathing and natural blinking.
  - A wave when a character arrives, and a little hop when she changes clothes.
  - A spin and confetti when you save a look.
  - Five poses: Casual, Hand on Hip, Peace Sign, Wave and Happy. Moving between poses blends smoothly.
- **Four 3D sets:** Pastel Studio, Bedroom Closet, City Studio and Garden Party. Changing the set keeps the outfit.
- **Saved looks:** stored as JSON in the app's documents folder. You can edit, rename or delete them. If a saved item no longer exists, it is skipped and the player is told.
- **Screenshot sharing:** captures the 3D view without the closet UI and opens the native share sheet.
- **Responsive layout:** on phones the closet is a resizable bottom panel. On tablets and in landscape it sits beside the character.

## Running

```bash
flutter pub get
flutter run            # pick an Android device/emulator or iOS simulator
flutter test           # unit, widget and render tests
```

To write contact sheets and UI screenshots for visual review:

```bash
SCREENSHOT_DIR=/tmp/shots flutter test test/visual test/widget
```

### Android build

```bash
flutter build apk --release        # or: flutter build appbundle --release
```

Set up release signing in `android/app/build.gradle.kts` before publishing.

### iOS build

```bash
cd ios && pod install && cd ..
flutter build ios --release
```

Open `ios/Runner.xcworkspace` in Xcode and choose a Team under *Signing & Capabilities*.
Sharing uses the system share sheet, so it needs no extra permissions or Info.plist keys.

## Mia's 3D models

Mia starts in `default.glb` (grey tee, grey knee-length shorts, pink sneakers). The Tops tab offers the four tops that have a model:

| Closet item | File |
|---|---|
| Everyday Tee (`top_basic_tee`) | `tee_white.glb` |
| Heart Graphic Tee (`top_heart_tee`) | `tee_heart.glb` |
| Comfy Hoodie (`top_hoodie`) | `hoodie.glb` |
| Denim Jacket (`outer_denim_jacket`) | `denim_jacket.glb` |

Tapping the worn top again restores her default outfit and the view returns to `default.glb`. The swap cross-fades in about 300ms; the camera stays put. All five files are decoded at startup and cached, so the swap does not hitch on disk.

Each file is a whole body (about 29k triangles, one 1024² texture, no rig). Tops that do not have a file are hidden in Mia's Tops tab. If a saved look still names one, the dressing room shows `default.glb` rather than a procedural tee. Other closet tabs keep the previous paper-doll filter (only items painted for her). They update the saved outfit but do not change the GLB until a matching file exists.

Bottoms are not separate yet. `MiaLooks.comboAssets` is the map for a future `(top, bottom)` pair: an entry keyed `topId|bottomId` wins over the top-only file. The jacket wins over the tee while both are worn, because that model already includes the shirt.

The other five characters, and every garment on them, stay procedural.

### APK size

The five GLBs are 8,218,128 bytes (~7.8 MiB) on disk. The textures are already PNG-compressed inside the GLB, so a release APK grows by about that much. They are not downloaded later; they ship in the asset bundle.

## Architecture

```
lib/
  engine/        math3d, Mesh, primitive generators, SoftRenderer, GLB loader
  models/        Mia's top → GLB map, preload cache, closet filter
  character/     skeleton (shared rig), body metrics, body/face builder,
                 character definitions, poses + CharacterAnimator
  wardrobe/      GarmentDefinition / GarmentSlot / ColorVariant, OutfitState,
                 WardrobeManager (all conflict rules), GarmentCatalog
    builders/    tops, bottoms, outfits, shoes, hair, accessories, bags, kit
  scene/         CharacterAssembler (parts, masking, LRU mesh cache),
                 DressingScene (camera, animation, cached backdrop), environment
  persistence/   OutfitSaveService (JSON looks), SettingsService
  services/      ScreenshotService (capture + share)
  ui/            screens (menu, character select, dressing room, saved looks,
                 settings) and widgets (viewport, closet panel, thumbnails)
```

Data flows one way. The closet UI calls `WardrobeManager.toggle/equip/remove`. The manager produces a new immutable `OutfitState` and broadcasts `WardrobeEvent`s. `DressingScene` re-assembles the parts and the UI reacts with hops, toasts and similar feedback.

### How the 3D works

- **Rendering:** `SoftRenderer` does the vertex work on the CPU: it transforms each vertex, lights it with Gouraud shading (key, fill, sky light and rim light, plus specular highlights for glossy materials) and culls back faces. It then depth-sorts the triangles with an O(n) bucket sort. The finished frame goes to Skia/Impeller as a single `drawVertices` call, which does the rasterisation on the GPU. A full dressing-room frame is roughly 14k visible triangles and took about 2 ms of CPU time in the test benchmark (`test/engine/renderer_test.dart`).
- **Rig and clothing:** every mesh is a `Part` bound to one bone of the shared skeleton, so clothing follows every pose and animation. Garments are authored against shared body measurements in `Body`, which is why they fit all characters.
  - **Masking:** garments list the body regions they cover (`hides`), and those regions are not drawn. This removes clipping and saves triangles. Hats use the same mechanism to hide top buns.
  - **Layering:** each layer has a depth bias (`Layer`), so a jacket always sorts above a top, which sorts above the body.
- **Painter's-algorithm caveat:** depth sorting happens per triangle, not per pixel. Very thin, intersecting layers can show small sorting artefacts at seams. Using decal sorting for facial features and the layer biases keeps this to a minimum.

## Honest limitations

- **Placeholder art:** five characters, their clothes and the room props are procedural placeholders built from primitives (lathes, ellipsoids, tubes). Mia's dressing-room body is a textured GLB; the menu portrait is still the paper doll.
- **No mesh blending at joints:** each clothing piece is attached rigidly to one bone, like a ball-jointed doll. Elbows and knees are covered with joint caps instead of blending the mesh between bones.
- **Prints are vertex-coloured:** fabric prints are painted onto mesh vertices, not textures, so small patterns look soft.
- **No audio.**

See [docs/ASSET_AUTHORING.md](docs/ASSET_AUTHORING.md) for adding items and replacing the placeholders with real models.
