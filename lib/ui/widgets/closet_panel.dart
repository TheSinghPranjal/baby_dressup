import 'package:flutter/material.dart';

import '../../app.dart';
import '../../scene/character_assembler.dart';
import '../../wardrobe/garment.dart';
import '../../wardrobe/wardrobe_manager.dart';
import '../theme.dart';
import 'thumbnails.dart';

/// The virtual closet: category tabs, colour options and a garment grid.
/// It only forwards taps to the [WardrobeManager]; all rules live there.
class ClosetPanel extends StatelessWidget {
  final WardrobeManager wardrobe;
  final CharacterAssembler assembler;
  final GarmentCategory category;
  final ValueChanged<GarmentCategory> onCategory;
  final VoidCallback onReset;
  final GestureDragUpdateCallback? onDragHandle;

  const ClosetPanel({
    super.key,
    required this.wardrobe,
    required this.assembler,
    required this.category,
    required this.onCategory,
    required this.onReset,
    this.onDragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final available = wardrobe.available;
    final items = [
      for (final g in wardrobe.catalog.inCategory(category))
        if (available == null || available(wardrobe.state.characterId, g)) g,
    ];
    final equipped = [
      for (final g in items)
        if (wardrobe.state.items[g.slot] == g.id) g,
    ];
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Palette.lavender.withValues(alpha: 0.4),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: onDragHandle,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Palette.inkSoft.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              key: const Key('closet-tabs'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final c in GarmentCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('tab-${c.name}'),
                      label: Text('${c.emoji} ${c.label}'),
                      selected: c == category,
                      showCheckmark: false,
                      onSelected: (_) => onCategory(c),
                      selectedColor: Palette.pinkSoft,
                      side: BorderSide(color: c == category ? Palette.pink : Palette.lavenderSoft),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c == category ? Palette.pink : Palette.ink,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                TextButton.icon(
                  key: const Key('reset-outfit'),
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ),
          for (final g in equipped) _VariantStrip(garment: g, wardrobe: wardrobe),
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No ${category.label.toLowerCase()} for ${wardrobe.character.name} yet ✨',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Palette.inkSoft, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                key: PageStorageKey('closet-${category.name}'),
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 124,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.76,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => GarmentCard(
                  key: Key('card-${items[i].id}'),
                  garment: items[i],
                  wardrobe: wardrobe,
                  assembler: assembler,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VariantStrip extends StatelessWidget {
  final GarmentDefinition garment;
  final WardrobeManager wardrobe;
  const _VariantStrip({required this.garment, required this.wardrobe});

  @override
  Widget build(BuildContext context) {
    final shown =
        AppScope.maybeOf(context)?.dolls.variantsFor(wardrobe.character, garment) ??
        List.generate(garment.variants.length, (i) => i);
    if (shown.length < 2) return const SizedBox.shrink();
    final selected = wardrobe.state.variantOf(garment.slot);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          Center(
            child: Text(
              '${garment.name}: ',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.inkSoft, fontSize: 13),
            ),
          ),
          for (final i in shown)
            Tooltip(
              message: garment.variants[i].name,
              child: GestureDetector(
                key: Key('variant-${garment.id}-$i'),
                onTap: () => wardrobe.setVariant(garment.slot, i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  width: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _swatch(garment.variants[i], wardrobe),
                    border: Border.all(
                      color: i == selected ? Palette.pink : Colors.black12,
                      width: i == selected ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Gradient _swatch(ColorVariant v, WardrobeManager w) {
    final p = Color(v.natural ? w.character.hairColor : v.primary);
    final s = Color(v.natural ? w.character.hairColor : v.secondary);
    return SweepGradient(colors: [p, p, s, p]);
  }
}

class GarmentCard extends StatelessWidget {
  final GarmentDefinition garment;
  final WardrobeManager wardrobe;
  final CharacterAssembler assembler;

  const GarmentCard({super.key, required this.garment, required this.wardrobe, required this.assembler});

  @override
  Widget build(BuildContext context) {
    final on = wardrobe.state.items[garment.slot] == garment.id;
    final locked = wardrobe.isLocked(garment);
    final fits = wardrobe.canWear(garment);
    final variant = on ? wardrobe.state.variantOf(garment.slot) : 0;
    String? note;
    if (!fits) {
      note = 'Signature item';
    } else if (locked) {
      note = 'Save ${garment.unlockAtSavedLooks} look${garment.unlockAtSavedLooks == 1 ? '' : 's'}';
    }
    return Semantics(
      button: true,
      selected: on,
      label: '${garment.name}${on ? ', wearing' : ''}${note != null ? ', $note' : ''}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: on ? [Palette.pinkSoft, const Color(0xFFFFF1F7)] : [const Color(0xFFF8F4FF), Colors.white],
          ),
          border: Border.all(color: on ? Palette.pink : Palette.lavenderSoft, width: on ? 2.5 : 1.5),
          boxShadow: [
            if (on) BoxShadow(color: Palette.pink.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => wardrobe.toggle(garment.id),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Opacity(
                          opacity: (locked || !fits) ? 0.45 : 1,
                          child: GarmentThumbnail(
                            garment: garment,
                            variant: variant,
                            character: wardrobe.character,
                            assembler: assembler,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                      child: Text(
                        note ?? garment.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: note != null ? Palette.inkSoft : Palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                if (on)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: Palette.pink,
                      child: Icon(Icons.check_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                if (locked || !fits)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Icon(fits ? Icons.lock_rounded : Icons.star_rounded, size: 18, color: Palette.lavender),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
