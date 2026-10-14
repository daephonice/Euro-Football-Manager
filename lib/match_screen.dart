import 'dart:async';
import 'package:flutter/material.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'engine/match.dart';
import 'tactics.dart';

String eventLine(MatchEvent e, String club) => switch (e.type) {
      'goal' => "${e.minute}' ⚽ ${e.name}${e.other != null ? ' (${e.other})' : ''} — $club",
      'yellow' => "${e.minute}' 🟨 ${e.name} — $club",
      'red' => "${e.minute}' 🟥 ${e.name} — $club",
      'injury' => "${e.minute}' 🚑 ${e.name} — $club",
      _ => "${e.minute}' 🔁 ${e.name} for ${e.other} — $club",
    };

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
  bool _busy = false;

  bool get _running => _timer != null;

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
      builder: (ctx) => SimpleDialog(
        title: Text('Replace ${out.name} ($slot)'),
        children: [
          for (final b in bench)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, b),
              child: Text('${b.primary}  ${b.name}  ·  ${ratingAt(b, slot).round()} at $slot'),
            ),
        ],
      ),
    );
    if (pick == null || !mounted) return;
    if (!sim.substitute(me, out.id, pick.id)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No substitutions left')));
    }
    setState(() {});
  }

  String get _status => sim.minute == 0
      ? 'Kick-off'
      : sim.finished
          ? (widget.lm.mine!.knockout && sim.goals[0] == sim.goals[1] ? 'FT · ET/pens next' : 'FT')
          : (sim.minute == 45 && !_running ? 'HT' : "${sim.minute}'");

  Widget _events() => ListView(padding: const EdgeInsets.all(12), children: [
        if (sim.minute > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
                'Shots ${sim.shots[0]}–${sim.shots[1]}   ·   Possession ${sim.poss[0]}%–${sim.poss[1]}%',
                textAlign: TextAlign.center),
          ),
        for (final e in sim.events.reversed) ListTile(dense: true, title: Text(eventLine(e, club[e.side]))),
      ]);

  Widget _lineup() {
    final s = sim.sides[me];
    final canSub = !sim.finished && (sim.minute == 0 || s.subsUsed < 5) && s.bench.isNotEmpty;
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(sim.minute == 0
            ? 'Free changes before kick-off'
            : 'Substitutions ${s.subsUsed}/5'),
      ),
      for (var j = 0; j < s.xi.length; j++)
        ListTile(
          dense: true,
          leading: SizedBox(width: 36, child: Text(s.slots[j])),
          title: Text(s.xi[j].name),
          subtitle: Text('${ratingAt(s.xi[j], s.slots[j]).round()} at ${s.slots[j]} · Fit ${s.xi[j].fitness}'),
          trailing: TextButton(
            onPressed: canSub ? () => _sub(s.xi[j], s.slots[j]) : null,
            child: const Text('Sub'),
          ),
        ),
      const Divider(),
      const Padding(padding: EdgeInsets.all(12), child: Text('Bench')),
      for (final b in s.bench)
        ListTile(
          dense: true,
          leading: SizedBox(width: 36, child: Text(b.primary)),
          title: Text(b.name),
          subtitle: Text('Fit ${b.fitness}'),
        ),
    ]);
  }

  Widget _tactics() {
    final t = sim.sides[me].tactics;
    return ListView(padding: const EdgeInsets.all(12), children: [
      TacticsControls(
        enabled: !sim.finished,
        formation: t.formation,
        mentality: t.mentality,
        verticality: t.verticality,
        onFormation: (f) => setState(() => sim.setFormation(me, f)),
        onMentality: (m) => setState(() => sim.setStyle(me, mentality: m)),
        onVerticality: (v) => setState(() => sim.setStyle(me, verticality: v)),
        onStyle: (m, v) => setState(() => sim.setStyle(me, mentality: m, verticality: v)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(automaticallyImplyLeading: false, title: Text(widget.lm.mine!.competition)),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(children: [
                Expanded(child: Text(club[0], textAlign: TextAlign.center, style: th.titleSmall)),
                Column(children: [
                  Text('${sim.goals[0]} – ${sim.goals[1]}', style: th.headlineMedium),
                  Text(_status),
                ]),
                Expanded(child: Text(club[1], textAlign: TextAlign.center, style: th.titleSmall)),
              ]),
            ),
            LinearProgressIndicator(value: sim.minute / 90),
            Padding(
              padding: const EdgeInsets.all(8),
              child: sim.finished
                  ? FilledButton(
                      onPressed: _busy ? null : _finish, child: const Text('Continue'))
                  : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      FilledButton.icon(
                        onPressed: _running ? _pause : _play,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(_running ? 'Pause' : 'Play'),
                      ),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 400, label: Text('1x')),
                          ButtonSegment(value: 150, label: Text('2x')),
                          ButtonSegment(value: 50, label: Text('4x')),
                        ],
                        selected: {_ms},
                        onSelectionChanged: (s) {
                          _ms = s.first;
                          if (_running) _play();
                          setState(() {});
                        },
                      ),
                      IconButton(
                        tooltip: 'Skip to end',
                        icon: const Icon(Icons.fast_forward),
                        onPressed: () {
                          sim.playAll();
                          _pause();
                        },
                      ),
                    ]),
            ),
            const TabBar(tabs: [Tab(text: 'Events'), Tab(text: 'Lineup'), Tab(text: 'Tactics')]),
            Expanded(child: TabBarView(children: [_events(), _lineup(), _tactics()])),
          ]),
        ),
      ),
    );
  }
}
