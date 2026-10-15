import 'package:flutter/material.dart';
import 'brand.dart';
import 'competitions.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'db/facilities.dart';
import 'db/market.dart';
import 'db/training.dart';
import 'engine/fixtures.dart';
import 'facilities.dart';
import 'finances.dart';
import 'honours.dart';
import 'match_screen.dart';
import 'menu.dart';
import 'settings.dart';
import 'slots.dart';
import 'squad.dart';
import 'tactics.dart';
import 'training.dart';
import 'transfers.dart';
import 'util.dart';

class _Home {
  final HubData hub;
  final FinanceData fin;
  final List<Player> squad;
  final FacilityData fac;
  final String manager;
  _Home(this.hub, this.fin, this.squad, this.fac, this.manager);
}

class HubScreen extends StatefulWidget {
  final AppDatabase db;
  const HubScreen(this.db, {super.key});
  @override
  State<HubScreen> createState() => _HubState();
}

class _HubState extends State<HubScreen> {
  late Future<_Home> _f = _load();
  bool _busy = false;

  Future<_Home> _load() async {
    final d = await loadHub(widget.db);
    await Slots.sync(d);
    final save = await loadCareer(widget.db);
    return _Home(d, await loadFinance(widget.db), await loadSquad(widget.db),
        await loadFacilities(widget.db), save.name);
  }

  void _reload() => setState(() => _f = _load());

  Future<void> _go(Widget w) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    if (mounted) _reload();
  }

  void _err(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }

  Future<void> _play() async {
    setState(() => _busy = true);
    try {
      var lm = await prepareMatchday(widget.db);
      while (lm != null && lm.mine == null) {
        await finishMatchday(widget.db, lm);
        lm = await prepareMatchday(widget.db);
      }
      if (lm != null && mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => MatchScreen(widget.db, lm!)));
      }
    } catch (e) {
      _err(e);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _reload();
  }

  Future<void> _next() async {
    setState(() => _busy = true);
    try {
      await startNextSeason(widget.db);
      if (mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => HonoursScreen(widget.db)));
      }
    } catch (e) {
      _err(e);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _reload();
  }

  void _about() => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Euro Football Manager'),
          content: const Text('Version $kVersion\nAn offline European football management game.'),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
        ),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<_Home>(
        future: _f,
        builder: (_, s) {
          if (s.hasError) return Scaffold(body: Center(child: Text('${s.error}')));
          if (!s.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return _view(context, s.data!);
        },
      );

  Widget _view(BuildContext context, _Home h) {
    final d = h.hub;
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final yy = '${(d.season.year + 1) % 100}'.padLeft(2, '0');
    final week = d.season.currentDay ~/ 7 + 1;
    final nat = Slots.active == null ? null : Slots.get(Slots.active!)?.nationality;

    return Scaffold(
      drawer: _drawer(context, h),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          Row(children: [
            Builder(
                builder: (c) => IconButton(
                    onPressed: () => Scaffold.of(c).openDrawer(),
                    icon: Ico('menu', color: cs.primary))),
            Expanded(
              child: Column(children: [
                Text(d.me.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hStyle(19, cs.onSurface)),
                const SizedBox(height: 3),
                Text('${d.league.name}  ·  ${d.season.year}/$yy  ·  WEEK $week',
                    style: lStyle(cs.onSurface.withOpacity(0.55))),
              ]),
            ),
            IconButton(
                onPressed: () => Slots.setTheme(dark ? ThemeMode.light : ThemeMode.dark),
                icon: Ico(dark ? 'sun' : 'moon', color: cs.primary)),
            PopupMenuButton<int>(
              icon: Ico('more', color: cs.primary),
              onSelected: (v) {
                if (v == 0) _about();
                if (v == 1) showPolicy(context);
                if (v == 2) Navigator.of(context).popUntil((r) => r.isFirst);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0, child: Text('About')),
                PopupMenuItem(value: 1, child: Text('Privacy policy')),
                PopupMenuItem(value: 2, child: Text('Save and exit')),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          _manager(cs, h.manager, nat),
          const SizedBox(height: 14),
          _matchCard(cs, h),
          _financeCard(cs, h),
          _clubCard(cs, h),
          _leagueCard(cs, h),
          _facilityCard(cs, h),
        ]),
      ),
    );
  }

  Widget _manager(ColorScheme cs, String name, String? nat) => Row(children: [
        Ico('user', size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(name, style: bStyle(15, cs.onSurface)),
        if (nat != null) Text('   ·   $nat', style: bStyle(14, cs.onSurface.withOpacity(0.55))),
      ]);

  Widget _card(ColorScheme cs, String title, Widget child,
      {String? action, VoidCallback? onTap}) {
    final line = cs.onSurface.withOpacity(0.14);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.045),
        border: Border.all(color: line),
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
            topRight: Radius.circular(3),
            bottomLeft: Radius.circular(3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(children: [
              Container(width: 4, height: 14, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(title.toUpperCase(), style: hStyle(15, cs.onSurface))),
              if (action != null) ...[
                Text(action.toUpperCase(), style: lStyle(cs.primary)),
                const SizedBox(width: 4),
                Ico('next', size: 16, color: cs.primary),
              ],
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), child: child),
      ]),
    );
  }

  Widget _kv(ColorScheme cs, String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(k.toUpperCase(), style: lStyle(cs.onSurface.withOpacity(0.55)))),
          Text(v, style: hStyle(16, color ?? cs.onSurface).copyWith(letterSpacing: 0.8)),
        ]),
      );

  Widget _matchCard(ColorScheme cs, _Home h) {
    final d = h.hub;
    final first = d.next.isEmpty ? null : d.next.first;
    Widget action;
    if (_busy) {
      action = const SizedBox(height: 54, child: Center(child: CircularProgressIndicator()));
    } else if (first != null) {
      action = BrandButton('Play match', onTap: _play, color: cs.primary);
    } else if (d.seasonOver) {
      action = BrandButton('Start next season', onTap: _next, color: cs.primary);
    } else {
      action = BrandButton('Simulate ahead', onTap: _play, color: cs.primary);
    }
    if (first == null) {
      return _card(
          cs,
          'Next match',
          Column(children: [
            Text(d.seasonOver ? 'Season complete' : 'No fixture scheduled',
                style: bStyle(16, cs.onSurface)),
            const SizedBox(height: 14),
            action,
          ]));
    }
    final home = first.homeClubId == d.me.id;
    final opp = d.clubs[home ? first.awayClubId : first.homeClubId]!;
    final up = d.next.skip(1).take(2).toList();
    return _card(
        cs,
        'Next match',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(border: Border.all(color: cs.primary)),
              child: Text(home ? 'HOME' : 'AWAY', style: lStyle(cs.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(opp.name, style: hStyle(21, cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          Text('${first.competition}  ·  Round ${first.round}  ·  ${dayLabel(d.season.year, first.day)}',
              style: bStyle(13, cs.onSurface.withOpacity(0.6))),
          const SizedBox(height: 14),
          action,
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: () => _go(TacticsScreen(widget.db)),
                child: Text('SET TACTICS', style: lStyle(cs.primary))),
          ),
          for (final f in up)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Expanded(
                    child: Text(
                        '${f.homeClubId == d.me.id ? 'H' : 'A'}  ${d.clubs[f.homeClubId == d.me.id ? f.awayClubId : f.homeClubId]!.name}',
                        style: bStyle(13, cs.onSurface.withOpacity(0.7)))),
                Text(dayLabel(d.season.year, f.day), style: bStyle(12, cs.onSurface.withOpacity(0.5))),
              ]),
            ),
        ]));
  }

  Widget _financeCard(ColorScheme cs, _Home h) {
    final net = h.fin.totals.values.fold<int>(0, (a, b) => a + b);
    return _card(
        cs,
        'Finances',
        Column(children: [
          _kv(cs, 'Budget', fmtMoney(h.fin.club.budget)),
          _kv(cs, 'Wage bill / week', fmtMoney(h.fin.wageBill)),
          _kv(cs, 'Season net', fmtMoney(net), color: net < 0 ? alert : null),
        ]),
        action: 'Finances',
        onTap: () => _go(FinancesScreen(widget.db)));
  }

  Widget _clubCard(ColorScheme cs, _Home h) {
    final value = h.squad.fold<int>(0, (a, p) => a + p.value);
    final avg = h.squad.isEmpty
        ? 0
        : (h.squad.fold<int>(0, (a, p) => a + p.age) / h.squad.length).toStringAsFixed(1);
    final top = [...h.squad]..sort((a, b) => b.overall.compareTo(a.overall));
    final best = top.take(11).fold<int>(0, (a, p) => a + p.overall);
    return _card(
        cs,
        'Club',
        Column(children: [
          _kv(cs, 'Squad value', fmtMoney(value)),
          _kv(cs, 'Squad size', '${h.squad.length}'),
          _kv(cs, 'Average age', '$avg'),
          _kv(cs, 'Best XI rating', top.length < 11 ? '-' : (best / 11).toStringAsFixed(1)),
        ]),
        action: 'Squad',
        onTap: () => _go(SquadScreen(widget.db)));
  }

  Widget _leagueCard(ColorScheme cs, _Home h) {
    final d = h.hub;
    final t = d.table;
    final mine = t.indexWhere((r) => r.club.id == d.me.id);
    final show = <int>[for (var i = 0; i < t.length && i < 3; i++) i];
    if (mine > 2) show.add(mine);
    Widget row(int i) {
      final r = t[i];
      final me = i == mine;
      final st = bStyle(14, me ? cs.primary : cs.onSurface)
          .copyWith(fontWeight: me ? FontWeight.w800 : FontWeight.w500);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 26, child: Text('${i + 1}', style: st)),
          Expanded(child: Text(r.club.name, style: st, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 44, child: Text('${r.gd > 0 ? '+' : ''}${r.gd}', style: st)),
          SizedBox(width: 32, child: Text('${r.pts}', textAlign: TextAlign.right, style: st)),
        ]),
      );
    }

    return _card(
        cs,
        d.league.name,
        Column(children: [
          Row(children: [
            const SizedBox(width: 26),
            Expanded(child: Text('CLUB', style: lStyle(cs.onSurface.withOpacity(0.5)))),
            SizedBox(width: 44, child: Text('GD', style: lStyle(cs.onSurface.withOpacity(0.5)))),
            SizedBox(
                width: 32,
                child: Text('PTS', textAlign: TextAlign.right, style: lStyle(cs.onSurface.withOpacity(0.5)))),
          ]),
          for (final i in show) row(i),
        ]),
        action: 'Competitions',
        onTap: () => _go(CompetitionsScreen(widget.db)));
  }

  Widget _facilityCard(ColorScheme cs, _Home h) {
    Widget pips(String k, int n) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(k.toUpperCase(), style: lStyle(cs.onSurface.withOpacity(0.55)))),
            Pips(n),
          ]),
        );
    final sp = h.fac.save.sponsorName.isEmpty ? 'Local partners' : h.fac.save.sponsorName;
    return _card(
        cs,
        'Facilities',
        Column(children: [
          pips('Stadium', h.fac.club.stadiumLevel),
          pips('Training ground', h.fac.club.trainingLevel),
          _kv(cs, 'Sponsor', sp),
        ]),
        action: 'Facilities',
        onTap: () => _go(FacilitiesScreen(widget.db)));
  }

  Widget _drawer(BuildContext context, _Home h) {
    final cs = Theme.of(context).colorScheme;
    Widget item(String icon, String label, VoidCallback t) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          leading: Ico(icon, color: cs.primary, size: 24),
          title: Text(label.toUpperCase(), style: hStyle(15, cs.onSurface)),
          onTap: () {
            Navigator.pop(context);
            t();
          },
        );
    return Drawer(
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.manager, style: hStyle(22, cs.onSurface)),
              const SizedBox(height: 6),
              Text(h.hub.me.name, style: bStyle(14, cs.onSurface.withOpacity(0.6))),
              const SizedBox(height: 14),
              Container(height: 2, color: cs.primary),
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              item('home', 'Home', () {}),
              item('squad', 'Squad', () => _go(SquadScreen(widget.db))),
              item('tactics', 'Tactics', () => _go(TacticsScreen(widget.db))),
              item('transfer', 'Transfers', () => _go(TransfersScreen(widget.db))),
              item('training', 'Training', () => _go(TrainingScreen(widget.db))),
              item('finances', 'Finances', () => _go(FinancesScreen(widget.db))),
              item('facility', 'Facilities', () => _go(FacilitiesScreen(widget.db))),
              item('trophy', 'Competitions', () => _go(CompetitionsScreen(widget.db))),
              item('award', 'Honours', () => _go(HonoursScreen(widget.db))),
              item('gear', 'Settings', () => _go(SettingsScreen(widget.db))),
              item('exit', 'Save and exit', () => Navigator.of(context).popUntil((r) => r.isFirst)),
            ]),
          ),
        ]),
      ),
    );
  }
}
