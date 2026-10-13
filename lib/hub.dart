import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'db/database.dart';

class HubScreen extends StatelessWidget {
  final AppDatabase db;
  const HubScreen(this.db, {super.key});

  Future<(int, int, List<Player>)> _load() async {
    final clubs = (await db.select(db.clubs).get()).length;
    final players = await (db.select(db.players)
          ..orderBy([(t) => OrderingTerm.desc(t.overall)]))
        .get();
    return (clubs, players.length, players.take(25).toList());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Hub')),
        body: FutureBuilder(
          future: _load(),
          builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final (clubs, count, top) = s.data!;
            return ListView(children: [
              ListTile(title: Text('$clubs clubs · $count players')),
              const Divider(),
              for (final p in top)
                ListTile(
                  dense: true,
                  title: Text(p.fullName),
                  subtitle: Text('${p.positions} · ${p.age} · ${p.nationality}'),
                  trailing: Text('${p.overall}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ]);
          },
        ),
      );
}
