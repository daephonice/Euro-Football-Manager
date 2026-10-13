import 'dart:math';
import 'package:drift/drift.dart';
import '../engine/fixtures.dart';
import 'database.dart';

class HubData {
  final Club me;
  final Season season;
  final Map<int, Club> clubs;
  final List<Fixture> next;
  HubData(this.me, this.season, this.clubs, this.next);
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
  return HubData(clubs[me]!, season, clubs, fx);
}
