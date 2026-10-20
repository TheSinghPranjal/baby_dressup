import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../character/characters.dart';
import '../../character/pose.dart';
import '../../persistence/outfit_save_service.dart';
import '../../scene/dressing_scene.dart';
import '../../scene/environment.dart';
import '../../services/screenshot_service.dart';
import '../../wardrobe/garment.dart';
import '../../wardrobe/wardrobe_manager.dart';
import '../theme.dart';
import '../widgets/character_viewport.dart';
import '../widgets/closet_panel.dart';
import '../widgets/confetti.dart';
import '../widgets/thumbnails.dart';

class DressingRoomScreen extends StatefulWidget {
  /// Wave hello on arrival.
  final bool greet;

  /// When editing a saved look, saving offers to update it.
  final SavedLook? editing;

  const DressingRoomScreen({super.key, this.greet = false, this.editing});

  @override
  State<DressingRoomScreen> createState() => _DressingRoomScreenState();
}

class _DressingRoomScreenState extends State<DressingRoomScreen> {
  late AppServices _s;
  DressingScene? _scene;
  StreamSubscription<WardrobeEvent>? _sub;
  GarmentCategory _category = GarmentCategory.tops;
  double _panelFraction = 0.42;
  final _captureKey = GlobalKey();
  final _shareKey = GlobalKey();
  final _confetti = GlobalKey<ConfettiBurstState>();
  SavedLook? _editing;

  WardrobeManager get _w => _s.wardrobe;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scene != null) return;
    _s = AppScope.of(context);
    _editing = widget.editing;
    _scene = DressingScene(_s.assembler, dolls: _s.dolls, showEnvironment: _s.settings.showBackground)
      ..autoRotate = _s.settings.autoRotate;
    _scene!.show(_w.state, _w.character);
    if (widget.greet) _scene!.animator.waveHello();
    _w.addListener(_onWardrobe);
    _sub = _w.events.listen(_onEvent);
  }

  void _onWardrobe() {
    _scene!.show(_w.state, _w.character);
    if (mounted) setState(() {});
  }

  void _onEvent(WardrobeEvent e) {
    switch (e) {
      case GarmentChanged():
        if (!_s.settings.reduceMotion) _scene!.animator.react();
      case CharacterChanged():
        if (!_s.settings.reduceMotion) _scene!.animator.waveHello();
      case EquipRejected(:final garmentId, :final reason):
        final g = _w.catalog.byId(garmentId);
        final msg = switch (reason) {
          EquipResult.incompatible =>
            '${g?.name ?? 'This item'} is a signature piece for ${_ownerNames(g)}.',
          EquipResult.locked =>
            'Save ${g?.unlockAtSavedLooks} look${g?.unlockAtSavedLooks == 1 ? '' : 's'} to unlock ${g?.name}!',
          _ => 'That item is not available right now.',
        };
        _toast(msg);
      case LookLoaded(:final missingItems):
        if (missingItems > 0) {
          _toast('$missingItems item${missingItems == 1 ? '' : 's'} from this look are no longer available.');
        }
    }
  }

  String _ownerNames(GarmentDefinition? g) => g == null
      ? 'someone else'
      : [for (final id in g.compatibleCharacters) characterById(id)?.name ?? id].join(' & ');

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  void dispose() {
    _w.removeListener(_onWardrobe);
    _sub?.cancel();
    _scene?.dispose();
    super.dispose();
  }

  // --- Actions ---------------------------------------------------------------

  Future<void> _save() async {
    final c = _w.character;
    final controller = TextEditingController(
        text: _editing?.name ?? "${c.name}'s look #${_s.saves.looks.where((l) => l.look.characterId == c.id).length + 1}");
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Save this look 💖'),
        content: TextField(
          key: const Key('look-name'),
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (_editing != null)
            TextButton(onPressed: () => Navigator.pop(ctx, 'new'), child: const Text('Save as new')),
          FilledButton(
            key: const Key('confirm-save'),
            onPressed: () => Navigator.pop(ctx, _editing != null ? 'update' : 'new'),
            child: Text(_editing != null ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final name = controller.text.trim().isEmpty ? null : controller.text.trim();
    if (choice == 'update' && _editing != null) {
      final updated = _editing!.copyWith(name: name, look: _w.state);
      await _s.saves.update(updated);
      _editing = updated;
    } else {
      _editing = await _s.saves.save(_w.state, name: name);
    }
    _w.savedLookCount = _s.saves.looks.length;
    if (!_s.settings.reduceMotion) _scene!.animator.celebrate();
    _confetti.currentState?.fire();
    if (mounted) setState(() {});
    _toast('Look saved to your collection!');
  }

  Future<void> _share() async {
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final err = await ScreenshotService.captureAndShare(_captureKey,
        caption: 'My ${_w.character.name} look from Glam Closet 3D ✨', origin: origin);
    if (err != null && mounted) _toast(err);
  }

  void _pickPose() => _sheet(
        'Pose',
        [
          for (final p in kPoses)
            _SheetOption(
              key: Key('pose-${p.id}'),
              label: p.name,
              leading: Text(p.emoji, style: const TextStyle(fontSize: 26)),
              selected: _w.state.poseId == p.id,
              onTap: () => _w.setPose(p.id),
            ),
        ],
      );

  void _pickBackground() => _sheet(
        'Background',
        [
          for (final b in kBackgrounds)
            _SheetOption(
              key: Key('bg-${b.id}'),
              label: b.name,
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(b.skyTop), Color(b.floor)]),
                ),
                alignment: Alignment.center,
                child: Text(b.emoji),
              ),
              selected: _w.state.backgroundId == b.id,
              onTap: () => _w.setBackground(b.id),
            ),
        ],
      );

  void _pickCharacter() => _sheet(
        'Switch character',
        [
          for (final c in kCharacters)
            _SheetOption(
              key: Key('switch-${c.id}'),
              label: c.name,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Color(c.themeColor).withValues(alpha: 0.35),
                child: Text(c.name[0], style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.ink)),
              ),
              selected: _w.state.characterId == c.id,
              onTap: () => _w.switchCharacter(c.id, keepOutfit: _s.settings.keepOutfitOnSwitch),
            ),
        ],
        footer: _s.settings.keepOutfitOnSwitch
            ? 'Clothes carry over; each girl keeps her own hairstyle.'
            : 'Each girl arrives in her signature outfit.',
      );

  void _sheet(String title, List<_SheetOption> options, {String? footer}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final o in options)
                    ChoiceChip(
                      key: o.key,
                      avatar: o.leading,
                      label: Text(o.label),
                      selected: o.selected,
                      showCheckmark: false,
                      selectedColor: Palette.pinkSoft,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      onSelected: (_) {
                        o.onTap();
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
              if (footer != null) ...[
                const SizedBox(height: 10),
                Text(footer, style: const TextStyle(color: Palette.inkSoft)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Layout ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scene = _scene!;
    final viewport = Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            key: _captureKey,
            child: CharacterViewport(scene: scene),
          ),
        ),
        Positioned.fill(child: ConfettiBurst(key: _confetti)),
        Positioned(
          right: 10,
          top: 8,
          child: Column(
            children: [
              // Paper dolls have one painted pose and no back view.
              if (!scene.isFlat)
                _RoundButton(
                  key: const Key('auto-rotate'),
                  icon: Icons.threesixty_rounded,
                  tooltip: 'Auto-rotate',
                  active: scene.autoRotate,
                  onTap: () => setState(() => scene.autoRotate = !scene.autoRotate),
                ),
              _RoundButton(icon: Icons.center_focus_strong_rounded, tooltip: 'Reset camera', onTap: scene.resetCamera),
              if (!scene.isFlat)
                _RoundButton(key: const Key('open-poses'), icon: Icons.accessibility_new_rounded, tooltip: 'Pose', onTap: _pickPose),
              _RoundButton(key: const Key('open-backgrounds'), icon: Icons.landscape_rounded, tooltip: 'Background', onTap: _pickBackground),
              _RoundButton(key: _shareKey, icon: Icons.ios_share_rounded, tooltip: 'Share picture', onTap: _share),
            ],
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Row(
            children: [
              _RoundButton(icon: Icons.zoom_out_rounded, tooltip: 'Zoom out', onTap: () => scene.setZoom(scene.zoom / 1.2)),
              _RoundButton(icon: Icons.zoom_in_rounded, tooltip: 'Zoom in', onTap: () => scene.setZoom(scene.zoom * 1.2)),
            ],
          ),
        ),
      ],
    );

    final closet = ClosetPanel(
      wardrobe: _w,
      assembler: _s.assembler,
      category: _category,
      onCategory: (c) => setState(() => _category = c),
      onReset: _w.resetOutfit,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Palette.backdrop),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 760;
            final top = _TopBar(
              name: _w.character.name,
              themeColor: Color(_w.character.themeColor),
              onBack: () => Navigator.of(context).maybePop(),
              onSwitch: _pickCharacter,
              onSave: _save,
              avatar: LookThumbnail(
                look: _w.state,
                character: _w.character,
                assembler: _s.assembler,
                headOnly: true,
              ),
            );
            if (wide) {
              return Column(children: [
                top,
                Expanded(
                  child: Row(children: [
                    Expanded(child: viewport),
                    SizedBox(
                      width: (box.maxWidth * 0.4).clamp(360.0, 520.0),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(28)),
                        child: closet,
                      ),
                    ),
                  ]),
                ),
              ]);
            }
            final panelHeight = (box.maxHeight * _panelFraction).clamp(220.0, box.maxHeight * 0.65);
            return Column(children: [
              top,
              Expanded(child: viewport),
              SizedBox(
                height: panelHeight,
                child: ClosetPanel(
                  wardrobe: _w,
                  assembler: _s.assembler,
                  category: _category,
                  onCategory: (c) => setState(() => _category = c),
                  onReset: _w.resetOutfit,
                  onDragHandle: (d) => setState(() {
                    _panelFraction = (_panelFraction - d.delta.dy / box.maxHeight).clamp(0.28, 0.62);
                  }),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

class _SheetOption {
  final Key key;
  final String label;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;
  const _SheetOption({required this.key, required this.label, required this.leading, required this.selected, required this.onTap});
}

class _TopBar extends StatelessWidget {
  final String name;
  final Color themeColor;
  final Widget avatar;
  final VoidCallback onBack, onSwitch, onSave;
  const _TopBar({
    required this.name,
    required this.themeColor,
    required this.avatar,
    required this.onBack,
    required this.onSwitch,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Back'),
          const Spacer(),
          Material(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              key: const Key('character-switcher'),
              borderRadius: BorderRadius.circular(24),
              onTap: onSwitch,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: themeColor.withValues(alpha: 0.35)),
                    clipBehavior: Clip.antiAlias,
                    child: avatar,
                  ),
                  const SizedBox(width: 8),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const Icon(Icons.expand_more_rounded),
                ]),
              ),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            key: const Key('save-look'),
            onPressed: onSave,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            icon: const Icon(Icons.favorite_rounded, size: 18),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  const _RoundButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(4),
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: active ? Palette.pink : Colors.white.withValues(alpha: 0.88),
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: Colors.black26,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, size: 22, color: active ? Colors.white : Palette.ink),
              ),
            ),
          ),
        ),
      );
}
