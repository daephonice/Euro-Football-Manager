import 'package:flutter/material.dart';
import 'db/database.dart';
import 'db/market.dart';
import 'engine/fixtures.dart';
import 'util.dart';

class FinancesScreen extends StatefulWidget {
  final AppDatabase db;
  const FinancesScreen(this.db, {super.key});
  @override
  State<FinancesScreen> createState() => _FinancesState();
}

class _FinancesState extends State<FinancesScreen> {
  late final Future<FinanceData> _f = loadFinance(widget.db);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Finances')),
        body: FutureBuilder<FinanceData>(
          future: _f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final d = s.data!;
            const rows = [
              ('tickets', 'Gate receipts'),
              ('commercial', 'Sponsors & merchandise'),
              ('wages', 'Wages'),
              ('transfer_in', 'Transfers in'),
              ('transfer_out', 'Transfers out'),
            ];
            final net = d.totals.values.fold<int>(0, (a, b) => a + b);
            Widget line(String a, int v, {bool bold = false}) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(
                        child: Text(a,
                            style: TextStyle(fontWeight: bold ? FontWeight.bold : null))),
                    Text(fmtMoney(v),
                        style: TextStyle(
                            fontWeight: bold ? FontWeight.bold : null,
                            color: v < 0 ? Colors.redAccent : null)),
                  ]),
                );
            return ListView(padding: const EdgeInsets.all(12), children: [
              Card(
                child: ListTile(
                  title: Text(fmtMoney(d.club.budget),
                      style: Theme.of(context).textTheme.headlineMedium),
                  subtitle: Text('Transfer budget · wage bill ${fmtMoney(d.wageBill)}/wk'),
                ),
              ),
              const SizedBox(height: 8),
              Text('Season ${d.season.year}',
                  style: Theme.of(context).textTheme.titleSmall),
              for (final r in rows) line(r.$2, d.totals[r.$1] ?? 0),
              const Divider(),
              line('Net', net, bold: true),
              const SizedBox(height: 12),
              Text('Recent', style: Theme.of(context).textTheme.titleSmall),
              for (final e in d.entries.take(20))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.note),
                  subtitle: Text(dayLabel(d.season.year, e.day)),
                  trailing: Text(fmtMoney(e.amount),
                      style: TextStyle(color: e.amount < 0 ? Colors.redAccent : Colors.green)),
                ),
            ]);
          },
        ),
      );
}
