import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Small JSON-backed settings store.
class SettingsService extends ChangeNotifier {
  final Future<Directory> Function() directory;
  bool autoRotate = false;
  bool showBackground = true;
  bool reduceMotion = false;
  bool keepOutfitOnSwitch = true;

  SettingsService(this.directory);

  Future<File> _file() async => File('${(await directory()).path}/settings.json');

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        autoRotate = m['autoRotate'] as bool? ?? autoRotate;
        showBackground = m['showBackground'] as bool? ?? showBackground;
        reduceMotion = m['reduceMotion'] as bool? ?? reduceMotion;
        keepOutfitOnSwitch = m['keepOutfitOnSwitch'] as bool? ?? keepOutfitOnSwitch;
      }
    } catch (e) {
      debugPrint('Could not read settings: $e');
    }
    notifyListeners();
  }

  Future<void> update({bool? autoRotate, bool? showBackground, bool? reduceMotion, bool? keepOutfitOnSwitch}) async {
    this.autoRotate = autoRotate ?? this.autoRotate;
    this.showBackground = showBackground ?? this.showBackground;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    this.keepOutfitOnSwitch = keepOutfitOnSwitch ?? this.keepOutfitOnSwitch;
    notifyListeners();
    try {
      await (await _file()).writeAsString(jsonEncode({
        'autoRotate': this.autoRotate,
        'showBackground': this.showBackground,
        'reduceMotion': this.reduceMotion,
        'keepOutfitOnSwitch': this.keepOutfitOnSwitch,
      }));
    } catch (e) {
      debugPrint('Could not write settings: $e');
    }
  }
}
