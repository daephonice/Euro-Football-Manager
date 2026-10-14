import 'package:flutter/material.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'engine/rating.dart' show gkAttrs, outfieldAttrs;

class SquadScreen extends StatefulWidget {
  final AppDatabase db;
  const SquadScreen(this.db, {super.key});
  @override
  State<SquadScreen> createState() => _SquadState();
}

class _SquadState extends State<SquadScreen> {
  late final Future<List<Player>> _f = loadSquad(widget.db);

  static String _label(String k) {
    final s = k.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}');
    return s[0].toUpperCase() + s.substring(1);
  }

  void _detail(Player p) {
    final a = toSim(p).attrs;
    final keys = p.positions.split(',').first == 'GK' ? gkAttrs : outfieldAttrs;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.all(16), children: [
          Text(p.fullName, style: Theme.of(context).textTheme.titleLarge),
          Text('${p.positions.replaceAll(',', '/')} · ${p.nationality} · age ${p.age} · ${p.preferredFoot} foot'),
          const SizedBox(height: 4),
          Text('OVR ${p.overall} · POT ${p.potential} · fitness ${p.fitness} · form ${p.form} · morale ${p.morale}'),
          Text('Wage £${p.wagePerWeek}/wk · Value £${p.value} · Contract ${p.contractEndYear}'),
          const Divider(),
          for (final k in keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                SizedBox(width: 120, child: Text(_label(k))),
                Expanded(child: LinearProgressIndicator(value: a[k]! / 99)),
                SizedBox(width: 32, child: Text('${a[k]}', textAlign: TextAlign.right)),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Squad')),
        body: FutureBuilder<List<Player>>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(children: [
              for (final p in s.data!)
                ListTile(
                  dense: true,
                  onTap: () => _detail(p),
                  leading: CircleAvatar(
                      radius: 16,
                      child: Text(p.positions.split(',').first,
                          style: const TextStyle(fontSize: 10))),
                  title: Text(p.fullName),
                  subtitle: Text('Age ${p.age} · Fit ${p.fitness} · Form ${p.form}'),
                  trailing: Text('${p.overall}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
            ]);
          },
        ),
      );
}
