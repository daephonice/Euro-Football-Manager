import 'package:drift/drift.dart' show OrderingTerm, innerJoin, BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'brand.dart';
import 'db/career.dart';
import 'db/database.dart';
import 'db/facilities.dart';
import 'engine/match.dart';
import 'match_screen.dart';
import 'util.dart';

class _Form {
  final int pos, total, value, wage;
  final List<String> last;
  final double? gf, ga;
  _Form(this.pos, this.total, this.value, this.wage, this.last, this.gf, this.ga);
}

Future<_Form> _formFor(AppDatabase db, LiveMatchday lm, Side s) async {
  final id = s.clubId;
  final f = db.fixtures, m = db.matchResults;
  final (pos, total) = await leaguePosition(db, lm.season.id, id);
  final rows = await (db.select(f).join([innerJoin(m, m.fixtureId.equalsExp(f.id))])
        ..where(f.seasonId.equals(lm.season.id) & (f.homeClubId.equals(id) | f.awayClubId.equals(id)))
        ..orderBy([OrderingTerm.desc(f.day)]))
      .get();
  final last = <String>[];
  var gf = 0, ga = 0;
  for (final r in rows) {
    final fx = r.readTable(f), mr = r.readTable(m);
    final home = fx.homeClubId == id;
    final a = home ? mr.homeGoals : mr.awayGoals, b = home ? mr.awayGoals : mr.homeGoals;
    gf += a;
    ga += b;
    if (last.length < 5) {
      last.add(a > b ? 'W' : a < b ? 'L' : (mr.winnerClubId == null ? 'D' : (mr.winnerClubId == id ? 'W' : 'L')));
    }
  }
  final ps = await (db.select(db.players)..where((t) => t.id.isIn([for (final p in s.xi) p.id]))).get();
  return _Form(pos, total, ps.fold(0, (a, p) => a + p.value), ps.fold(0, (a, p) => a + p.wagePerWeek),
      last, rows.isEmpty ? null : gf / rows.length, rows.isEmpty ? null : ga / rows.length);
}

const _strengthRows = <(String, List<String>)>[
  ('DEF', ['defending', 'tackling']),
  ('PASS', ['passing', 'vision']),
  ('ATT', ['finishing', 'shooting']),
  ('SKILL', ['dribbling', 'technique']),
  ('PHY', ['physical', 'strength', 'stamina']),
  ('PACE', ['pace', 'acceleration']),
];

double _avgAttr(Side s, List<String> keys) {
  var t = 0.0, n = 0;
  for (var i = 0; i < s.xi.length; i++) {
    if (s.slots[i] == 'GK') continue;
    for (final k in keys) {
      t += s.xi[i].attrs[k] ?? 50;
    }
    n += keys.length;
  }
  return n == 0 ? 0 : t / n;
}

double _fit(Side s) =>
    s.xi.isEmpty ? 0 : s.xi.fold<int>(0, (a, p) => a + p.fitness) / s.xi.length;

Color _ovrColor(int v) => v >= 75 ? volt : (v >= 60 ? bone : mist);

class PreMatchScreen extends StatefulWidget {
  final AppDatabase db;
  final LiveMatchday lm;
  const PreMatchScreen(this.db, this.lm, {super.key});
  @override
  State<PreMatchScreen> createState() => _PreState();
}

class _PreState extends State<PreMatchScreen> {
  int _tab = 0, _team = 0;
  late final MatchSim sim = widget.lm.mySim!;
  late final int me = widget.lm.mySide;
  late final Future<List<_Form>> _forms =
      Future.wait([for (final s in sim.sides) _formFor(widget.db, widget.lm, s)]);

  Side _side(int mineFirst) => sim.sides[mineFirst == 0 ? me : 1 - me];
  String _name(Side s) => widget.lm.names[s.clubId]!;

  Future<void> _go() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MatchScreen(widget.db, widget.lm)));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = _side(0), b = _side(1);
    final fx = widget.lm.mine!;
    return Theme(
      data: brandTheme(Brightness.dark),
      child: Scaffold(
        backgroundColor: ink,
        body: BrandBg(
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(children: [
                  IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Ico('back')),
                  Expanded(child: Text(fx.competition.toUpperCase(), style: hStyle(18))),
                  Text('ROUND ${fx.round}', style: lStyle(volt)),
                ]),
              ),
              FutureBuilder<List<_Form>>(
                future: _forms,
                builder: (_, s) {
                  final f = s.data;
                  Widget team(Side sd, Color c, _Form? fm) => Expanded(
                        child: Column(children: [
                          Crest(_name(sd), color: c),
                          const SizedBox(height: 8),
                          Text(_name(sd),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: hStyle(15)),
                          const SizedBox(height: 3),
                          Text(fm == null ? ' ' : '${ordinal(fm.pos)} of ${fm.total}', style: lStyle()),
                        ]),
                      );
                  final fa = f == null ? null : f[me == 0 ? 0 : 1];
                  final fb = f == null ? null : f[me == 0 ? 1 : 0];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      team(a, volt, fa),
                      Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text('VS', style: hStyle(18, mist))),
                      team(b, sky, fb),
                    ]),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BrandButton('Go to match', onTap: _go),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: inkLine),
              Expanded(
                child: switch (_tab) {
                  0 => _lineups(a, b),
                  1 => _pitch(),
                  2 => _strength(a, b),
                  _ => _formTab(),
                },
              ),
              _tabs(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    const t = [('list', 'Lineups'), ('board', 'Pitch'), ('bars', 'Strength'), ('trend', 'Form')];
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

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Row(children: [
          Container(width: 4, height: 14, color: volt),
          const SizedBox(width: 10),
          Text(t.toUpperCase(), style: hStyle(15)),
        ]),
      );

  Widget _chip(String t) => Container(
        width: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(border: Border.all(color: inkLine), borderRadius: BorderRadius.circular(3)),
        child: Text(t, style: lStyle(bone)),
      );

  Widget _pl(SimPlayer p, String slot, bool left, Color c) {
    final o = ratingAt(p, slot).round();
    return Expanded(
      child: Column(crossAxisAlignment: left ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bStyle(14, c)),
        const SizedBox(height: 2),
        Text('OVR $o  ·  FIT ${p.fitness}', style: lStyle(_ovrColor(o).withOpacity(0.85))),
      ]),
    );
  }

  Widget _lineups(Side a, Side b) {
    final n = a.xi.length > b.xi.length ? a.xi.length : b.xi.length;
    Widget row(SimPlayer? p, String? sp, SimPlayer? q, String? sq, {bool bench = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          child: Row(children: [
            p == null ? const Expanded(child: SizedBox()) : _pl(p, sp!, true, volt),
            const SizedBox(width: 10),
            _chip(sp ?? ''),
            const SizedBox(width: 6),
            _chip(sq ?? ''),
            const SizedBox(width: 10),
            q == null ? const Expanded(child: SizedBox()) : _pl(q, sq!, false, sky),
          ]),
        );
    final m = a.bench.length > b.bench.length ? a.bench.length : b.bench.length;
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      _title('Starting eleven'),
      for (var i = 0; i < n; i++)
        row(i < a.xi.length ? a.xi[i] : null, i < a.xi.length ? a.slots[i] : null,
            i < b.xi.length ? b.xi[i] : null, i < b.xi.length ? b.slots[i] : null),
      _title('Substitutes'),
      for (var i = 0; i < m; i++)
        row(i < a.bench.length ? a.bench[i] : null, i < a.bench.length ? a.bench[i].primary : null,
            i < b.bench.length ? b.bench[i] : null, i < b.bench.length ? b.bench[i].primary : null,
            bench: true),
    ]);
  }

  Widget _pitch() {
    final s = sim.sides[_team == 0 ? me : 1 - me];
    final c = _team == 0 ? volt : sky;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _team = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: i == _team ? (i == 0 ? volt : sky) : inkLine, width: i == _team ? 3 : 1))),
                  child: Text(_name(_side(i)).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: lStyle(i == _team ? bone : mist)),
                ),
              ),
            ),
        ]),
      ),
      Text('${s.tactics.formation}', style: hStyle(16, c)),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: LayoutBuilder(builder: (_, bc) {
            final w = bc.maxWidth, h = bc.maxHeight;
            final pts = _layout(s.slots);
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
              for (var i = 0; i < s.xi.length; i++)
                Positioned(
                  left: pts[i].dx * w - 32,
                  top: pts[i].dy * h - 18,
                  width: 64,
                  child: Column(children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: ink, shape: BoxShape.circle, border: Border.all(color: c, width: 1.8)),
                      child: Text(s.slots[i], style: lStyle(c).copyWith(fontSize: 11)),
                    ),
                    const SizedBox(height: 3),
                    Text(s.xi[i].name.split(' ').last.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: lStyle(bone).copyWith(fontSize: 10, letterSpacing: 0.8)),
                    Text('${ratingAt(s.xi[i], s.slots[i]).round()}',
                        style: lStyle(_ovrColor(ratingAt(s.xi[i], s.slots[i]).round())).copyWith(fontSize: 11)),
                  ]),
                ),
            ]);
          }),
        ),
      ),
    ]);
  }

  List<Offset> _layout(List<String> slots) {
    final hasAm = slots.contains('CAM');
    String row(String s) => switch (s) {
          'GK' => 'gk',
          'CB' || 'LB' || 'RB' => 'def',
          'CDM' => 'dm',
          'CM' => 'cm',
          'CAM' => 'am',
          'LW' || 'RW' => hasAm ? 'am' : 'att',
          _ => 'att',
        };
    const y = {'gk': 0.9, 'def': 0.72, 'dm': 0.58, 'cm': 0.46, 'am': 0.34, 'att': 0.14};
    int rank(String s) => (s == 'LB' || s == 'LW') ? 0 : (s == 'RB' || s == 'RW') ? 2 : 1;
    final groups = <String, List<int>>{};
    for (var i = 0; i < slots.length; i++) {
      (groups[row(slots[i])] ??= []).add(i);
    }
    final out = List<Offset>.filled(slots.length, Offset.zero);
    groups.forEach((k, idx) {
      idx.sort((p, q) => rank(slots[p]).compareTo(rank(slots[q])));
      for (var j = 0; j < idx.length; j++) {
        out[idx[j]] = Offset(0.14 + 0.72 * (j + 0.5) / idx.length, y[k]!);
      }
    });
    return out;
  }

  Widget _strength(Side a, Side b) {
    Widget line(String k, double x, double y) {
      final aw = x >= y;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        child: Column(children: [
          Row(children: [
            Text(x.toStringAsFixed(1), style: hStyle(18, aw ? volt : bone)),
            Expanded(child: Text(k, textAlign: TextAlign.center, style: lStyle())),
            Text(y.toStringAsFixed(1), style: hStyle(18, !aw ? sky : bone)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                flex: (x * 10).round().clamp(1, 1000),
                child: Container(height: 5, color: volt.withOpacity(aw ? 1 : 0.4))),
            const SizedBox(width: 3),
            Expanded(
                flex: (y * 10).round().clamp(1, 1000),
                child: Container(height: 5, color: sky.withOpacity(!aw ? 1 : 0.4))),
          ]),
        ]),
      );
    }

    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      _title('Average strength'),
      for (final r in _strengthRows) line(r.$1, _avgAttr(a, r.$2), _avgAttr(b, r.$2)),
      line('FIT', _fit(a), _fit(b)),
    ]);
  }

  Widget _formTab() => FutureBuilder<List<_Form>>(
        future: _forms,
        builder: (_, s) {
          if (s.hasError) return Center(child: Text('${s.error}', style: bStyle()));
          if (!s.hasData) return const Center(child: CircularProgressIndicator(color: volt));
          final a = s.data![me == 0 ? 0 : 1], b = s.data![me == 0 ? 1 : 0];
          String avg(double? v) => v == null ? '-' : v.toStringAsFixed(1);
          Widget row(String k, String x, String y) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(children: [
                  Expanded(child: Text(x, textAlign: TextAlign.left, style: hStyle(18, volt))),
                  Text(k.toUpperCase(), style: lStyle()),
                  Expanded(child: Text(y, textAlign: TextAlign.right, style: hStyle(18, sky))),
                ]),
              );
          Widget dots(List<String> l, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
                for (final r in l)
                  Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: r == 'W' ? c : Colors.transparent,
                        border: Border.all(color: r == 'L' ? alert : c, width: 1.5),
                        borderRadius: BorderRadius.circular(3)),
                    child: Text(r, style: lStyle(r == 'W' ? ink : (r == 'L' ? alert : c))),
                  ),
                if (l.isEmpty) Text('-', style: bStyle(16, mist)),
              ]);
          return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
            _title('Season form'),
            row('Goals scored / game', avg(a.gf), avg(b.gf)),
            row('Goals conceded / game', avg(a.ga), avg(b.ga)),
            row('Starters value', fmtMoney(a.value), fmtMoney(b.value)),
            row('Starters wages / wk', fmtMoney(a.wage), fmtMoney(b.wage)),
            _title('Last 5 results'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                dots(a.last, volt),
                dots(b.last, sky),
              ]),
            ),
          ]);
        },
      );
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = volt.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final w = s.width, h = s.height;
    c.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    c.drawLine(Offset(0, h / 2), Offset(w, h / 2), p);
    c.drawCircle(Offset(w / 2, h / 2), w * 0.14, p);
    c.drawRect(Rect.fromLTWH(w * 0.22, 0, w * 0.56, h * 0.16), p);
    c.drawRect(Rect.fromLTWH(w * 0.36, 0, w * 0.28, h * 0.06), p);
    c.drawRect(Rect.fromLTWH(w * 0.22, h * 0.84, w * 0.56, h * 0.16), p);
    c.drawRect(Rect.fromLTWH(w * 0.36, h * 0.94, w * 0.28, h * 0.06), p);
  }

  @override
  bool shouldRepaint(_) => false;
}
