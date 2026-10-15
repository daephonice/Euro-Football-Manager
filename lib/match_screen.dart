import 'dart:async';
import 'package:flutter/material.dart';
import 'brand.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'engine/match.dart';
import 'tactics.dart';

class MatchScreen extends StatefulWidget {
  final AppDatabase db;
  final LiveMatchday lm;
  const MatchScreen(this.db, this.lm, {super.key});
  @override
  State<MatchScreen> createState() => _MatchState();
}

class _MatchState extends State<MatchScreen> {
  late final MatchSim sim = widget.lm.mySim!;
  late final int me = widget.lm.mySide;
  late final List<String> club = [
    widget.lm.names[widget.lm.mine!.homeClubId]!,
    widget.lm.names[widget.lm.mine!.awayClubId]!,
  ];
  Timer? _timer;
  int _ms = 400;
  int _seen = 0;
  int _tab = 0;
  bool _busy = false;

  bool get _running => _timer != null;
  Color _col(int side) => side == me ? volt : sky;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _ms), (_) => _tick());
    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() {});
  }

  void _tick() {
    sim.step();
    var stop = sim.finished || sim.minute == 45;
    for (; _seen < sim.events.length; _seen++) {
      final e = sim.events[_seen];
      if (e.side == me && (e.type == 'injury' || e.type == 'red')) stop = true;
    }
    if (stop) {
      _pause();
    } else {
      setState(() {});
    }
  }

  Future<void> _finish() async {
    _pause();
    setState(() => _busy = true);
    try {
      await finishMatchday(widget.db, widget.lm);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _sub(SimPlayer out, String slot) async {
    _pause();
    final bench = sim.sides[me].bench;
    final pick = await showDialog<SimPlayer>(
      context: context,
      builder: (ctx) => Theme(
        data: brandTheme(Brightness.dark),
        child: SimpleDialog(
          backgroundColor: inkRaised,
          title: Text('REPLACE ${out.name.toUpperCase()} ($slot)', style: hStyle(15, volt)),
          children: [
            for (final b in bench)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, b),
                child: Text('${b.primary}   ${b.name}   ·   ${ratingAt(b, slot).round()} at $slot',
                    style: bStyle(14)),
              ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    if (!sim.substitute(me, out.id, pick.id)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No substitutions left')));
    }
    setState(() {});
  }

  Future<void> _tactics() async {
    _pause();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: inkRaised,
      builder: (_) => Theme(
        data: brandTheme(Brightness.dark),
        child: StatefulBuilder(builder: (ctx, setM) {
          final t = sim.sides[me].tactics;
          void upd(VoidCallback f) {
            f();
            setM(() {});
            setState(() {});
          }

          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Row(children: [
                Expanded(child: Text('TACTICS', style: hStyle(18, volt))),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Ico('close')),
              ]),
              TacticsControls(
                enabled: !sim.finished,
                formation: t.formation,
                mentality: t.mentality,
                verticality: t.verticality,
                onFormation: (f) => upd(() => sim.setFormation(me, f)),
                onMentality: (m) => upd(() => sim.setStyle(me, mentality: m)),
                onVerticality: (v) => upd(() => sim.setStyle(me, verticality: v)),
                onStyle: (m, v) => upd(() => sim.setStyle(me, mentality: m, verticality: v)),
              ),
            ]),
          );
        }),
      ),
    );
  }

  String get _status => sim.minute == 0
      ? 'KICK OFF'
      : sim.finished
          ? (widget.lm.mine!.knockout && sim.goals[0] == sim.goals[1] ? 'FT - EXTRA TIME / PENS' : 'FULL TIME')
          : (sim.minute == 45 && !_running ? 'HALF TIME' : "${sim.minute}'");

  int _count(int side, String type) =>
      sim.events.where((e) => e.side == side && e.type == type).length;

  double _live(SimPlayer p, int side) {
    var x = 6.0;
    for (final e in sim.events) {
      if (e.side != side) continue;
      if (e.type == 'goal' && e.playerId == p.id) x += 1.0;
      if (e.type == 'goal' && e.other == p.name) x += 0.6;
      if (e.type == 'yellow' && e.playerId == p.id) x -= 0.2;
      if (e.type == 'red' && e.playerId == p.id) x -= 1.5;
    }
    if (sim.minute > 0) {
      final gf = sim.goals[side], ga = sim.goals[1 - side];
      x += gf > ga ? 0.3 : (gf < ga ? -0.3 : 0);
    }
    return (x.clamp(3.0, 10.0) * 10).round() / 10;
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Theme(
          data: brandTheme(Brightness.dark),
          child: Scaffold(
            backgroundColor: ink,
            body: BrandBg(
              child: SafeArea(
                child: Column(children: [
                  _board(),
                  _possession(),
                  _controls(),
                  Container(height: 1, color: inkLine),
                  Expanded(child: [_stats, _events, _ratings, _squad][_tab]()),
                  _tabs(),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _board() {
    Widget team(int i) => Expanded(
          child: Column(children: [
            Crest(club[i], color: _col(i), size: 44),
            const SizedBox(height: 6),
            Text(club[i], maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: hStyle(13)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(children: [
        Text('${widget.lm.mine!.competition.toUpperCase()}  ·  ROUND ${widget.lm.mine!.round}', style: lStyle()),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          team(0),
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                border: Border.all(color: volt, width: 1.6),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14), bottomRight: Radius.circular(14))),
            child: Column(children: [
              Text('${sim.goals[0]}  -  ${sim.goals[1]}', style: hStyle(34).copyWith(letterSpacing: 3)),
              const SizedBox(height: 2),
              Text(_status, style: lStyle(volt)),
            ]),
          ),
          team(1),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
              value: sim.minute / 90, minHeight: 3, backgroundColor: inkLine, color: volt),
        ),
      ]),
    );
  }

  Widget _possession() {
    final p = sim.minute == 0 ? [50, 50] : sim.poss;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Column(children: [
        Row(children: [
          Text('${p[0]}%', style: hStyle(14, _col(0))),
          Expanded(child: Text('POSSESSION', textAlign: TextAlign.center, style: lStyle())),
          Text('${p[1]}%', style: hStyle(14, _col(1))),
        ]),
        const SizedBox(height: 5),
        Row(children: [
          Expanded(flex: p[0], child: Container(height: 5, color: _col(0))),
          const SizedBox(width: 3),
          Expanded(flex: p[1], child: Container(height: 5, color: _col(1))),
        ]),
      ]),
    );
  }

  Widget _controls() {
    if (_busy) {
      return const SizedBox(height: 70, child: Center(child: CircularProgressIndicator(color: volt)));
    }
    if (sim.finished) {
      return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: BrandButton('Continue', onTap: _finish));
    }
    Widget speed(String l, int ms) => GestureDetector(
          onTap: () {
            _ms = ms;
            if (_running) _play();
            setState(() {});
          },
          child: Container(
            width: 46,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _ms == ms ? volt : Colors.transparent,
                border: Border.all(color: _ms == ms ? volt : inkLine),
                borderRadius: BorderRadius.circular(3)),
            child: Text(l, style: lStyle(_ms == ms ? ink : mist)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(children: [
        Row(children: [
          Expanded(
              flex: 3,
              child: BrandButton(
                  sim.minute == 0 ? 'Kick off' : (_running ? 'Pause' : 'Resume'),
                  onTap: _running ? _pause : _play)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: BrandButton('Tactics', filled: false, onTap: _tactics)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          speed('1X', 400),
          const SizedBox(width: 6),
          speed('2X', 150),
          const SizedBox(width: 6),
          speed('4X', 50),
          const Spacer(),
          GestureDetector(
            onTap: () {
              sim.playAll();
              _pause();
            },
            child: Row(children: [
              Text('SKIP TO END', style: lStyle(volt)),
              const SizedBox(width: 6),
              const Ico('fast', size: 18, color: volt),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _tabs() {
    const t = [('bars', 'Stats'), ('list', 'Events'), ('user', 'Ratings'), ('squad', 'Squad')];
    return Container(
      decoration: const BoxDecoration(color: inkRaised, border: Border(top: BorderSide(color: inkLine))),
      child: Row(children: [
        for (var i = 0; i < t.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: i == _tab ? volt : Colors.transparent, width: 3))),
                child: Column(children: [
                  Ico(t[i].$1, size: 22, color: i == _tab ? volt : mist),
                  const SizedBox(height: 4),
                  Text(t[i].$2.toUpperCase(), style: lStyle(i == _tab ? volt : mist)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _stats() {
    Widget row(String k, num a, num b) {
      final t = a + b;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(children: [
          Row(children: [
            Text('$a', style: hStyle(17, _col(0))),
            Expanded(child: Text(k.toUpperCase(), textAlign: TextAlign.center, style: lStyle())),
            Text('$b', style: hStyle(17, _col(1))),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(flex: t == 0 ? 1 : (a * 100 ~/ t).clamp(1, 99), child: Container(height: 3, color: t == 0 ? inkLine : _col(0))),
            const SizedBox(width: 3),
            Expanded(flex: t == 0 ? 1 : (b * 100 ~/ t).clamp(1, 99), child: Container(height: 3, color: t == 0 ? inkLine : _col(1))),
          ]),
        ]),
      );
    }

    return ListView(padding: const EdgeInsets.only(top: 6, bottom: 16), children: [
      row('Goals', sim.goals[0], sim.goals[1]),
      row('Attempts', sim.shots[0], sim.shots[1]),
      row('Yellow cards', _count(0, 'yellow'), _count(1, 'yellow')),
      row('Red cards', _count(0, 'red'), _count(1, 'red')),
      row('Injuries', _count(0, 'injury'), _count(1, 'injury')),
      row('Substitutions', sim.sides[0].subsUsed, sim.sides[1].subsUsed),
    ]);
  }

  Widget _events() {
    if (sim.events.isEmpty) {
      return Center(child: Text(sim.minute == 0 ? 'MATCH NOT STARTED' : 'NO KEY EVENTS YET', style: lStyle()));
    }
    (String, Color) ic(String t) => switch (t) {
          'goal' => ('ball', volt),
          'yellow' => ('card', amber),
          'red' => ('card', alert),
          'injury' => ('cross', alert),
          _ => ('transfer', sky),
        };
    String txt(MatchEvent e) => switch (e.type) {
          'goal' => '${e.name}${e.other != null ? '  (assist ${e.other})' : ''}',
          'yellow' => '${e.name}  -  yellow card',
          'red' => '${e.name}  -  sent off',
          'injury' => '${e.name}  -  injured',
          _ => '${e.name} on for ${e.other}',
        };
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: [
      for (final e in sim.events.reversed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(textDirection: e.side == 0 ? TextDirection.ltr : TextDirection.rtl, children: [
            SizedBox(
                width: 38,
                child: Text("${e.minute}'",
                    textAlign: e.side == 0 ? TextAlign.left : TextAlign.right, style: hStyle(14, mist))),
            Ico(ic(e.type).$1, size: 20, color: ic(e.type).$2),
            const SizedBox(width: 10),
            Expanded(
                child: Text(txt(e),
                    textAlign: e.side == 0 ? TextAlign.left : TextAlign.right,
                    style: bStyle(14, _col(e.side)))),
          ]),
        ),
    ]);
  }

  Widget _ratings() {
    Widget col(int side) {
      final s = sim.sides[side];
      return Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(club[side].toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: lStyle(_col(side))),
          const SizedBox(height: 8),
          for (final p in s.xi)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                  width: 38,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: _col(side)), borderRadius: BorderRadius.circular(3)),
                  child: Text(_live(p, side).toStringAsFixed(1), style: lStyle(_col(side))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bStyle(12))),
              ]),
            ),
        ]),
      );
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [col(me), const SizedBox(width: 14), col(1 - me)]),
    ]);
  }

  Widget _squad() {
    final s = sim.sides[me];
    final canSub = !sim.finished && (sim.minute == 0 || s.subsUsed < 5) && s.bench.isNotEmpty;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 16), children: [
      Text(sim.minute == 0 ? 'FREE CHANGES BEFORE KICK OFF' : 'SUBSTITUTIONS ${s.subsUsed} / 5', style: lStyle(volt)),
      const SizedBox(height: 8),
      for (var j = 0; j < s.xi.length; j++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 38, child: Text(s.slots[j], style: lStyle(volt))),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.xi[j].name, style: bStyle(14)),
              Text('OVR ${ratingAt(s.xi[j], s.slots[j]).round()}  ·  FIT ${s.xi[j].fitness}', style: lStyle()),
            ])),
            TextButton(
              onPressed: canSub ? () => _sub(s.xi[j], s.slots[j]) : null,
              child: Text('SUB', style: lStyle(canSub ? volt : inkLine)),
            ),
          ]),
        ),
      const SizedBox(height: 14),
      Text('BENCH', style: lStyle(volt)),
      const SizedBox(height: 6),
      for (final b in s.bench)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 38, child: Text(b.primary, style: lStyle())),
            Expanded(child: Text(b.name, style: bStyle(14))),
            Text('FIT ${b.fitness}', style: lStyle()),
          ]),
        ),
    ]);
  }
}
