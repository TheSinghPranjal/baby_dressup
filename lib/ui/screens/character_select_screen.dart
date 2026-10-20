import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../character/character_definition.dart';
import '../../character/characters.dart';
import '../../scene/dressing_scene.dart';
import '../../wardrobe/wardrobe_manager.dart';
import '../theme.dart';
import '../widgets/character_viewport.dart';
import 'dressing_room_screen.dart';

/// Carousel of large 3D character previews.
class CharacterSelectScreen extends StatefulWidget {
  final bool collection;
  const CharacterSelectScreen({super.key, this.collection = false});

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  PageController? _controller;
  PageController get _pages => _controller!;
  final _scenes = <String, DressingScene>{};
  WardrobeManager? _preview;
  int _current = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preview != null) return;
    final s = AppScope.of(context);
    _preview = WardrobeManager(catalog: s.catalog);
    _current = kCharacters.indexWhere((c) => c.id == s.wardrobe.state.characterId).clamp(0, kCharacters.length - 1);
    _controller = PageController(viewportFraction: 0.78, initialPage: _current);
  }

  DressingScene _sceneFor(CharacterDefinition c) => _scenes.putIfAbsent(c.id, () {
        final s = AppScope.of(context);
        _preview!.switchCharacter(c.id);
        return DressingScene(s.assembler, dolls: s.dolls, showEnvironment: false, seed: c.id.hashCode)
          ..pitch = 0.05
          ..zoom = 1.03
          ..show(_preview!.state, c);
      });

  @override
  void dispose() {
    for (final s in _scenes.values) {
      s.dispose();
    }
    _preview?.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _select(CharacterDefinition c) {
    final s = AppScope.of(context);
    s.wardrobe.switchCharacter(c.id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DressingRoomScreen(greet: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = kCharacters[_current];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        foregroundColor: _plum,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(widget.collection ? 'Character Collection' : 'Choose Your Stylist',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: _plum, letterSpacing: -0.3)),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: Palette.backdrop),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: kCharacters.length,
                  onPageChanged: (i) {
                    setState(() => _current = i);
                    _sceneFor(kCharacters[i]).animator.waveHello();
                  },
                  itemBuilder: (context, i) {
                    final ch = kCharacters[i];
                    final active = i == _current;
                    return AnimatedScale(
                      scale: active ? 1 : 0.86,
                      duration: const Duration(milliseconds: 250),
                      child: AnimatedOpacity(
                        opacity: active ? 1 : 0.55,
                        duration: const Duration(milliseconds: 250),
                        child: GestureDetector(
                          onTap: () => active
                              ? null
                              : _pages.animateToPage(i,
                                  duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(34),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.lerp(Color(ch.themeColor), Colors.white, 0.72)!,
                                  Color.lerp(const Color(0xFFF7A1BE), Colors.white, 0.7)!,
                                ],
                              ),
                              border: Border.all(
                                  color: active ? Color(ch.themeColor) : Colors.white, width: active ? 3 : 1.5),
                              boxShadow: [
                                if (active)
                                  BoxShadow(
                                      color: Color(ch.themeColor).withValues(alpha: 0.35),
                                      blurRadius: 24,
                                      spreadRadius: 1),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(31),
                              child: Stack(children: [
                                Positioned.fill(child: CustomPaint(painter: _CardDecor(Color(ch.themeColor)))),
                                Positioned.fill(
                                  child: CharacterViewport(
                                    scene: _sceneFor(ch),
                                    // Swipes page the carousel, so the preview is view-only.
                                    interactive: false,
                                    animate: active,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _Dots(count: kCharacters.length, index: _current),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(c.id),
                    children: [
                      Text(c.name,
                          style: const TextStyle(
                              fontSize: 46, height: 1.05, fontWeight: FontWeight.w900, color: _plum, letterSpacing: -1)),
                      Text(c.tagline,
                          style: TextStyle(
                              fontSize: 20,
                              color: Color.lerp(Color(c.themeColor), const Color(0xFFE8604A), 0.4),
                              fontWeight: FontWeight.w800)),
                      if (widget.collection) ...[
                        const SizedBox(height: 6),
                        Text(c.bio, textAlign: TextAlign.center, style: const TextStyle(color: Palette.inkSoft)),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: SizedBox(
                  width: 420,
                  height: 64,
                  child: FilledButton.icon(
                    key: const Key('select-character'),
                    onPressed: () => _select(c),
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: const Color(0xFFF55A93),
                      elevation: 6,
                      shadowColor: const Color(0xFFF55A93).withValues(alpha: 0.5),
                      textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 28),
                    label: Text('Style ${c.name}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count, index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.all(3),
              width: i == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? Palette.pink : Palette.pink.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      );
}

const _plum = Color(0xFF34103C);

/// Sparkles, outlined hearts, a soft halo and a floor glow behind the
/// character, as in the card design.
class _CardDecor extends CustomPainter {
  final Color theme;
  _CardDecor(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawCircle(
        Offset(w * 0.62, h * 0.42),
        w * 0.42,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: Offset(w * 0.62, h * 0.42), radius: w * 0.42)));
    // Floor.
    final floor = Rect.fromLTWH(0, h * 0.86, w, h * 0.14);
    canvas.drawRect(
        floor,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.35), const Color(0xFFF6D3E0).withValues(alpha: 0.6)],
          ).createShader(floor));
    canvas.drawLine(Offset(0, h * 0.86), Offset(w, h * 0.86),
        Paint()..color = Colors.white.withValues(alpha: 0.6)..strokeWidth = 1.5);

    final sparkle = Paint()..color = Colors.white.withValues(alpha: 0.95);
    for (final s in const [(0.16, 0.13, 13.0), (0.15, 0.27, 7.0), (0.13, 0.52, 11.0), (0.9, 0.56, 9.0), (0.88, 0.3, 6.0)]) {
      _star(canvas, Offset(w * s.$1, h * s.$2), s.$3, sparkle);
    }
    final heart = Paint()
      ..color = Color.lerp(theme, Colors.white, 0.35)!.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    _heart(canvas, Offset(w * 0.86, h * 0.22), 22, 0.25, heart);
    _heart(canvas, Offset(w * 0.17, h * 0.4), 20, -0.2, heart..color = heart.color.withValues(alpha: 0.6));
  }

  void _star(Canvas c, Offset o, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.22;
      final pt = o + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(path..close(), p);
  }

  void _heart(Canvas c, Offset o, double s, double rot, Paint p) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot);
    final path = Path()
      ..moveTo(0, s * 0.35)
      ..cubicTo(-s * 1.1, -s * 0.3, -s * 0.45, -s * 1.05, 0, -s * 0.4)
      ..cubicTo(s * 0.45, -s * 1.05, s * 1.1, -s * 0.3, 0, s * 0.35);
    c.drawPath(path, p);
    c.restore();
  }

  @override
  bool shouldRepaint(_CardDecor old) => old.theme != theme;
}
