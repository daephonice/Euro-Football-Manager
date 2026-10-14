import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'honours.dart';
import 'util.dart';

class SettingsScreen extends StatelessWidget {
  final AppDatabase db;
  const SettingsScreen(this.db, {super.key});

  Future<void> _theme(ThemeMode m) async {
    themeNotifier.value = m;
    final s = await loadCareer(db);
    await (db.update(db.careerSaves)..where((t) => t.id.equals(s.id)))
        .write(CareerSavesCompanion(themeMode: Value(m.index)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (_, m, __) => SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {m},
              onSelectionChanged: (v) => _theme(v.first),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.military_tech),
            title: const Text('Honours & awards'),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => HonoursScreen(db))),
          ),
        ]),
      );
}
