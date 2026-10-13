import 'package:flutter/material.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'engine/fixtures.dart';
import 'engine/match.dart' show MatchEvent;

class HubScreen extends StatefulWidget {
  final AppDatabase db;
  const HubScreen(this.db, {super.key});
  @override
  State<HubScreen> createState() => _HubState();
}

class _HubState extends State<HubScreen> {
  late Future<HubData> _f = loadHub(widget.db);
  bool _busy = false;

  Future<void> _play() async {
    setState(() => _busy = true);
    MatchReport? rep;
    try {
      rep = await playNextMatchday(widget.db);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _f = loadHub(widget.db);
    });
    if (rep != null) {
      final r = rep;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('${r.home} ${r.hg}–${r.ag} ${r.away}'),
          content: SingleChildScrollView(
            child: Text([
              for (final e in r.events) _line(r, e),
              '',
              'Shots ${r.shots[0]}–${r.shots[1]}',
              'Possession ${r.poss[0]}%–${r.poss[1]}%',
            ].join('\n')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
          ],
        ),
      );
    }
  }

  String _line(MatchReport r, MatchEvent e) {
    final club = e.side == 0 ? r.home : r.away;
    return switch (e.type) {
      'goal' => "${e.minute}' ⚽ ${e.name}${e.other != null ? ' (${e.other})' : ''} — $club",
      'yellow' => "${e.minute}' 🟨 ${e.name} — $club",
      'red' => "${e.minute}' 🟥 ${e.name} — $club",
      'injury' => "${e.minute}' 🚑 ${e.name} — $club",
      _ => "${e.minute}' 🔁 ${e.name} for ${e.other} — $club",
    };
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<HubData>(
        future: _f,
        builder: (_, s) {
          if (s.hasError) return Scaffold(body: Center(child: Text('${s.error}')));
          if (!s.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final d = s.data!;
          String vs(Fixture f) {
            final home = f.homeClubId == d.me.id;
            return '${home ? 'H' : 'A'} · ${d.clubs[home ? f.awayClubId : f.homeClubId]!.name}';
          }

          final yy = '${(d.season.year + 1) % 100}'.padLeft(2, '0');
          final first = d.next.isEmpty ? null : d.next.first;
          final bold = const TextStyle(fontWeight: FontWeight.bold);
          Widget tr(String a, String b, String c, String e, String f,
                  {TextStyle? st, Color? bg}) =>
              Container(
                color: bg,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  SizedBox(width: 24, child: Text(a, style: st)),
                  Expanded(child: Text(b, overflow: TextOverflow.ellipsis, style: st)),
                  SizedBox(width: 28, child: Text(c, style: st)),
                  SizedBox(width: 36, child: Text(e, style: st)),
                  SizedBox(width: 32, child: Text(f, style: st)),
                ]),
              );
          return Scaffold(
            appBar: AppBar(title: Text(d.me.name)),
            body: ListView(padding: const EdgeInsets.all(12), children: [
              Text('Season ${d.season.year}/$yy · ${d.league.name}',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.sports_soccer),
                  title: Text(first == null ? 'Season complete' : vs(first)),
                  subtitle: first == null
                      ? null
                      : Text('${first.competition} · Round ${first.round} · ${dayLabel(d.season.year, first.day)}'),
                  trailing: first == null
                      ? null
                      : _busy
                          ? const SizedBox(
                              width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : FilledButton(onPressed: _play, child: const Text('Play')),
                ),
              ),
              const SizedBox(height: 8),
              Text('Table', style: Theme.of(context).textTheme.titleSmall),
              tr('#', 'Club', 'P', 'GD', 'Pts', st: bold),
              for (var i = 0; i < d.table.length; i++)
                tr('${i + 1}', d.table[i].club.name, '${d.table[i].p}', '${d.table[i].gd}',
                    '${d.table[i].pts}',
                    st: d.table[i].club.id == d.me.id ? bold : null,
                    bg: d.table[i].club.id == d.me.id
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null),
              const SizedBox(height: 8),
              Text('Upcoming', style: Theme.of(context).textTheme.titleSmall),
              for (final f in d.next.skip(1))
                ListTile(
                  dense: true,
                  title: Text(vs(f)),
                  trailing: Text(dayLabel(d.season.year, f.day)),
                ),
            ]),
          );
        },
      );
}
