import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'career.dart';
import 'competitions.dart';
import 'database.dart';

const maxFacility = 5;
const _sponsors = [
  'Nordlicht Energy', 'Aurelia Bank', 'Vantage Telecom', 'Solis Airlines',
  'Kestrel Motors', 'Meridian Foods', 'Corvo Insurance', 'Helix Sports',
];

int upgradeCost(int level, int strength) =>
    (3000000 * pow(2.2, level - 1) * (0.25 + 0.75 * strength / 100) / 10000).round() * 10000;

class FacilityData {
  final Club club;
  final League league;
  final CareerSave save;
  FacilityData(this.club, this.league, this.save);
}

Future<FacilityData> loadFacilities(AppDatabase db) async {
  final save = await loadCareer(db);
  final club = await (db.select(db.clubs)..where((t) => t.id.equals(save.clubId!))).getSingle();
  final lg = await (db.select(db.leagues)..where((t) => t.id.equals(club.leagueId))).getSingle();
  return FacilityData(club, lg, save);
}

/// Returns an error message, or null on success.
Future<String?> upgradeFacility(AppDatabase db, {required bool stadium}) =>
    db.transaction(() async {
      final d = await loadFacilities(db);
      final lvl = stadium ? d.club.stadiumLevel : d.club.trainingLevel;
      if (lvl >= maxFacility) return 'Already at maximum level';
      final cost = upgradeCost(lvl, d.league.strength);
      if (d.club.budget < cost) return 'Not enough budget';
      final season = await (db.select(db.seasons)..where((t) => t.id.equals(d.save.seasonId))).getSingle();
      await (db.update(db.clubs)..where((t) => t.id.equals(d.club.id))).write(ClubsCompanion(
          budget: Value(d.club.budget - cost),
          stadiumLevel: stadium ? Value(lvl + 1) : const Value.absent(),
          trainingLevel: stadium ? const Value.absent() : Value(lvl + 1)));
      await db.into(db.financeEntries).insert(FinanceEntriesCompanion.insert(
          seasonId: season.id,
          clubId: d.club.id,
          day: season.currentDay,
          kind: 'facilities',
          amount: -cost,
          note: Value('${stadium ? 'Stadium' : 'Training ground'} upgraded to level ${lvl + 1}')));
      return null;
    });

Future<(int, int)> leaguePosition(AppDatabase db, int sid, int clubId) async {
  final clubs = {for (final c in await db.select(db.clubs).get()) c.id: c};
  final me = clubs[clubId]!;
  final lg = await (db.select(db.leagues)..where((t) => t.id.equals(me.leagueId))).getSingle();
  final ids = [for (final c in clubs.values) if (c.leagueId == me.leagueId) c.id];
  final sorted = sortRows((await standingsOf(db, sid, lg.name, clubs, ids)).values);
  return (sorted.indexWhere((r) => r.club.id == clubId) + 1, sorted.length);
}

/// Sponsor signed at season start; value depends on last season's finish.
Future<void> signSponsor(AppDatabase db, int sid, int clubId, int? prev) async {
  var pct = 100;
  if (prev != null) {
    final (p, n) = await leaguePosition(db, prev, clubId);
    if (n > 1) pct = (80 + 50 * (n - p) / (n - 1)).round();
  }
  final save = await loadCareer(db);
  await (db.update(db.careerSaves)..where((t) => t.id.equals(save.id))).write(
      CareerSavesCompanion(
          sponsorName: Value(_sponsors[Random(sid * 31 + clubId).nextInt(_sponsors.length)]),
          sponsorPct: Value(pct)));
}

Future<void> payPrizes(AppDatabase db, int newSid, int prev, int clubId) async {
  final club = await (db.select(db.clubs)..where((t) => t.id.equals(clubId))).getSingle();
  final lg = await (db.select(db.leagues)..where((t) => t.id.equals(club.leagueId))).getSingle();
  final lf = 0.25 + 0.75 * lg.strength / 100;
  final items = <(String, int)>[];
  final (p, n) = await leaguePosition(db, prev, clubId);
  if (n > 1) {
    items.add(('League prize money (finished $p of $n)',
        (60e6 * lf * (0.25 + 0.75 * (n - p) / (n - 1))).round()));
  }
  final es = await (db.select(db.compEntries)
        ..where((t) => t.seasonId.equals(prev) & t.clubId.equals(clubId)))
      .get();
  for (final comp in {for (final e in es) e.competition}) {
    final i = euroComps.indexOf(comp);
    final won = await winnerOf(db, prev, comp) == clubId;
    if (i >= 0) {
      items.add(('$comp participation', (const [15e6, 6e6, 3e6][i] * lf).round()));
      if (won) items.add(('$comp winners', (const [25e6, 10e6, 5e6][i] * lf).round()));
    } else if (won && comp != superCup) {
      items.add(('$comp winners', (8e6 * lf).round()));
    }
  }
  if (items.isEmpty) return;
  await db.batch((b) => b.insertAll(db.financeEntries, [
        for (final it in items)
          FinanceEntriesCompanion.insert(
              seasonId: newSid,
              clubId: clubId,
              day: 0,
              kind: 'prize',
              amount: it.$2,
              note: Value(it.$1))
      ]));
  final total = items.fold<int>(0, (a, b) => a + b.$2);
  await (db.update(db.clubs)..where((t) => t.id.equals(clubId)))
      .write(ClubsCompanion(budget: Value(club.budget + total)));
}

/// Season awards: champions, cup winners, golden boot, assists, player of the season.
Future<void> computeAwards(AppDatabase db, int sid) async {
  final leagues = await db.select(db.leagues).get();
  final clubs = {for (final c in await db.select(db.clubs).get()) c.id: c};
  final pl = {for (final p in await db.select(db.players).get()) p.id: p};
  final out = <AwardsCompanion>[];
  void add(String cat, String who, {String detail = '', int? club, bool team = false}) =>
      out.add(AwardsCompanion.insert(
          seasonId: sid,
          category: cat,
          winner: who,
          detail: Value(detail),
          clubId: Value(club),
          team: Value(team)));
  String cn(int? id) => id == null ? '' : clubs[id]?.name ?? '';

  final top = leagues.where((l) => l.tier == 1).toList()
    ..sort((a, b) => b.strength.compareTo(a.strength));
  for (final l in top) {
    final ids = [for (final c in clubs.values) if (c.leagueId == l.id) c.id];
    if (ids.length < 2) continue;
    final rows = sortRows((await standingsOf(db, sid, l.name, clubs, ids)).values);
    add('${l.name} Champion', rows.first.club.name, club: rows.first.club.id, team: true);
    final res = await (db.select(db.fixtures).join([
      innerJoin(db.matchResults, db.matchResults.fixtureId.equalsExp(db.fixtures.id))
    ])
          ..where(db.fixtures.competition.equals(l.name) & db.fixtures.seasonId.equals(sid)))
        .get();
    final goals = <int, int>{};
    final assists = <String, int>{};
    final rsum = <int, double>{}, rcnt = <int, int>{};
    for (final x in res) {
      final f = x.readTable(db.fixtures);
      final m = jsonDecode(x.readTable(db.matchResults).eventsJson) as Map<String, dynamic>;
      for (final e in (m['events'] as List? ?? [])) {
        if (e['t'] != 'goal') continue;
        goals[e['p'] as int] = (goals[e['p'] as int] ?? 0) + 1;
        if (e['o'] != null) {
          final k = '${e['o']}|${e['s'] == 0 ? f.homeClubId : f.awayClubId}';
          assists[k] = (assists[k] ?? 0) + 1;
        }
      }
      ((m['ratings'] as Map?) ?? {}).forEach((k, v) {
        final id = int.parse(k as String);
        rsum[id] = (rsum[id] ?? 0) + (v as num).toDouble();
        rcnt[id] = (rcnt[id] ?? 0) + 1;
      });
    }
    if (goals.isNotEmpty) {
      final b = goals.entries.reduce((a, c) => c.value > a.value ? c : a);
      final p = pl[b.key];
      if (p != null) {
        add('${l.name} Golden Boot', p.fullName,
            detail: '${b.value} goals · ${cn(p.clubId)}', club: p.clubId);
      }
    }
    if (assists.isNotEmpty) {
      final b = assists.entries.reduce((a, c) => c.value > a.value ? c : a);
      final parts = b.key.split('|');
      add('${l.name} Top Assists', parts[0],
          detail: '${b.value} assists · ${cn(int.tryParse(parts[1]))}',
          club: int.tryParse(parts[1]));
    }
    int? best;
    var bestAvg = 0.0;
    for (final id in rsum.keys) {
      if (rcnt[id]! < 15) continue;
      final a = rsum[id]! / rcnt[id]!;
      if (a > bestAvg) {
        bestAvg = a;
        best = id;
      }
    }
    final bp = best == null ? null : pl[best];
    if (bp != null) {
      add('${l.name} Player of the Season', bp.fullName,
          detail: 'avg ${bestAvg.toStringAsFixed(2)} · ${cn(bp.clubId)}', club: bp.clubId);
    }
  }
  final es = await (db.select(db.compEntries)..where((t) => t.seasonId.equals(sid))).get();
  for (final comp in {for (final e in es) e.competition}) {
    final w = await winnerOf(db, sid, comp);
    if (w != null) add(comp, cn(w), club: w, team: true);
  }
  await db.batch((b) => b.insertAll(db.awards, out));
}

class HonoursData {
  final Map<int, List<Award>> bySeason;
  final int trophies;
  final int myClub;
  HonoursData(this.bySeason, this.trophies, this.myClub);
}

Future<HonoursData> loadHonours(AppDatabase db) async {
  final save = await loadCareer(db);
  final rows = await (db.select(db.awards).join([
    innerJoin(db.seasons, db.seasons.id.equalsExp(db.awards.seasonId))
  ])
        ..orderBy([OrderingTerm.desc(db.seasons.year), OrderingTerm.asc(db.awards.id)]))
      .get();
  final m = <int, List<Award>>{};
  var t = 0;
  for (final r in rows) {
    final a = r.readTable(db.awards);
    (m[r.readTable(db.seasons).year] ??= []).add(a);
    if (a.team && a.clubId == save.clubId) t++;
  }
  return HonoursData(m, t, save.clubId ?? -1);
}
