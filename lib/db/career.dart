import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import '../engine/fixtures.dart';
import '../engine/match.dart';
import 'database.dart';

class StandingRow {
  final Club club;
  int p = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0;
  StandingRow(this.club);
  int get pts => w * 3 + d;
  int get gd => gf - ga;
}

class HubData {
  final Club me;
  final Season season;
  final Map<int, Club> clubs;
  final List<Fixture> next;
  final League league;
  final List<StandingRow> table;
  HubData(this.me, this.season, this.clubs, this.next, this.league, this.table);
}

class MatchReport {
  final String home, away;
  final int hg, ag;
  final List<MatchEvent> events;
  final List<int> shots, poss;
  MatchReport(this.home, this.away, this.hg, this.ag, this.events, this.shots, this.poss);
}

Future<CareerSave> loadCareer(AppDatabase db) =>
    db.select(db.careerSaves).getSingle();

Future<void> startCareer(AppDatabase db, int clubId) => db.transaction(() async {
      final save = await loadCareer(db);
      await (db.update(db.careerSaves)..where((t) => t.id.equals(save.id)))
          .write(CareerSavesCompanion(clubId: Value(clubId)));
      final has = await (db.select(db.fixtures)
            ..where((t) => t.seasonId.equals(save.seasonId))
            ..limit(1))
          .get();
      if (has.isEmpty) await generateFixtures(db, save.seasonId);
    });

Future<void> generateFixtures(AppDatabase db, int seasonId) async {
  final leagues = await db.select(db.leagues).get();
  final clubs = await db.select(db.clubs).get();
  final r = Random(seasonId);
  final rows = <FixturesCompanion>[];
  for (final l in leagues) {
    final ids = [for (final c in clubs) if (c.leagueId == l.id) c.id];
    if (ids.length < 2) continue;
    final rounds = doubleRoundRobin(ids, r);
    for (var i = 0; i < rounds.length; i++) {
      for (final (h, a) in rounds[i]) {
        rows.add(FixturesCompanion.insert(
          seasonId: seasonId,
          competition: l.name,
          round: i + 1,
          day: 14 + i * 7,
          homeClubId: h,
          awayClubId: a,
        ));
      }
    }
  }
  await db.batch((b) => b.insertAll(db.fixtures, rows));
}

Future<HubData> loadHub(AppDatabase db) async {
  final save = await loadCareer(db);
  final season = await (db.select(db.seasons)
        ..where((t) => t.id.equals(save.seasonId)))
      .getSingle();
  final clubs = {for (final c in await db.select(db.clubs).get()) c.id: c};
  final me = save.clubId!;
  final fx = await (db.select(db.fixtures)
        ..where((t) =>
            (t.homeClubId.equals(me) | t.awayClubId.equals(me)) &
            t.played.equals(false) &
            t.day.isBiggerOrEqualValue(season.currentDay))
        ..orderBy([(t) => OrderingTerm.asc(t.day)])
        ..limit(8))
      .get();
  final lg = await (db.select(db.leagues)
        ..where((t) => t.id.equals(clubs[me]!.leagueId)))
      .getSingle();
  final rows = <int, StandingRow>{
    for (final c in clubs.values)
      if (c.leagueId == lg.id) c.id: StandingRow(c)
  };
  final res = await (db.select(db.fixtures).join([
    innerJoin(db.matchResults, db.matchResults.fixtureId.equalsExp(db.fixtures.id))
  ])
        ..where(db.fixtures.competition.equals(lg.name) &
            db.fixtures.seasonId.equals(season.id)))
      .get();
  for (final x in res) {
    final f = x.readTable(db.fixtures);
    final m = x.readTable(db.matchResults);
    final h = rows[f.homeClubId]!, a = rows[f.awayClubId]!;
    h.p++;
    a.p++;
    h.gf += m.homeGoals;
    h.ga += m.awayGoals;
    a.gf += m.awayGoals;
    a.ga += m.homeGoals;
    if (m.homeGoals > m.awayGoals) {
      h.w++;
      a.l++;
    } else if (m.homeGoals < m.awayGoals) {
      a.w++;
      h.l++;
    } else {
      h.d++;
      a.d++;
    }
  }
  final table = rows.values.toList()
    ..sort((a, b) => b.pts != a.pts
        ? b.pts.compareTo(a.pts)
        : b.gd != a.gd
            ? b.gd.compareTo(a.gd)
            : b.gf != a.gf
                ? b.gf.compareTo(a.gf)
                : a.club.name.compareTo(b.club.name));
  return HubData(clubs[me]!, season, clubs, fx, lg, table);
}

SimPlayer toSim(Player p) => SimPlayer(
      p.id,
      p.fullName,
      p.positions.split(','),
      {
        'pace': p.pace,
        'acceleration': p.acceleration,
        'shooting': p.shooting,
        'finishing': p.finishing,
        'passing': p.passing,
        'crossing': p.crossing,
        'dribbling': p.dribbling,
        'technique': p.technique,
        'defending': p.defending,
        'tackling': p.tackling,
        'physical': p.physical,
        'strength': p.strength,
        'stamina': p.stamina,
        'jumping': p.jumping,
        'decisionMaking': p.decisionMaking,
        'workRate': p.workRate,
        'vision': p.vision,
        'composure': p.composure,
        'handling': p.handling,
        'reflexes': p.reflexes,
        'positioning': p.positioning,
        'kicking': p.kicking,
        'command': p.command,
      },
      p.fitness,
      p.form,
    );

/// Simulates every unplayed fixture on the next matchday day. Returns the user's match report.
Future<MatchReport?> playNextMatchday(AppDatabase db) => db.transaction(() async {
      final save = await loadCareer(db);
      final season = await (db.select(db.seasons)
            ..where((t) => t.id.equals(save.seasonId)))
          .getSingle();
      final next = await (db.select(db.fixtures)
            ..where((t) =>
                t.seasonId.equals(season.id) &
                t.played.equals(false) &
                t.day.isBiggerOrEqualValue(season.currentDay))
            ..orderBy([(t) => OrderingTerm.asc(t.day)])
            ..limit(1))
          .getSingleOrNull();
      if (next == null) return null;
      final todays = await (db.select(db.fixtures)
            ..where((t) =>
                t.seasonId.equals(season.id) &
                t.played.equals(false) &
                t.day.equals(next.day)))
          .get();
      final ids = <int>{
        for (final f in todays) ...[f.homeClubId, f.awayClubId]
      };
      final players =
          await (db.select(db.players)..where((t) => t.clubId.isIn(ids))).get();
      final squads = <int, List<SimPlayer>>{};
      for (final p in players) {
        (squads[p.clubId!] ??= []).add(toSim(p));
      }
      final names = {for (final c in await db.select(db.clubs).get()) c.id: c.name};

      MatchReport? report;
      final results = <MatchResultsCompanion>[];
      final upd = <int, (int, int)>{};
      for (final f in todays) {
        final sim = MatchSim(
          Side.pick(f.homeClubId, squads[f.homeClubId] ?? [], defaultTactics(f.homeClubId)),
          Side.pick(f.awayClubId, squads[f.awayClubId] ?? [], defaultTactics(f.awayClubId)),
          Random(f.id * 31 + 17),
        )..playAll();
        final rt = sim.ratings();
        results.add(MatchResultsCompanion.insert(
          fixtureId: f.id,
          homeGoals: sim.goals[0],
          awayGoals: sim.goals[1],
          eventsJson: Value(jsonEncode(sim.toJson(rt))),
        ));
        for (final p in sim.participants) {
          final target = (60 + (rt[p.id]! - 6.8) * 30).clamp(0, 100);
          upd[p.id] = (
            max(40, min(100, p.fitness + 10) - 25),
            (p.form * 0.7 + target * 0.3).round(),
          );
        }
        if (f.homeClubId == save.clubId || f.awayClubId == save.clubId) {
          report = MatchReport(names[f.homeClubId]!, names[f.awayClubId]!,
              sim.goals[0], sim.goals[1], sim.events, sim.shots, sim.poss);
        }
      }

      await db.customStatement('UPDATE players SET fitness = MIN(100, fitness + 10)');
      await db.batch((b) {
        b.insertAll(db.matchResults, results);
        for (final f in todays) {
          b.update(db.fixtures, FixturesCompanion(played: const Value(true)),
              where: (t) => t.id.equals(f.id));
        }
        for (final e in upd.entries) {
          b.update(
              db.players,
              PlayersCompanion(fitness: Value(e.value.$1), form: Value(e.value.$2)),
              where: (t) => t.id.equals(e.key));
        }
      });
      await (db.update(db.seasons)..where((t) => t.id.equals(season.id)))
          .write(SeasonsCompanion(currentDay: Value(next.day + 1)));
      return report;
    });
