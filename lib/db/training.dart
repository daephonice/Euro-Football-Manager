import 'dart:math';
import 'package:drift/drift.dart';
import '../engine/development.dart';
import '../engine/rating.dart';
import 'career.dart';
import 'facilities.dart';
import 'database.dart';

const maxFocus = 2;

List<String> parseFocus(String s) =>
    s.isEmpty || s == 'fitness' ? [] : s.split(',');

class TrainingData {
  final Club club;
  final List<String> focus;
  final List<Player> squad;
  final int weeks;
  TrainingData(this.club, this.focus, this.squad, this.weeks);
}

Future<TrainingData> loadTraining(AppDatabase db) async {
  final save = await loadCareer(db);
  final club = await (db.select(db.clubs)..where((t) => t.id.equals(save.clubId!))).getSingle();
  final n = db.trainingSessions.id.count();
  final w = await (db.selectOnly(db.trainingSessions)
        ..addColumns([n])
        ..where(db.trainingSessions.clubId.equals(club.id) &
            db.trainingSessions.seasonId.equals(save.seasonId)))
      .getSingle();
  return TrainingData(club, parseFocus(save.trainingFocus), await loadSquad(db), w.read(n) ?? 0);
}

Future<void> saveFocus(AppDatabase db, List<String> f) async {
  final s = await loadCareer(db);
  await (db.update(db.careerSaves)..where((x) => x.id.equals(s.id))).write(
      CareerSavesCompanion(trainingFocus: Value(f.isEmpty ? 'fitness' : f.join(','))));
}

PlayersCompanion devCompanion(Map<String, int> a,
        {int? ovr, int? pot, int? age, int? value, int? fitness}) =>
    PlayersCompanion(
      pace: Value(a['pace']!),
      acceleration: Value(a['acceleration']!),
      shooting: Value(a['shooting']!),
      finishing: Value(a['finishing']!),
      passing: Value(a['passing']!),
      crossing: Value(a['crossing']!),
      dribbling: Value(a['dribbling']!),
      technique: Value(a['technique']!),
      defending: Value(a['defending']!),
      tackling: Value(a['tackling']!),
      physical: Value(a['physical']!),
      strength: Value(a['strength']!),
      stamina: Value(a['stamina']!),
      jumping: Value(a['jumping']!),
      decisionMaking: Value(a['decisionMaking']!),
      workRate: Value(a['workRate']!),
      vision: Value(a['vision']!),
      composure: Value(a['composure']!),
      handling: Value(a['handling']!),
      reflexes: Value(a['reflexes']!),
      positioning: Value(a['positioning']!),
      kicking: Value(a['kicking']!),
      command: Value(a['command']!),
      overall: ovr == null ? const Value.absent() : Value(ovr),
      potential: pot == null ? const Value.absent() : Value(pot),
      age: age == null ? const Value.absent() : Value(age),
      value: value == null ? const Value.absent() : Value(value),
      fitness: fitness == null ? const Value.absent() : Value(fitness),
    );

Future<Map<int, int>> _strengthByClub(AppDatabase db) async {
  final ls = {for (final l in await db.select(db.leagues).get()) l.id: l.strength};
  return {for (final c in await db.select(db.clubs).get()) c.id: ls[c.leagueId] ?? 50};
}

/// Called inside finishMatchday's transaction, after results are saved.
Future<void> applyTraining(AppDatabase db, LiveMatchday lm, Set<int> played) async {
  final save = await loadCareer(db);
  final focus = parseFocus(save.trainingFocus);
  final me = lm.myClubId;
  final club = await (db.select(db.clubs)..where((t) => t.id.equals(me))).getSingle();
  final clubIds = <int>{
    for (final f in lm.fixtures) ...[f.homeClubId, f.awayClubId],
    me,
  };
  final ps = await (db.select(db.players)..where((t) => t.clubId.isIn(clubIds))).get();
  final str = await _strengthByClub(db);
  final rows = <int, PlayersCompanion>{};
  for (final p in ps) {
    final mine = p.clubId == me;
    final inMatch = played.contains(p.id);
    if (!mine && !inMatch) continue;
    final r = Random(lm.day * 100003 + p.id);
    final pos = p.positions.split(',').first;
    final a = {...toSim(p).attrs};
    if (inMatch) a.addAll(matchExperience(a, pos, p.age, p.overall, p.potential, r));
    if (mine) {
      a.addAll(weeklyTrain(a, pos, p.age, p.overall, p.potential, club.trainingLevel, focus, r));
    }
    final base = toSim(p).attrs;
    final changed = a.keys.any((k) => a[k] != base[k]);
    final fit = mine && focus.isEmpty ? min(100, p.fitness + 8) : null;
    if (!changed && fit == null) continue;
    final ovr = changed ? overallOf(pos, a) : p.overall;
    rows[p.id] = devCompanion(a,
        ovr: ovr,
        fitness: fit,
        value: ovr != p.overall
            ? valueOf(ovr, p.potential, p.age, str[p.clubId] ?? 50)
            : null);
  }
  await db.batch((b) {
    for (final e in rows.entries) {
      b.update(db.players, e.value, where: (t) => t.id.equals(e.key));
    }
  });
  await db.into(db.trainingSessions).insert(TrainingSessionsCompanion.insert(
      clubId: me,
      seasonId: lm.season.id,
      week: lm.day ~/ 7,
      focus: save.trainingFocus));
}

/// Ages everyone, applies growth/decline, then opens the next season.
Future<void> startNextSeason(AppDatabase db) => db.transaction(() async {
      final save = await loadCareer(db);
      final season = await (db.select(db.seasons)..where((t) => t.id.equals(save.seasonId))).getSingle();
      final left = await (db.select(db.fixtures)
            ..where((t) => t.seasonId.equals(season.id) & t.played.equals(false))
            ..limit(1))
          .get();
      if (left.isNotEmpty) throw StateError('Season not finished');
      await computeAwards(db, season.id);
      final str = await _strengthByClub(db);
      final r = Random(season.year * 7919);
      final ps = await db.select(db.players).get();
      await db.batch((b) {
        for (final p in ps) {
          final pos = p.positions.split(',').first;
          final base = toSim(p).attrs;
          final a = {...base, ...seasonDevelop(base, pos, p.age, p.overall, p.potential, r)};
          final age = p.age + 1;
          final ovr = overallOf(pos, a);
          final pot = nextPotential(p.potential, ovr, age, r);
          b.update(
              db.players,
              devCompanion(a,
                  ovr: ovr,
                  pot: pot,
                  age: age,
                  fitness: 100,
                  value: valueOf(ovr, pot, age, str[p.clubId] ?? 50)),
              where: (t) => t.id.equals(p.id));
        }
      });
      final sid = await db.into(db.seasons).insert(SeasonsCompanion.insert(year: season.year + 1));
      await (db.update(db.careerSaves)..where((t) => t.id.equals(save.id)))
          .write(CareerSavesCompanion(seasonId: Value(sid)));
      await generateFixtures(db, sid, prev: season.id);
      await signSponsor(db, sid, save.clubId!, season.id);
      await payPrizes(db, sid, season.id, save.clubId!);
    });
