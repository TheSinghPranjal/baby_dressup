import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'doll/doll_art.dart';
import 'models/mia_model_library.dart';
import 'persistence/outfit_save_service.dart';
import 'persistence/settings_service.dart';
import 'wardrobe/catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final saves = OutfitSaveService(getApplicationDocumentsDirectory);
  final settings = SettingsService(getApplicationDocumentsDirectory);
  final dolls = DollLibrary.load(rootBundle);
  final models = MiaModelLibrary.load(rootBundle);
  await Future.wait([saves.load(), settings.load()]);
  runApp(
    DressUpApp(
      services: AppServices(
        catalog: GarmentCatalog.starter(),
        saves: saves,
        settings: settings,
        dolls: await dolls,
        models: await models,
      ),
    ),
  );
}
