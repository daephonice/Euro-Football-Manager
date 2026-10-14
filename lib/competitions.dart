import 'package:flutter/material.dart';
import 'db/competitions.dart';
import 'db/database.dart';
import 'engine/fixtures.dart';

class CompetitionsScreen extends StatefulWidget {
  final AppDatabase db;
  const CompetitionsScreen(this.db, {super.key});
  @override
  State<CompetitionsScreen> createState() => _CompState();
}

class _CompState extends State<CompetitionsScreen> {
  late final Future<List<String>> _names = myCompetitions(widget.db);
  String? _sel;
  Future<CompDetail>? _d;

  void _pick(String n) => setState(() {
        _sel = n;
        _d = loadCompDetail(widget.db, n);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Competitions')),
        body: FutureBuilder<List<String>>(
          future: _names,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            if (s.data!.isEmpty) return const Center(child: Text('No cup or European entries this season'));
            if (_sel == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _sel == null) _pick(s.data!.first);
              });
            }
            return Column(children: [
              SizedBox(
                height: 52,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
                  for (final n in s.data!)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                          label: Text(n), selected: n == _sel, onSelected: (_) => _pick(n)),
                    ),
                ]),
              ),
              Expanded(child: _body()),
            ]);
          },
        ),
      );

  Widget _body() => FutureBuilder<CompDetail>(
        future: _d,
        builder: (_, s) {
          if (s.hasError) return Center(child: Text('${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final d = s.data!;
          final bold = const TextStyle(fontWeight: FontWeight.bold);
          final rounds = <int, List<(Fixture, MatchResult?)>>{};
          for (final x in d.fixtures) {
            (rounds[x.$1.round] ??= []).add(x);
          }
          return ListView(padding: const EdgeInsets.all(12), children: [
            if (d.winner != null)
              Card(
                  child: ListTile(
                      leading: const Icon(Icons.emoji_events),
                      title: Text('Winner: ${d.clubs[d.winner]!.name}'))),
            for (var g = 0; g < d.groups.length; g++) ...[
              Text('Group ${String.fromCharCode(65 + g)}',
                  style: Theme.of(context).textTheme.titleSmall),
              for (final r in d.groups[g])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(r.club.name, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: 28, child: Text('${r.p}')),
                    SizedBox(width: 36, child: Text('${r.gd}')),
                    SizedBox(width: 32, child: Text('${r.pts}', style: bold)),
                  ]),
                ),
              const SizedBox(height: 8),
            ],
            for (final e in rounds.entries) ...[
              Text(e.value.length == 1 ? 'Final' : 'Round ${e.key > groupRounds && d.groups.isNotEmpty ? e.key - groupRounds : e.key}',
                  style: Theme.of(context).textTheme.titleSmall),
              for (final x in e.value)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${d.clubs[x.$1.homeClubId]!.name}  ${x.$2 == null ? 'v' : '${x.$2!.homeGoals}–${x.$2!.awayGoals}'}  ${d.clubs[x.$1.awayClubId]!.name}',
                      style: TextStyle(
                          fontWeight: x.$2?.winnerClubId != null ? FontWeight.w600 : null)),
                  subtitle: Text(x.$2 == null
                      ? dayLabel(d.season.year, x.$1.day)
                      : x.$2!.note == 'pens'
                          ? 'Won on penalties: ${d.clubs[x.$2!.winnerClubId]!.name}'
                          : x.$2!.note == 'aet'
                              ? 'After extra time'
                              : dayLabel(d.season.year, x.$1.day)),
                ),
              const SizedBox(height: 8),
            ],
          ]);
        },
      );
}
