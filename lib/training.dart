import 'package:flutter/material.dart';
import 'db/database.dart';
import 'db/training.dart';
import 'engine/development.dart';
import 'engine/rating.dart' show gkAttrs, outfieldAttrs;
import 'util.dart';

class TrainingScreen extends StatefulWidget {
  final AppDatabase db;
  const TrainingScreen(this.db, {super.key});
  @override
  State<TrainingScreen> createState() => _TrainingState();
}

class _TrainingState extends State<TrainingScreen> {
  late Future<TrainingData> _f = loadTraining(widget.db);

  Future<void> _toggle(List<String> cur, String k) async {
    final f = [...cur];
    if (f.contains(k)) {
      f.remove(k);
    } else {
      if (f.length >= maxFocus) f.removeAt(0);
      f.add(k);
    }
    await saveFocus(widget.db, f);
    if (mounted) setState(() => _f = loadTraining(widget.db));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Training')),
        body: FutureBuilder<TrainingData>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final d = s.data!;
            final lvl = d.club.trainingLevel;
            final grow = [...d.squad]
              ..sort((a, b) => (b.potential - b.overall).compareTo(a.potential - a.overall));
            Widget chip(String k, String label) => FilterChip(
                  label: Text(label),
                  selected: d.focus.contains(k),
                  onSelected: (_) => _toggle(d.focus, k),
                );
            return ListView(padding: const EdgeInsets.all(12), children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text('Training facility · level $lvl/5'),
                  subtitle: Text(
                      'Gains ×${trainingMult(lvl).toStringAsFixed(2)} · ${d.weeks} sessions this season'),
                ),
              ),
              const SizedBox(height: 8),
              Text('Weekly focus (pick up to $maxFocus)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 0, children: [
                FilterChip(
                  label: const Text('General fitness'),
                  selected: d.focus.isEmpty,
                  onSelected: (_) async {
                    await saveFocus(widget.db, []);
                    if (mounted) setState(() => _f = loadTraining(widget.db));
                  },
                ),
                for (final k in outfieldAttrs) chip(k, attrLabel(k)),
              ]),
              const SizedBox(height: 8),
              Text('Goalkeepers', style: Theme.of(context).textTheme.labelMedium),
              Wrap(spacing: 6, children: [for (final k in gkAttrs) chip(k, attrLabel(k))]),
              const SizedBox(height: 4),
              Text(
                  'Outfield focus only trains outfielders; goalkeeper focus only trains goalkeepers. General fitness speeds up recovery.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Text('Most room to grow', style: Theme.of(context).textTheme.titleSmall),
              for (final p in grow.take(10))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.fullName),
                  subtitle: Text('${p.positions.split(',').first} · age ${p.age}'),
                  trailing: Text('${p.overall} → ${p.potential}'),
                ),
            ]);
          },
        ),
      );
}
