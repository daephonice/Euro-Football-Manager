import 'dart:math';

const outfieldAttrs = [
  'pace', 'acceleration', 'shooting', 'finishing', 'passing', 'crossing',
  'dribbling', 'technique', 'defending', 'tackling', 'physical', 'strength',
  'stamina', 'jumping', 'decisionMaking', 'workRate', 'vision', 'composure',
];
const gkAttrs = ['handling', 'reflexes', 'positioning', 'kicking', 'command'];

const Map<String, double> _fullback = {
  'defending': 2, 'tackling': 2, 'pace': 2, 'stamina': 2, 'crossing': 1.5,
  'workRate': 1.5, 'acceleration': 1, 'passing': 1,
};
const Map<String, double> _winger = {
  'pace': 2.5, 'acceleration': 2, 'dribbling': 2.5, 'crossing': 1.5,
  'technique': 1.5, 'finishing': 1, 'shooting': 1,
};

const Map<String, Map<String, double>> posWeights = {
  'GK': {'handling': 3, 'reflexes': 3, 'positioning': 3, 'kicking': 1, 'command': 2, 'composure': 1},
  'CB': {'defending': 3, 'tackling': 2.5, 'physical': 1.5, 'strength': 2, 'jumping': 1.5, 'decisionMaking': 2, 'composure': 1, 'pace': 0.5},
  'LB': _fullback,
  'RB': _fullback,
  'CDM': {'defending': 2, 'tackling': 2.5, 'passing': 2, 'decisionMaking': 2, 'stamina': 1.5, 'strength': 1.5, 'workRate': 1.5, 'vision': 1},
  'CM': {'passing': 2.5, 'vision': 2, 'technique': 1.5, 'decisionMaking': 2, 'stamina': 1.5, 'workRate': 1.5, 'dribbling': 1, 'tackling': 1},
  'CAM': {'passing': 2.5, 'vision': 2.5, 'technique': 2.5, 'dribbling': 2, 'shooting': 1.5, 'decisionMaking': 1.5, 'composure': 1},
  'LW': _winger,
  'RW': _winger,
  'ST': {'finishing': 3.5, 'shooting': 2, 'pace': 2, 'composure': 2, 'acceleration': 1, 'strength': 1, 'dribbling': 1, 'jumping': 0.5},
};

Map<String, double> _w(String pos) => posWeights[pos] ?? posWeights['CM']!;

int _c(num v, [int lo = 1, int hi = 99]) => v.clamp(lo, hi).toInt();

int overallOf(String pos, Map<String, int> a) {
  var s = 0.0, t = 0.0;
  _w(pos).forEach((k, v) {
    s += (a[k] ?? 50) * v;
    t += v;
  });
  return _c((s / t).round());
}

Map<String, int> genAttrs(String pos, int target, Random r) {
  final w = _w(pos);
  final isGk = pos == 'GK';
  final a = <String, int>{};
  for (final n in outfieldAttrs) {
    a[n] = w.containsKey(n)
        ? _c(target + r.nextInt(9) - 4)
        : isGk
            ? 10 + r.nextInt(16)
            : _c(target - 10 + r.nextInt(13) - 6);
  }
  for (final n in gkAttrs) {
    a[n] = w.containsKey(n) ? _c(target + r.nextInt(9) - 4) : 5 + r.nextInt(11);
  }
  final d = target - overallOf(pos, a);
  for (final n in w.keys) {
    a[n] = _c(a[n]! + d);
  }
  return a;
}

int valueOf(int ovr, int pot, int age, int leagueStrength) {
  final lf = 0.25 + 0.75 * leagueStrength / 100;
  final af = age <= 21
      ? 1 + (pot - ovr) / 30
      : age <= 28
          ? 1.0
          : max(0.1, 1 - (age - 28) * 0.14);
  final v = 400000 * pow(1.15, ovr - 50) * af * lf;
  return _c((v / 10000).round() * 10000, 10000, 300000000);
}

int wageOf(int value) => max(500, (value / 330 / 100).round() * 100);
