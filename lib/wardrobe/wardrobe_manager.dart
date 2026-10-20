import 'dart:async';

import 'package:flutter/foundation.dart';

import '../character/character_definition.dart';
import '../character/characters.dart';
import 'catalog.dart';
import 'garment.dart';
import 'outfit_state.dart';

enum EquipResult { equipped, removed, restoredDefault, unchanged, incompatible, locked, unknown }

/// Events the UI and animation layers react to (e.g. a happy hop).
sealed class WardrobeEvent {
  const WardrobeEvent();
}

class GarmentChanged extends WardrobeEvent {
  final GarmentSlot slot;
  final String? garmentId;
  const GarmentChanged(this.slot, this.garmentId);
}

class CharacterChanged extends WardrobeEvent {
  final String characterId;
  const CharacterChanged(this.characterId);
}

class EquipRejected extends WardrobeEvent {
  final String garmentId;
  final EquipResult reason;
  const EquipRejected(this.garmentId, this.reason);
}

class LookLoaded extends WardrobeEvent {
  final int missingItems;
  const LookLoaded(this.missingItems);
}

/// Central outfit manager. All slot conflict rules live here — closet
/// buttons only call [toggle] / [equip] / [remove].
class WardrobeManager extends ChangeNotifier {
  final GarmentCatalog catalog;
  final List<CharacterDefinition> characters;
  OutfitState _state;
  int savedLookCount;

  /// Extra availability check per character (e.g. paper-doll art exists).
  final bool Function(String characterId, GarmentDefinition g)? available;

  final _events = StreamController<WardrobeEvent>.broadcast();
  Stream<WardrobeEvent> get events => _events.stream;

  /// Required slots always hold something; removing restores the default.
  static const requiredSlots = {GarmentSlot.hair, GarmentSlot.shoes};

  WardrobeManager({
    required this.catalog,
    this.characters = kCharacters,
    String initialCharacter = 'mia',
    this.savedLookCount = 0,
    this.available,
  }) : _state = OutfitState(characterId: initialCharacter) {
    _state = _defaultsFor(character);
  }

  OutfitState get state => _state;

  CharacterDefinition get character => characters.firstWhere(
      (c) => c.id == _state.characterId,
      orElse: () => characters.first);

  CharacterDefinition? _characterById(String id) {
    for (final c in characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  GarmentDefinition? equippedIn(GarmentSlot slot) {
    final id = _state.items[slot];
    return id == null ? null : catalog.byId(id);
  }

  bool isLocked(GarmentDefinition g) => g.unlockAtSavedLooks > savedLookCount;

  bool canWear(GarmentDefinition g) => _fits(g, _state.characterId);

  bool _fits(GarmentDefinition g, String characterId) =>
      g.isCompatibleWith(characterId) && (available?.call(characterId, g) ?? true);

  // ---------------------------------------------------------------------------

  /// Tapping an item in the closet: wear it, or take it off if already worn.
  EquipResult toggle(String garmentId) {
    final g = catalog.byId(garmentId);
    if (g == null) return _reject(garmentId, EquipResult.unknown);
    if (_state.items[g.slot] == garmentId) return remove(g.slot);
    return equip(garmentId);
  }

  EquipResult equip(String garmentId, {int? variant}) {
    final g = catalog.byId(garmentId);
    if (g == null) return _reject(garmentId, EquipResult.unknown);
    if (!canWear(g)) return _reject(garmentId, EquipResult.incompatible);
    if (isLocked(g)) return _reject(garmentId, EquipResult.locked);

    final items = Map<GarmentSlot, String>.of(_state.items);
    final variants = Map<GarmentSlot, int>.of(_state.variants);

    switch (g.slot) {
      case GarmentSlot.top:
        if (items.remove(GarmentSlot.fullOutfit) != null) {
          _restore(items, variants, GarmentSlot.bottom, character);
        }
      case GarmentSlot.bottom:
        if (items.remove(GarmentSlot.fullOutfit) != null) {
          _restore(items, variants, GarmentSlot.top, character);
        }
      case GarmentSlot.fullOutfit:
        items.remove(GarmentSlot.top);
        items.remove(GarmentSlot.bottom);
        variants.remove(GarmentSlot.top);
        variants.remove(GarmentSlot.bottom);
      default:
        break;
    }
    // Generic layering rules declared on garments.
    for (final s in g.blocksSlots) {
      items.remove(s);
    }
    items.removeWhere((slot, id) => catalog.byId(id)?.blocksSlots.contains(g.slot) ?? false);

    final sameItem = _state.items[g.slot] == g.id;
    items[g.slot] = g.id;
    variants[g.slot] = (variant ?? (sameItem ? _state.variantOf(g.slot) : 0))
        .clamp(0, g.variants.length - 1);
    _set(_state.copyWith(items: items, variants: variants));
    _events.add(GarmentChanged(g.slot, g.id));
    return EquipResult.equipped;
  }

  /// Takes off whatever is in [slot]. Required pieces (top/bottom, hair,
  /// shoes) fall back to the character's default for that slot.
  EquipResult remove(GarmentSlot slot) {
    final current = _state.items[slot];
    if (current == null) return EquipResult.unchanged;
    final items = Map<GarmentSlot, String>.of(_state.items);
    final variants = Map<GarmentSlot, int>.of(_state.variants);
    final defaults = character.defaultOutfit;

    if (slot == GarmentSlot.fullOutfit) {
      items.remove(slot);
      variants.remove(slot);
      _restore(items, variants, GarmentSlot.top, character);
      _restore(items, variants, GarmentSlot.bottom, character);
      _set(_state.copyWith(items: items, variants: variants));
      _events.add(GarmentChanged(slot, null));
      return EquipResult.restoredDefault;
    }

    final needsDefault = requiredSlots.contains(slot) ||
        ((slot == GarmentSlot.top || slot == GarmentSlot.bottom) &&
            !items.containsKey(GarmentSlot.fullOutfit));
    if (needsDefault) {
      final def = defaults[slot.name];
      if (def == null || def == current || catalog.byId(def) == null) {
        return EquipResult.unchanged;
      }
      items[slot] = def;
      variants[slot] = character.defaultVariants[slot.name] ?? 0;
      _set(_state.copyWith(items: items, variants: variants));
      _events.add(GarmentChanged(slot, def));
      return EquipResult.restoredDefault;
    }

    items.remove(slot);
    variants.remove(slot);
    _set(_state.copyWith(items: items, variants: variants));
    _events.add(GarmentChanged(slot, null));
    return EquipResult.removed;
  }

  void setVariant(GarmentSlot slot, int index) {
    final g = equippedIn(slot);
    if (g == null) return;
    final v = Map<GarmentSlot, int>.of(_state.variants)
      ..[slot] = index.clamp(0, g.variants.length - 1);
    _set(_state.copyWith(variants: v));
    _events.add(GarmentChanged(slot, g.id));
  }

  void resetOutfit() {
    _set(_defaultsFor(character).copyWith(
        poseId: _state.poseId, backgroundId: _state.backgroundId));
    _events.add(CharacterChanged(_state.characterId));
  }

  /// Switches character. With [keepOutfit] compatible clothing carries over
  /// (the new character keeps her own hairstyle); otherwise she arrives in
  /// her signature outfit.
  void switchCharacter(String id, {bool keepOutfit = false}) {
    final c = _characterById(id);
    if (c == null) return;
    var next = _defaultsFor(c)
        .copyWith(poseId: _state.poseId, backgroundId: _state.backgroundId);
    if (keepOutfit) {
      final items = Map<GarmentSlot, String>.of(next.items);
      final variants = Map<GarmentSlot, int>.of(next.variants);
      final carried = Map<GarmentSlot, String>.of(_state.items)
        ..remove(GarmentSlot.hair);
      if (carried.containsKey(GarmentSlot.fullOutfit)) {
        items.remove(GarmentSlot.top);
        items.remove(GarmentSlot.bottom);
      }
      carried.forEach((slot, gid) {
        final g = catalog.byId(gid);
        if (g != null && _fits(g, c.id)) {
          items[slot] = gid;
          variants[slot] = _state.variantOf(slot);
        }
      });
      _ensureRequired(items, variants, c);
      next = next.copyWith(items: items, variants: variants);
    }
    _set(next);
    _events.add(CharacterChanged(id));
  }

  void setPose(String poseId) => _set(_state.copyWith(poseId: poseId));
  void setBackground(String id) => _set(_state.copyWith(backgroundId: id));

  /// Applies a saved look, skipping items that no longer exist or no longer
  /// fit. Returns how many items were skipped.
  int applyLook(OutfitState look) {
    final c = _characterById(look.characterId) ?? characters.first;
    final items = <GarmentSlot, String>{};
    final variants = <GarmentSlot, int>{};
    var missing = look.characterId == c.id ? 0 : 1;
    look.items.forEach((slot, gid) {
      final g = catalog.byId(gid);
      if (g == null || g.slot != slot || !_fits(g, c.id)) {
        missing++;
        return;
      }
      items[slot] = gid;
      variants[slot] = look.variantOf(slot).clamp(0, g.variants.length - 1);
    });
    if (items.containsKey(GarmentSlot.fullOutfit)) {
      items.remove(GarmentSlot.top);
      items.remove(GarmentSlot.bottom);
    }
    _ensureRequired(items, variants, c);
    _set(OutfitState(
      characterId: c.id,
      items: Map.unmodifiable(items),
      variants: Map.unmodifiable(variants),
      poseId: look.poseId,
      backgroundId: look.backgroundId,
    ));
    _events.add(CharacterChanged(c.id));
    _events.add(LookLoaded(missing));
    return missing;
  }

  // ---------------------------------------------------------------------------

  OutfitState _defaultsFor(CharacterDefinition c) {
    final items = <GarmentSlot, String>{};
    final variants = <GarmentSlot, int>{};
    for (final e in c.defaultOutfit.entries) {
      final slot = GarmentSlot.values.where((s) => s.name == e.key).firstOrNull;
      final g = catalog.byId(e.value);
      if (slot != null && g != null && g.slot == slot) {
        items[slot] = e.value;
        final v = c.defaultVariants[e.key];
        if (v != null) variants[slot] = v.clamp(0, g.variants.length - 1);
      }
    }
    return OutfitState(
        characterId: c.id,
        items: Map.unmodifiable(items),
        variants: Map.unmodifiable(variants));
  }

  void _restore(Map<GarmentSlot, String> items, Map<GarmentSlot, int> variants,
      GarmentSlot slot, CharacterDefinition c) {
    if (items.containsKey(slot)) return;
    final def = c.defaultOutfit[slot.name];
    final g = def == null ? null : catalog.byId(def);
    if (g != null) {
      items[slot] = def!;
      variants[slot] = (c.defaultVariants[slot.name] ?? 0).clamp(0, g.variants.length - 1);
    }
  }

  void _ensureRequired(Map<GarmentSlot, String> items,
      Map<GarmentSlot, int> variants, CharacterDefinition c) {
    for (final s in requiredSlots) {
      _restore(items, variants, s, c);
    }
    if (!items.containsKey(GarmentSlot.fullOutfit)) {
      _restore(items, variants, GarmentSlot.top, c);
      _restore(items, variants, GarmentSlot.bottom, c);
    }
  }

  EquipResult _reject(String id, EquipResult r) {
    _events.add(EquipRejected(id, r));
    return r;
  }

  void _set(OutfitState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }
}
