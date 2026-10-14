import 'package:flutter/material.dart';
import 'db/database.dart';
import 'db/facilities.dart';
import 'util.dart';

class FacilitiesScreen extends StatefulWidget {
  final AppDatabase db;
  const FacilitiesScreen(this.db, {super.key});
  @override
  State<FacilitiesScreen> createState() => _FacState();
}

class _FacState extends State<FacilitiesScreen> {
  late Future<FacilityData> _f = loadFacilities(widget.db);

  Future<void> _up(bool stadium) async {
    final err = await upgradeFacility(widget.db, stadium: stadium);
    if (!mounted) return;
    if (err != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    setState(() => _f = loadFacilities(widget.db));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Facilities & sponsor')),
        body: FutureBuilder<FacilityData>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final d = s.data!;
            Widget card(IconData ic, String t, int lvl, String effect, bool stadium) {
              final max = lvl >= maxFacility;
              final cost = upgradeCost(lvl, d.league.strength);
              return Card(
                child: ListTile(
                  leading: Icon(ic),
                  title: Text('$t · level $lvl/$maxFacility'),
                  subtitle: Text(effect),
                  trailing: max
                      ? const Text('MAX')
                      : FilledButton(
                          onPressed: d.club.budget >= cost ? () => _up(stadium) : null,
                          child: Text(fmtMoney(cost))),
                ),
              );
            }

            final name = d.save.sponsorName.isEmpty ? 'Local partners' : d.save.sponsorName;
            return ListView(padding: const EdgeInsets.all(12), children: [
              Card(
                child: ListTile(
                  title: Text(fmtMoney(d.club.budget),
                      style: Theme.of(context).textTheme.headlineMedium),
                  subtitle: const Text('Budget'),
                ),
              ),
              card(Icons.stadium, 'Stadium', d.club.stadiumLevel,
                  'Gate receipts ×${(1 + 0.15 * (d.club.stadiumLevel - 1)).toStringAsFixed(2)}', true),
              card(Icons.fitness_center, 'Training ground', d.club.trainingLevel,
                  'Player development ×${(0.7 + 0.15 * d.club.trainingLevel).toStringAsFixed(2)}', false),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.handshake),
                  title: Text(name),
                  subtitle: Text(
                      'Sponsor deal · ${d.save.sponsorPct}% of standard value. Renewed each season based on league finish.'),
                ),
              ),
            ]);
          },
        ),
      );
}
