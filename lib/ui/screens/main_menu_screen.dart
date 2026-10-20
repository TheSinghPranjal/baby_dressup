import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../character/characters.dart';
import '../../scene/dressing_scene.dart';
import '../../wardrobe/outfit_state.dart';
import '../../wardrobe/wardrobe_manager.dart';
import '../theme.dart';
import '../widgets/character_viewport.dart';
import 'character_select_screen.dart';
import 'saved_looks_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  DressingScene? _scene;
  WardrobeManager? _preview;
  Timer? _cycle;
  int _index = 0;
  bool _onTop = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scene != null) return;
    final s = AppScope.of(context);
    _scene = DressingScene(s.assembler, dolls: s.dolls, showEnvironment: false)
      ..autoRotate = true
      ..pitch = 0.05;
    _preview = WardrobeManager(catalog: s.catalog);
    _showCurrent();
    _cycle = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_onTop) return;
      _index = (_index + 1) % kCharacters.length;
      _showCurrent();
    });
  }

  void _showCurrent() {
    final c = kCharacters[_index];
    _preview!.switchCharacter(c.id);
    final OutfitState st = _preview!.state.copyWith(poseId: _index.isEven ? 'casual' : 'hand_on_hip');
    _scene!.show(st, c);
    _scene!.animator.react();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _scene?.dispose();
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _go(Widget page) async {
    _onTop = false;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _onTop = true;
  }

  @override
  Widget build(BuildContext context) {
    final c = kCharacters[_index];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Palette.backdrop),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 720;
            final hero = Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Color(c.themeColor).withValues(alpha: 0.45),
                        Colors.white.withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                ),
                Positioned.fill(child: CharacterViewport(scene: _scene!, interactive: false, animate: _onTop)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text('${c.name} · ${c.tagline}',
                        key: ValueKey(c.id),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.inkSoft)),
                  ),
                ),
              ],
            );
            final menu = _Menu(onNavigate: _go);
            if (wide) {
              return Row(children: [
                Expanded(child: hero),
                SizedBox(width: 380, child: Center(child: SingleChildScrollView(child: menu))),
              ]);
            }
            return Column(children: [
              Expanded(child: hero),
              menu,
            ]);
          }),
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  final Future<void> Function(Widget) onNavigate;
  const _Menu({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Palette.pink, Palette.lavender],
            ).createShader(r),
            child: const Text(
              'Glam Closet 3D',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
            ),
          ),
          const Text('Mix, match & strike a pose ✨',
              textAlign: TextAlign.center, style: TextStyle(color: Palette.inkSoft, fontSize: 15)),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('play'),
            onPressed: () => onNavigate(const CharacterSelectScreen()),
            icon: const Icon(Icons.checkroom_rounded),
            label: const Text('Play Dress Up'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _SoftButton(
                icon: Icons.groups_rounded,
                label: 'Characters',
                onTap: () => onNavigate(const CharacterSelectScreen(collection: true)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SoftButton(
                icon: Icons.favorite_rounded,
                label: 'Saved Looks',
                onTap: () => onNavigate(const SavedLooksScreen()),
              ),
            ),
            const SizedBox(width: 10),
            _SoftButton(
              icon: Icons.settings_rounded,
              label: '',
              tooltip: 'Settings',
              onTap: () => onNavigate(const SettingsScreen()),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback onTap;
  const _SoftButton({required this.icon, required this.label, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Palette.pink),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}
