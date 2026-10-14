import 'dart:math';
import 'rating.dart';

class SimPlayer {
  final int id;
  final String name;
  final List<String> positions;
  final Map<String, int> attrs;
  int fitness;
  int form;
  SimPlayer(this.id, this.name, this.positions, this.attrs, this.fitness, this.form);
  String get primary => positions.first;
}

class Tactics {
  String formation;
  int mentality; // 0 ultra-def .. 4 ultra-att
  int verticality; // 0 low .. 2 high
  Tactics({this.formation = '4-3-3', this.mentality = 2, this.verticality = 1});
}

const formations = <String, List<String>>{
  '4-4-2': ['GK', 'LB', 'CB', 'CB', 'RB', 'LW', 'CM', 'CM', 'RW', 'ST', 'ST'],
  '4-3-3': ['GK', 'LB', 'CB', 'CB', 'RB', 'CM', 'CDM', 'CM', 'LW', 'ST', 'RW'],
  '3-5-2': ['GK', 'CB', 'CB', 'CB', 'LB', 'CM', 'CDM', 'CM', 'RB', 'ST', 'ST'],
  '5-3-2': ['GK', 'LB', 'CB', 'CB', 'CB', 'RB', 'CM', 'CM', 'CDM', 'ST', 'ST'],
  '4-2-3-1': ['GK', 'LB', 'CB', 'CB', 'RB', 'CDM', 'CDM', 'LW', 'CAM', 'RW', 'ST'],
  '3-4-3': ['GK', 'CB', 'CB', 'CB', 'LB', 'CM', 'CM', 'RB', 'LW', 'ST', 'RW'],
};

const stylePresets = <String, (int, int)>{
  'Balanced': (2, 1),
  'Gegenpress': (3, 2),
  'Tiki-Taka': (3, 0),
  'Counter-Attack': (1, 2),
  'Catenaccio': (1, 0),
};

Tactics defaultTactics(int clubId) =>
    Tactics(formation: formations.keys.elementAt(clubId % formations.length));

String lineOf(String pos) => switch (pos) {
      'GK' => 'gk',
      'CB' || 'LB' || 'RB' => 'def',
      'CDM' || 'CM' => 'mid',
      _ => 'att',
    };

double ratingAt(SimPlayer p, String slot) {
  var r = overallOf(slot, p.attrs).toDouble();
  if (!p.positions.contains(slot)) {
    r -= (slot == 'GK' || p.primary == 'GK') ? 45 : 6;
  }
  return r;
}

double effRating(SimPlayer p, String slot) =>
    ratingAt(p, slot) * (0.9 + 0.1 * p.fitness / 100) * (0.98 + 0.04 * p.form / 100);

class Side {
  final int clubId;
  Tactics tactics;
  final List<String> slots;
  final List<SimPlayer> xi;
  final List<SimPlayer> bench;
  int subsUsed = 0;
  Side._(this.clubId, this.tactics, this.slots, this.xi, this.bench);

  factory Side.pick(int clubId, List<SimPlayer> squad, Tactics t) {
    final want = formations[t.formation] ?? formations['4-3-3']!;
    final order = [...want]
      ..sort((a, b) => (a == 'GK' ? 0 : 1).compareTo(b == 'GK' ? 0 : 1));
    final pool = [...squad];
    final slots = <String>[];
    final xi = <SimPlayer>[];
    for (final s in order) {
      if (pool.isEmpty) break;
      pool.sort((a, b) => ratingAt(b, s).compareTo(ratingAt(a, s)));
      slots.add(s);
      xi.add(pool.removeAt(0));
    }
    pool.sort((a, b) => ratingAt(b, b.primary).compareTo(ratingAt(a, a.primary)));
    return Side._(clubId, t, slots, xi, pool.take(7).toList());
  }
}

class Strength {
  final double att, mid, def;
  Strength(this.att, this.mid, this.def);
}

double _avg(List<double> v) => v.isEmpty ? 30 : v.reduce((a, b) => a + b) / v.length;

Strength strengthOf(Side s, {required bool home}) {
  final l = <String, List<double>>{'gk': [], 'def': [], 'mid': [], 'att': []};
  for (var i = 0; i < s.xi.length; i++) {
    l[lineOf(s.slots[i])]!.add(effRating(s.xi[i], s.slots[i]));
  }
  final m = s.tactics.mentality - 2, v = s.tactics.verticality - 1;
  final k = (0.55 + 0.45 * s.xi.length / 11) * (home ? 1.03 : 1.0);
  return Strength(
    _avg(l['att']!) * (1 + 0.035 * m + 0.015 * v) * k,
    _avg(l['mid']!) * (1 - 0.02 * v) * k,
    (_avg(l['def']!) * 0.75 + _avg(l['gk']!) * 0.25) * (1 - 0.035 * m) * k,
  );
}

double tempoOf(Tactics t) => 1 + 0.08 * (t.verticality - 1) + 0.03 * (t.mentality - 2);

class MatchEvent {
  final int minute;
  final String type; // goal, yellow, red, injury, sub
  final int side;
  final int playerId;
  final String name;
  final String? other; // assist, or player replaced
  MatchEvent(this.minute, this.type, this.side, this.playerId, this.name, this.other);
  Map<String, dynamic> toJson() => {
        'm': minute,
        't': type,
        's': side,
        'p': playerId,
        'n': name,
        if (other != null) 'o': other,
      };
}

double _lw(String line, double a, double m, double d) => switch (line) {
      'att' => a,
      'mid' => m,
      'def' => d,
      _ => 0,
    };
double _shotW(SimPlayer p, String slot) {
  final f = (p.attrs['finishing']! + p.attrs['shooting']!) / 100;
  return _lw(lineOf(slot), 4, 1.5, 0.4) * f * f;
}

double _assistW(SimPlayer p, String slot) {
  final f = (p.attrs['passing']! + p.attrs['vision']!) / 100;
  return _lw(lineOf(slot), 3, 3, 1) * f;
}

double _discW(SimPlayer p, String slot) => _lw(lineOf(slot), 1.5, 3, 3);
double _flatW(SimPlayer p, String slot) => 1.0;

class MatchSim {
  final List<Side> sides;
  final Random r;
  int minute = 0;
  final goals = [0, 0];
  final shots = [0, 0];
  final events = <MatchEvent>[];
  final _who = <int, SimPlayer>{};
  final _line = <int, String>{};
  final _g = <int, int>{}, _a = <int, int>{}, _y = <int, int>{};
  final _red = <int>{};
  final _side = <int, int>{};
  double _pos = 0;
  List<Strength>? _st;

  MatchSim(Side home, Side away, this.r) : sides = [home, away] {
    for (var i = 0; i < 2; i++) {
      for (var j = 0; j < sides[i].xi.length; j++) {
        final p = sides[i].xi[j];
        _who[p.id] = p;
        _line[p.id] = lineOf(sides[i].slots[j]);
        _side[p.id] = i;
      }
    }
  }

  bool get finished => minute >= 90;
  Iterable<SimPlayer> get participants => _who.values;
  List<int> get poss {
    final p = (_pos / max(minute, 1) * 100).round().clamp(30, 70).toInt();
    return [p, 100 - p];
  }

  List<Strength> get _s =>
      _st ??= [strengthOf(sides[0], home: true), strengthOf(sides[1], home: false)];
  void invalidate() => _st = null;

  void playTo(int m) {
    while (minute < m && !finished) {
      step();
    }
  }

  void playAll() => playTo(90);

  void step() {
    minute++;
    final s = _s;
    final tempo = (tempoOf(sides[0].tactics) + tempoOf(sides[1].tactics)) / 2;
    _pos += s[0].mid / (s[0].mid + s[1].mid);
    for (var i = 0; i < 2; i++) {
      final o = 1 - i;
      final off = s[i].att * 0.6 + s[i].mid * 0.4;
      final dfn = s[o].def * 0.6 + s[o].mid * 0.4;
      _attack(i, 1.3 * pow(off / dfn, 2.5).toDouble() * tempo);
    }
    for (var i = 0; i < 2; i++) {
      _discipline(i);
    }
  }

  SimPlayer? _pick(int i, double Function(SimPlayer, String) w, {SimPlayer? not}) {
    final s = sides[i];
    final ws = <double>[];
    var tot = 0.0;
    for (var j = 0; j < s.xi.length; j++) {
      final p = s.xi[j];
      final x = (identical(p, not) || s.slots[j] == 'GK') ? 0.0 : w(p, s.slots[j]);
      ws.add(x);
      tot += x;
    }
    if (tot <= 0) return null;
    var t = r.nextDouble() * tot;
    for (var j = 0; j < ws.length; j++) {
      t -= ws[j];
      if (t <= 0) return s.xi[j];
    }
    return s.xi.last;
  }

  void _attack(int i, double xg) {
    if (r.nextDouble() >= xg / 0.11 / 90) return;
    final sh = _pick(i, _shotW);
    if (sh == null) return;
    shots[i]++;
    final conv = 0.11 * (sh.attrs['finishing']! / 75).clamp(0.7, 1.35).toDouble();
    if (r.nextDouble() >= conv) return;
    goals[i]++;
    _g[sh.id] = (_g[sh.id] ?? 0) + 1;
    final ast = _pick(i, _assistW, not: sh);
    String? an;
    if (ast != null && r.nextDouble() < 0.7) {
      an = ast.name;
      _a[ast.id] = (_a[ast.id] ?? 0) + 1;
    }
    events.add(MatchEvent(minute, 'goal', i, sh.id, sh.name, an));
  }

  void _discipline(int i) {
    if (r.nextDouble() < 0.018) {
      final p = _pick(i, _discW);
      if (p != null) {
        _y[p.id] = (_y[p.id] ?? 0) + 1;
        events.add(MatchEvent(minute, 'yellow', i, p.id, p.name, null));
        if (_y[p.id] == 2) _send(i, p);
      }
    }
    if (r.nextDouble() < 0.0004) {
      final p = _pick(i, _discW);
      if (p != null) _send(i, p);
    }
    if (r.nextDouble() < 0.0006) {
      final p = _pick(i, _flatW);
      if (p != null) {
        events.add(MatchEvent(minute, 'injury', i, p.id, p.name, null));
        _remove(i, p, replace: true);
      }
    }
  }

  void _send(int i, SimPlayer p) {
    _red.add(p.id);
    events.add(MatchEvent(minute, 'red', i, p.id, p.name, null));
    _remove(i, p);
  }

  void _remove(int i, SimPlayer p, {bool replace = false}) {
    final s = sides[i];
    final j = s.xi.indexOf(p);
    if (j < 0) return;
    final slot = s.slots[j];
    if (replace && s.subsUsed < 5 && s.bench.isNotEmpty) {
      s.bench.sort((a, b) => ratingAt(b, slot).compareTo(ratingAt(a, slot)));
      _bring(i, j, s.bench.removeAt(0), p.name);
    } else {
      s.xi.removeAt(j);
      s.slots.removeAt(j);
    }
    invalidate();
  }

  void _bring(int i, int j, SimPlayer n, String outName, {bool free = false}) {
    final s = sides[i];
    final out = s.xi[j];
    s.xi[j] = n;
    if (free) {
      _who.remove(out.id);
      _line.remove(out.id);
      _side.remove(out.id);
      s.bench.add(out);
    } else {
      s.subsUsed++;
    }
    _who[n.id] = n;
    _line[n.id] = lineOf(s.slots[j]);
    _side[n.id] = i;
    if (!free) events.add(MatchEvent(minute, 'sub', i, n.id, n.name, outName));
  }

  bool substitute(int i, int outId, int inId) {
    final s = sides[i];
    final free = minute == 0;
    if (!free && s.subsUsed >= 5) return false;
    final j = s.xi.indexWhere((p) => p.id == outId);
    final k = s.bench.indexWhere((p) => p.id == inId);
    if (j < 0 || k < 0) return false;
    final out = s.xi[j];
    _bring(i, j, s.bench.removeAt(k), out.name, free: free);
    invalidate();
    return true;
  }

  void setFormation(int i, String f) {
    final s = sides[i];
    final want = formations[f];
    if (want == null || f == s.tactics.formation) return;
    final order = [...want]
      ..sort((a, b) => (a == 'GK' ? 0 : 1).compareTo(b == 'GK' ? 0 : 1));
    final pool = [...s.xi];
    final slots = <String>[];
    final xi = <SimPlayer>[];
    for (final sl in order) {
      if (pool.isEmpty) break;
      pool.sort((a, b) => ratingAt(b, sl).compareTo(ratingAt(a, sl)));
      slots.add(sl);
      xi.add(pool.removeAt(0));
    }
    s.xi
      ..clear()
      ..addAll(xi);
    s.slots
      ..clear()
      ..addAll(slots);
    s.tactics.formation = f;
    for (var j = 0; j < xi.length; j++) {
      _line[xi[j].id] = lineOf(slots[j]);
    }
    invalidate();
  }

  void setStyle(int i, {int? mentality, int? verticality}) {
    if (mentality != null) sides[i].tactics.mentality = mentality;
    if (verticality != null) sides[i].tactics.verticality = verticality;
    invalidate();
  }

  Map<int, double> ratings() {
    final out = <int, double>{};
    for (final id in _who.keys) {
      final i = _side[id]!;
      final gf = goals[i], ga = goals[1 - i];
      final ln = _line[id] ?? 'mid';
      var x = 6.5 +
          (r.nextDouble() - 0.5) * 0.8 +
          (_g[id] ?? 0) * 1.0 +
          (_a[id] ?? 0) * 0.6 -
          (_y[id] ?? 0) * 0.2 -
          (_red.contains(id) ? 1.5 : 0);
      x += gf > ga ? 0.4 : (gf < ga ? -0.3 : 0);
      if (ga == 0 && (ln == 'def' || ln == 'gk')) x += 0.5;
      out[id] = (x.clamp(6.0, 9.5) * 10).round() / 10;
    }
    return out;
  }

  Map<String, dynamic> toJson(Map<int, double> rt) => {
        'events': [for (final e in events) e.toJson()],
        'shots': shots,
        'poss': poss,
        'ratings': {for (final e in rt.entries) '${e.key}': e.value},
      };
}
