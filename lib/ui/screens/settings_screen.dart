import 'package:flutter/material.dart';

import '../../app.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = s.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListenableBuilder(
        listenable: st,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SwitchListTile(
              title: const Text('Auto-rotate in the dressing room'),
              value: st.autoRotate,
              onChanged: (v) => st.update(autoRotate: v),
            ),
            SwitchListTile(
              title: const Text('Show 3D backgrounds'),
              subtitle: const Text('Turn off for extra speed on older phones'),
              value: st.showBackground,
              onChanged: (v) => st.update(showBackground: v),
            ),
            SwitchListTile(
              title: const Text('Keep outfit when switching character'),
              value: st.keepOutfitOnSwitch,
              onChanged: (v) => st.update(keepOutfitOnSwitch: v),
            ),
            SwitchListTile(
              title: const Text('Reduce motion'),
              subtitle: const Text('No hops, waves or spins'),
              value: st.reduceMotion,
              onChanged: (v) => st.update(reduceMotion: v),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Palette.pink),
              title: const Text('Delete all saved looks'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete all saved looks?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) {
                  for (final l in [...s.saves.looks]) {
                    await s.saves.delete(l.id);
                  }
                }
              },
            ),
            const AboutListTile(
              icon: Icon(Icons.info_outline_rounded),
              applicationName: 'Glam Closet 3D',
              applicationVersion: '1.0.0',
              aboutBoxChildren: [
                Text('All characters, clothes and rooms are generated procedurally in real time.'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
