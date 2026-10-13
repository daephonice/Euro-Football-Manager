import 'package:flutter/material.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'engine/fixtures.dart';

class HubScreen extends StatelessWidget {
  final AppDatabase db;
  const HubScreen(this.db, {super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<HubData>(
        future: loadHub(db),
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
          return Scaffold(
            appBar: AppBar(title: Text(d.me.name)),
            body: ListView(padding: const EdgeInsets.all(12), children: [
              Text('Season ${d.season.year}/$yy',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  title: Text(first == null ? 'No fixtures' : vs(first)),
                  subtitle: first == null
                      ? null
                      : Text('${first.competition} · Round ${first.round} · ${dayLabel(d.season.year, first.day)}'),
                  leading: const Icon(Icons.sports_soccer),
                ),
              ),
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
