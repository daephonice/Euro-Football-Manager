import 'package:flutter/material.dart';
import 'db/database.dart';
import 'db/market.dart';
import 'util.dart';

class TransfersScreen extends StatefulWidget {
  final AppDatabase db;
  const TransfersScreen(this.db, {super.key});
  @override
  State<TransfersScreen> createState() => _TransfersState();
}

class _TransfersState extends State<TransfersScreen> {
  static const _positions = ['All', 'GK', 'CB', 'LB', 'RB', 'CDM', 'CM', 'CAM', 'LW', 'RW', 'ST'];
  MarketData? _d;
  Object? _err;
  String _pos = 'All', _q = '';
  int? _league;
  double _age = 40, _ovr = 50;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final d = await loadMarket(widget.db,
          pos: _pos, leagueId: _league, maxAge: _age.round(), minOvr: _ovr.round(), q: _q);
      if (mounted) {
        setState(() {
          _d = d;
          _err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  String _pct(double x) => '${(x * 100).round()}%';

  Future<void> _bid(MarketTarget t) async {
    final d = _d!;
    final p = t.p;
    var fm = 1.0, wm = 1.0, years = 3.0;
    final go = await showModalBottomSheet<(int, int, int)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final fee = (p.value * fm / 10000).round() * 10000;
        final wage = (p.wagePerWeek * wm / 100).round() * 100;
        final ch = bidChance(
            fee: fee,
            value: p.value,
            sellerBudget: t.club.budget,
            myRep: d.me.reputation,
            sellerRep: t.club.reputation,
            wage: wage,
            curWage: p.wagePerWeek);
        final afford = fee <= d.me.budget;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.fullName, style: Theme.of(ctx).textTheme.titleLarge),
            Text('${p.positions.replaceAll(',', '/')} · age ${p.age} · OVR ${p.overall} · POT ${p.potential} · ${t.club.name}'),
            Text('Value ${fmtMoney(p.value)} · Wage ${fmtMoney(p.wagePerWeek)}/wk · Budget ${fmtMoney(d.me.budget)}'),
            const SizedBox(height: 8),
            Text('Fee ${fmtMoney(fee)}'),
            Slider(value: fm, min: 0.7, max: 2.0, divisions: 26, onChanged: (v) => set(() => fm = v)),
            Text('Wage ${fmtMoney(wage)}/wk'),
            Slider(value: wm, min: 0.8, max: 2.0, divisions: 12, onChanged: (v) => set(() => wm = v)),
            Text('Contract ${years.round()} years'),
            Slider(value: years, min: 1, max: 5, divisions: 4, onChanged: (v) => set(() => years = v)),
            Text('Club ${_pct(ch.club)} · Player ${_pct(ch.player)} · Overall ${_pct(ch.club * ch.player)}'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: afford ? () => Navigator.pop(ctx, (fee, wage, years.round())) : null,
                child: Text(afford ? 'Make bid' : 'Over budget'),
              ),
            ),
          ]),
        );
      }),
    );
    if (go == null || !mounted) return;
    final r = await makeBid(widget.db, p.id, fee: go.$1, wage: go.$2, years: go.$3);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.ok ? 'Deal done' : 'Bid rejected'),
        content: Text(r.msg),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Transfers')),
          body: Center(child: _err != null ? Text('$_err') : const CircularProgressIndicator()));
    }
    final open = windowOpen(d.season.currentDay);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Transfers'), actions: [
        Center(
            child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(fmtMoney(d.me.budget),
                    style: const TextStyle(fontWeight: FontWeight.bold)))),
      ]),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: open ? cs.primaryContainer : cs.errorContainer,
          padding: const EdgeInsets.all(8),
          child: Text('${windowText(d.season.year, d.season.currentDay)} · squad ${d.squadSize}/$maxSquad',
              textAlign: TextAlign.center),
        ),
        ExpansionTile(
          title: const Text('Filters'),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name'),
              onSubmitted: (v) {
                _q = v;
                _reload();
              },
            ),
            Row(children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _pos,
                  isExpanded: true,
                  items: [for (final p in _positions) DropdownMenuItem(value: p, child: Text(p))],
                  onChanged: (v) {
                    setState(() => _pos = v!);
                    _reload();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int?>(
                  value: _league,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All leagues')),
                    for (final l in d.leagues)
                      DropdownMenuItem<int?>(value: l.id, child: Text(l.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    setState(() => _league = v);
                    _reload();
                  },
                ),
              ),
            ]),
            Text('Min overall ${_ovr.round()}'),
            Slider(
                value: _ovr,
                min: 40,
                max: 90,
                divisions: 50,
                onChanged: (v) => setState(() => _ovr = v),
                onChangeEnd: (_) => _reload()),
            Text('Max age ${_age.round()}'),
            Slider(
                value: _age,
                min: 16,
                max: 40,
                divisions: 24,
                onChanged: (v) => setState(() => _age = v),
                onChangeEnd: (_) => _reload()),
          ],
        ),
        Expanded(
          child: d.results.isEmpty
              ? const Center(child: Text('No players found'))
              : ListView(children: [
                  for (final t in d.results)
                    ListTile(
                      dense: true,
                      onTap: () => _bid(t),
                      leading: CircleAvatar(
                          radius: 16,
                          child: Text(t.p.positions.split(',').first,
                              style: const TextStyle(fontSize: 10))),
                      title: Text(t.p.fullName),
                      subtitle: Text('${t.club.name} · ${t.league.name} · ${t.p.age}y'),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${t.p.overall}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(fmtMoney(t.p.value), style: const TextStyle(fontSize: 11)),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}
