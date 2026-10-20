import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../wardrobe/outfit_state.dart';

/// A look the player saved from the dressing room.
class SavedLook {
  final String id;
  final String name;
  final OutfitState look;
  final DateTime createdAt;

  const SavedLook({
    required this.id,
    required this.name,
    required this.look,
    required this.createdAt,
  });

  SavedLook copyWith({String? name, OutfitState? look}) => SavedLook(
      id: id, name: name ?? this.name, look: look ?? this.look, createdAt: createdAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'look': look.toJson(),
      };

  static SavedLook? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return SavedLook(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'My Look',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        look: OutfitState.fromJson((json['look'] as Map).cast<String, dynamic>()),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Stores saved looks as JSON in the app's documents directory.
class OutfitSaveService extends ChangeNotifier {
  final Future<Directory> Function() directory;
  static const fileName = 'saved_looks.json';
  static const schemaVersion = 1;

  List<SavedLook> _looks = [];
  bool _loaded = false;

  OutfitSaveService(this.directory);

  List<SavedLook> get looks => List.unmodifiable(_looks);
  bool get isLoaded => _loaded;

  Future<File> _file() async => File('${(await directory()).path}/$fileName');

  Future<List<SavedLook>> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        final list = data is Map ? data['looks'] : data;
        _looks = [
          if (list is List)
            for (final e in list) ?SavedLook.tryParse(e),
        ];
      }
    } catch (e) {
      debugPrint('Could not read saved looks: $e');
      _looks = [];
    }
    _loaded = true;
    notifyListeners();
    return looks;
  }

  Future<SavedLook> save(OutfitState look, {String? name}) async {
    final now = DateTime.now();
    final saved = SavedLook(
      id: '${now.microsecondsSinceEpoch}',
      name: name ?? 'Look #${_looks.length + 1}',
      look: look,
      createdAt: now,
    );
    _looks = [saved, ..._looks];
    await _persist();
    return saved;
  }

  Future<void> update(SavedLook look) async {
    _looks = [for (final l in _looks) l.id == look.id ? look : l];
    await _persist();
  }

  Future<void> rename(String id, String name) async {
    final l = _looks.where((e) => e.id == id).firstOrNull;
    if (l != null) await update(l.copyWith(name: name.trim().isEmpty ? l.name : name.trim()));
  }

  Future<void> delete(String id) async {
    _looks = [for (final l in _looks) if (l.id != id) l];
    await _persist();
  }

  Future<void> _persist() async {
    notifyListeners();
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'version': schemaVersion,
      'looks': [for (final l in _looks) l.toJson()],
    }));
    await tmp.rename(f.path); // atomic replace
  }
}
