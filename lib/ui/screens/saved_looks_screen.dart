import 'package:flutter/material.dart';

import '../../app.dart';
import '../../character/characters.dart';
import '../../persistence/outfit_save_service.dart';
import '../../scene/environment.dart';
import '../theme.dart';
import '../widgets/thumbnails.dart';
import 'dressing_room_screen.dart';

class SavedLooksScreen extends StatelessWidget {
  const SavedLooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Looks', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: Palette.backdrop),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: s.saves,
            builder: (context, _) {
              final looks = s.saves.looks;
              if (looks.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No saved looks yet.\nStyle someone and tap 💖 Save!',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: Palette.inkSoft)),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 0.62,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: looks.length,
                itemBuilder: (context, i) => _LookCard(look: looks[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LookCard extends StatelessWidget {
  final SavedLook look;
  const _LookCard({required this.look});

  void _edit(BuildContext context) {
    final s = AppScope.of(context);
    s.wardrobe.applyLook(look.look);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DressingRoomScreen(editing: look)));
  }

  Future<void> _rename(BuildContext context) async {
    final s = AppScope.of(context);
    final ctrl = TextEditingController(text: look.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename look'),
        content: TextField(controller: ctrl, autofocus: true, maxLength: 32),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Rename')),
        ],
      ),
    );
    if (name != null) await s.saves.rename(look.id, name);
  }

  Future<void> _delete(BuildContext context) async {
    final s = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${look.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await s.saves.delete(look.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = characterById(look.look.characterId) ?? kCharacters.first;
    final bg = backgroundById(look.look.backgroundId);
    final d = look.createdAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _edit(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(bg.skyTop), Color(bg.skyBottom)],
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: LookThumbnail(look: look.look, character: c, assembler: s.assembler),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(look.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${c.name} · ${d.day}/${d.month}/${d.year}',
                            style: const TextStyle(fontSize: 12, color: Palette.inkSoft)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          _edit(context);
                        case 'rename':
                          _rename(context);
                        case 'delete':
                          _delete(context);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
