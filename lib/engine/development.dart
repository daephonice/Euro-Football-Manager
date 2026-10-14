import 'dart:math';
import 'rating.dart';

const _fast = ['pace', 'acceleration', 'stamina', 'reflexes'];
const _mid = ['physical', 'strength', 'jumping', 'dribbling', 'workRate'];
const _matchGain = ['decisionMaking', 'composure', 'workRate'];

int trainingLevelFor(int rep) =>
    rep >= 85 ? 5 : rep >= 70 ? 4 : rep >= 55 ? 3 : rep >= 40 ? 2 : 1;

double trainingMult(int level) => 0.7 + 0.15 * level;

List<String> devAttrs(String pos) =>
    pos == 'GK' ? [...gkAttrs, 'composure'] : outfieldAttrs;

int _cap(int pot) => min(99, pot + 6);

/// Weekly focus training (user's club). Spec gain 0.2-1.5/wk, scaled x0.12
/// so a season is roughly +1..+7 on a focused attribute. Returns changed attrs.
Map<String, int> weeklyTrain(Map<String, int> a, String pos, int age, int ovr,
    int pot, int level, List<String> focus, Random r) {
  if (focus.isEmpty || ovr >= pot) return {};
  final ageF = age <= 22 ? 1.0 : age <= 28 ? 0.6 : age <= 31 ? 0.3 : 0.1;
  final head = ((pot - ovr) / 10).clamp(0.0, 1.0);
  final spec = ((0.2 + 1.3 * ageF * head) * trainingMult(level)).clamp(0.2, 1.5);
  final p = spec * 0.12 * (focus.length > 1 ? 0.6 : 1.0);
  final ok = devAttrs(pos);
  final out = <String, int>{};
  for (final k in focus) {
    if (!ok.contains(k) || a[k]! >= _cap(pot)) continue;
    if (r.nextDouble() < p) out[k] = a[k]! + 1;
  }
  return out;
}

/// Small gain for players who featured in a match.
Map<String, int> matchExperience(
    Map<String, int> a, String pos, int age, int ovr, int pot, Random r) {
  if (age > 30 || ovr >= pot || r.nextDouble() >= 0.04) return {};
  final ks = pos == 'GK' ? const ['composure'] : _matchGain;
  final k = ks[r.nextInt(ks.length)];
  return a[k]! >= _cap(pot) ? {} : {k: a[k]! + 1};
}

/// Season-end growth/decline for one player (age = age before the birthday).
Map<String, int> seasonDevelop(
    Map<String, int> a, String pos, int age, int ovr, int pot, Random r) {
  final eff = pos == 'GK' ? age - 3 : age;
  final head = pot - ovr;
  final out = <String, int>{};
  for (final k in devAttrs(pos)) {
    var d = 0;
    if (eff <= 22) {
      final base = head <= 0 ? 0.3 : (head * 0.3).clamp(1.0, 4.0);
      d = (base + r.nextDouble() * 1.6 - 0.8).round().clamp(0, 5);
    } else if (eff <= 28) {
      d = head > 0 && r.nextDouble() < 0.45 ? 1 : 0;
    } else {
      final y = eff - 28;
      final e = _fast.contains(k)
          ? 0.5 + 0.35 * y
          : _mid.contains(k)
              ? 0.2 + 0.18 * y
              : (y >= 3 ? 0.1 * (y - 2) : 0.0);
      d = -(e + r.nextDouble() - 0.5).round().clamp(0, 6);
    }
    if (d > 0 && a[k]! >= _cap(pot)) d = 0;
    final v = (a[k]! + d).clamp(1, 99);
    if (v != a[k]) out[k] = v;
  }
  return out;
}

int nextPotential(int pot, int ovr, int newAge, Random r) {
  var p = pot;
  if (newAge <= 21) p += r.nextInt(5) - 2;
  if (newAge >= 27) p = min(p, ovr);
  return p.clamp(ovr, 99);
}
