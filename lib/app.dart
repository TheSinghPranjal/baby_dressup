import 'package:flutter/material.dart';

import 'doll/doll_art.dart';
import 'models/mia_availability.dart';
import 'models/mia_model_library.dart';
import 'persistence/outfit_save_service.dart';
import 'persistence/settings_service.dart';
import 'scene/character_assembler.dart';
import 'ui/screens/main_menu_screen.dart';
import 'ui/theme.dart';
import 'wardrobe/catalog.dart';
import 'wardrobe/garment.dart';
import 'wardrobe/wardrobe_manager.dart';

/// Long-lived services shared by every screen.
class AppServices {
  final GarmentCatalog catalog;
  final CharacterAssembler assembler;
  final WardrobeManager wardrobe;
  final OutfitSaveService saves;
  final SettingsService settings;
  final DollLibrary dolls;
  final MiaModelLibrary models;

  AppServices({
    required this.catalog,
    required this.saves,
    required this.settings,
    DollLibrary? dolls,
    MiaModelLibrary? models,
  }) : dolls = dolls ?? DollLibrary.empty(),
       models = models ?? MiaModelLibrary.empty(),
       assembler = CharacterAssembler(catalog),
       wardrobe = WardrobeManager(
         catalog: catalog,
         available: _availability(
           dolls ?? DollLibrary.empty(),
           models ?? MiaModelLibrary.empty(),
         ),
       ) {
    wardrobe.savedLookCount = saves.looks.length;
    saves.addListener(() => wardrobe.savedLookCount = saves.looks.length);
  }

  static bool Function(String, GarmentDefinition) _availability(
    DollLibrary dolls,
    MiaModelLibrary models,
  ) {
    return (id, g) => characterItemAvailable(
      dolls: dolls,
      models: models,
      characterId: id,
      garment: g,
    );
  }
}

class AppScope extends InheritedWidget {
  final AppServices services;
  const AppScope({super.key, required this.services, required super.child});

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;

  static AppServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

class DressUpApp extends StatelessWidget {
  final AppServices services;
  const DressUpApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'Glam Closet 3D',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const MainMenuScreen(),
      ),
    );
  }
}
