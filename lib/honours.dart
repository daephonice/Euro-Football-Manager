import 'package:flutter/material.dart';
import 'db/database.dart';
import 'db/facilities.dart';

class HonoursScreen extends StatelessWidget {
  final AppDatabase db;
  const HonoursScreen(this.db, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Honours')),
        body: FutureBuilder<HonoursData>(
          future: loadHonours(db),
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final d = s.data!;
            if (d.bySeason.isEmpty) return const Center(child: Text('Awards appear after your first season'));
            return ListView(padding: const EdgeInsets.all(12), children: [
              Card(
                  child: ListTile(
                      leading: const Icon(Icons.emoji_events),
                      title: Text('Club trophies: ${d.trophies}'))),
              for (final e in d.bySeason.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text('Season ${e.key}/${'${(e.key + 1) % 100}'.padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final a in e.value)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(a.team ? Icons.emoji_events : Icons.military_tech,
                        color: a.clubId == d.myClub ? Colors.amber : null),
                    title: Text(a.category),
                    subtitle: Text(a.detail.isEmpty ? a.winner : '${a.winner} · ${a.detail}'),
                  ),
              ],
            ]);
          },
        ),
      );
}
