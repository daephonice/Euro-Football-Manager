import 'package:flutter/material.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'engine/match.dart';

const mentalityNames = ['Ultra Defensive', 'Defensive', 'Balanced', 'Attacking', 'Ultra Attacking'];
const verticalityNames = ['Low', 'Medium', 'High'];

class TacticsControls extends StatelessWidget {
  final String formation;
  final int mentality, verticality;
  final bool enabled;
  final ValueChanged<String> onFormation;
  final ValueChanged<int> onMentality, onVerticality;
  final void Function(int mentality, int verticality) onStyle;
  const TacticsControls({
    required this.formation,
    required this.mentality,
    required this.verticality,
    required this.onFormation,
    required this.onMentality,
    required this.onVerticality,
    required this.onStyle,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.titleSmall;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Style', style: t),
      Wrap(spacing: 8, children: [
        for (final e in stylePresets.entries)
          ActionChip(
            label: Text(e.key),
            onPressed: enabled ? () => onStyle(e.value.$1, e.value.$2) : null,
          ),
      ]),
      const SizedBox(height: 12),
      Text('Formation', style: t),
      Wrap(spacing: 8, children: [
        for (final f in formations.keys)
          ChoiceChip(
            label: Text(f),
            selected: f == formation,
            onSelected: enabled ? (_) => onFormation(f) : null,
          ),
      ]),
      const SizedBox(height: 12),
      Text('Mentality: ${mentalityNames[mentality]}', style: t),
      Slider(
        value: mentality.toDouble(),
        min: 0,
        max: 4,
        divisions: 4,
        label: mentalityNames[mentality],
        onChanged: enabled
            ? (v) {
                if (v.round() != mentality) onMentality(v.round());
              }
            : null,
      ),
      Text('Verticality', style: t),
      const SizedBox(height: 4),
      SegmentedButton<int>(
        segments: [
          for (var i = 0; i < 3; i++) ButtonSegment(value: i, label: Text(verticalityNames[i])),
        ],
        selected: {verticality},
        onSelectionChanged: enabled ? (s) => onVerticality(s.first) : null,
      ),
    ]);
  }
}

class TacticsScreen extends StatefulWidget {
  final AppDatabase db;
  const TacticsScreen(this.db, {super.key});
  @override
  State<TacticsScreen> createState() => _TacticsState();
}

class _TacticsState extends State<TacticsScreen> {
  late final Future<(Tactics, List<SimPlayer>)> _f = _load();
  Tactics? _t;

  Future<(Tactics, List<SimPlayer>)> _load() async => (
        await loadTactics(widget.db),
        [for (final p in await loadSquad(widget.db)) toSim(p)],
      );

  void _set(void Function(Tactics t) f) {
    setState(() => f(_t!));
    saveTactics(widget.db, _t!);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tactics')),
        body: FutureBuilder<(Tactics, List<SimPlayer>)>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final t = _t ??= s.data!.$1;
            final side = Side.pick(0, s.data!.$2, t);
            return ListView(padding: const EdgeInsets.all(12), children: [
              TacticsControls(
                formation: t.formation,
                mentality: t.mentality,
                verticality: t.verticality,
                onFormation: (f) => _set((t) => t.formation = f),
                onMentality: (m) => _set((t) => t.mentality = m),
                onVerticality: (v) => _set((t) => t.verticality = v),
                onStyle: (m, v) => _set((t) {
                  t.mentality = m;
                  t.verticality = v;
                }),
              ),
              const Divider(height: 32),
              Text('Projected XI', style: Theme.of(context).textTheme.titleSmall),
              for (final ln in const ['att', 'mid', 'def', 'gk'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
                    for (var j = 0; j < side.xi.length; j++)
                      if (lineOf(side.slots[j]) == ln)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                              '${side.slots[j]} ${side.xi[j].name.split(' ').last} ${ratingAt(side.xi[j], side.slots[j]).round()}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                  ]),
                ),
            ]);
          },
        ),
      );
}
