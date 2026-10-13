import 'package:flutter/material.dart';
import 'db/career.dart';
import 'db/database.dart';

class NewCareerScreen extends StatelessWidget {
  final AppDatabase db;
  final VoidCallback onStarted;
  const NewCareerScreen(this.db, {required this.onStarted, super.key});

  Future<(List<League>, List<Club>)> _load() async {
    final leagues = await db.select(db.leagues).get();
    final clubs = await db.select(db.clubs).get();
    return (leagues, clubs);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Choose your club')),
        body: FutureBuilder(
          future: _load(),
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final (leagues, clubs) = s.data!;
            final withClubs = [
              for (final l in leagues)
                if (clubs.any((c) => c.leagueId == l.id)) l
            ]..sort((a, b) => b.strength.compareTo(a.strength));
            return ListView(children: [
              for (final l in withClubs)
                ExpansionTile(
                  title: Text('${l.name} · ${l.country}'),
                  children: [
                    for (final c in ([...clubs.where((c) => c.leagueId == l.id)]
                      ..sort((a, b) => b.reputation.compareTo(a.reputation))))
                      ListTile(
                        title: Text(c.name),
                        trailing: Text('${c.reputation}'),
                        onTap: () async {
                          await startCareer(db, c.id);
                          onStarted();
                        },
                      ),
                  ],
                ),
            ]);
          },
        ),
      );
}
