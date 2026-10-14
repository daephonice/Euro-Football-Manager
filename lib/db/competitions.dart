import 'dart:math';
import 'package:drift/drift.dart';
import '../engine/fixtures.dart';
import 'career.dart';
import 'database.dart';

const cupsByCountry = <String, List<String>>{
  'England': ['FA Cup', 'EFL Cup'],
  'Spain': ['Copa del Rey'],
  'Germany': ['DFB-Pokal'],
  'Italy': ['Coppa Italia'],
  'France': ['Coupe de France'],
  'Portugal': ['Taça de Portugal'],
  'Netherlands': ['KNVB Cup'],
  'Turkey': ['Turkish Cup'],
  'Belgium': ['Belgian Cup'],
  'Switzerland': ['Swiss Cup'],
};
const euroComps = [
  'UEFA Champions League',
  'UEFA Europa League',
  'UEFA Conference League',
];
const superCup = 'UEFA Super Cup';
const groupRounds = 6;
const _clSpots = [4, 4, 4, 4, 3, 2, 2, 1, 1, 1];
const _elSpots = [2, 2, 2, 2, 2, 2, 1, 1, 1, 1];

bool isEuro(String c) => c.startsWith('UEFA');

int _cupIndex(String c) {
  for (final l in cupsByCountry.values) {
    final i = l.indexOf(c);
    if (i >= 0) return i;
  }
  return 0;
}

List<StandingRow> sortRows(Iterable<StandingRow> r) => r.toList()
  ..sort((a, b) => b.pts != a.pts
      ? b.pts.compareTo(a.pts)
      : b.gd != a.gd
          ? b.gd.compareTo(a.gd)
          : b.gf != a.gf
              ? b.gf.compareTo(a.gf)
              : b.club.reputation.compareTo(a.club.reputation));

Future<Map<int, StandingRow>> standingsOf(AppDatabase db, int sid, String comp,
    Map<int, Club> clubs, Iterable<int> ids,
    {int maxRound = 9999}) async {
  final rows = {for (final i in ids) i: StandingRow(clubs[i]!)};
  final res = await (db.select(db.fixtures).join([
    innerJoin(db.matchResults, db.matchResults.fixtureId.equalsExp(db.fixtures.id))
  ])
        ..where(db.fixtures.competition.equals(comp) &
            db.fixtures.seasonId.equals(sid) &
            db.fixtures.round.isSmallerOrEqualValue(maxRound)))
      .get();
  for (final x in res) {
    final f = x.readTable(db.fixtures);
    final m = x.readTable(db.matchResults);
    final h = rows[f.homeClubId], a = rows[f.awayClubId];
    if (h == null || a == null) continue;
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
  return rows;
}

Future<int?> winnerOf(AppDatabase db, int sid, String comp) async {
  final r = await (db.select(db.fixtures).join([
    innerJoin(db.matchResults, db.matchResults.fixtureId.equalsExp(db.fixtures.id))
  ])
        ..where(db.fixtures.competition.equals(comp) &
            db.fixtures.seasonId.equals(sid) &
            db.fixtures.knockout.equals(true))
        ..orderBy([OrderingTerm.desc(db.fixtures.round)])
        ..limit(1))
      .get();
  return r.isEmpty ? null : r.first.readTable(db.matchResults).winnerClubId;
}

Future<void> _entries(AppDatabase db, int sid, String comp, Iterable<int> ids) =>
    db.batch((b) => b.insertAll(db.compEntries, [
          for (final i in ids)
            CompEntriesCompanion.insert(seasonId: sid, competition: comp, clubId: i)
        ]));

Future<void> _fx(AppDatabase db, int sid, String comp, int round, int day, int h, int a,
        {bool ko = false}) =>
    db.into(db.fixtures).insert(FixturesCompanion.insert(
        seasonId: sid,
        competition: comp,
        round: round,
        day: day,
        homeClubId: h,
        awayClubId: a,
        knockout: Value(ko)));

/// One single-leg knockout round. Non-power-of-2 fields: lowest-reputation clubs play, rest get byes.
Future<void> _koRound(AppDatabase db, int sid, String comp, List<int> alive,
    Map<int, Club> clubs, int day, int round) async {
  var p = 1;
  while (p * 2 <= alive.length) {
    p *= 2;
  }
  final extra = alive.length - p;
  final s = [...alive]
    ..sort((a, b) => clubs[a]!.reputation.compareTo(clubs[b]!.reputation));
  final playing = extra == 0 ? s : s.take(2 * extra).toList();
  playing.shuffle(Random(sid * 131 + round * 7 + comp.length));
  for (var i = 0; i + 1 < playing.length; i += 2) {
    await _fx(db, sid, comp, round, day, playing[i], playing[i + 1], ko: true);
  }
}

Future<void> _groups(AppDatabase db, int sid, String comp, List<int> ids,
    Map<int, Club> clubs, Random r) async {
  if (ids.length < 4) return;
  final g = ids.length ~/ 4;
  final s = [...ids]
    ..sort((a, b) => clubs[b]!.reputation.compareTo(clubs[a]!.reputation));
  final groups = List.generate(g, (_) => <int>[]);
  for (var p = 0; p < 4; p++) {
    final pot = s.sublist(p * g, (p + 1) * g)..shuffle(r);
    for (var j = 0; j < g; j++) {
      groups[j].add(pot[j]);
    }
  }
  for (var j = 0; j < g; j++) {
    await db.batch((b) => b.insertAll(db.compEntries, [
          for (final i in groups[j])
            CompEntriesCompanion.insert(
                seasonId: sid, competition: comp, clubId: i, grp: Value(j))
        ]));
    final rounds = doubleRoundRobin(groups[j], r);
    for (var i = 0; i < rounds.length; i++) {
      for (final (h, a) in rounds[i]) {
        await _fx(db, sid, comp, i + 1, 58 + 14 * i, h, a);
      }
    }
  }
}

Future<Map<String, List<int>>> _qualify(AppDatabase db, int? prev,
    List<League> leagues, Map<int, Club> clubs) async {
  final top = leagues.where((l) => l.tier == 1).toList()
    ..sort((a, b) => b.strength.compareTo(a.strength));
  final used = <int>{};
  final q = {for (final n in euroComps) n: <int>[]};
  for (var i = 0; i < top.length; i++) {
    final l = top[i];
    final ids = [for (final c in clubs.values) if (c.leagueId == l.id) c.id];
    if (ids.isEmpty) continue;
    List<int> ord;
    int? cupWin;
    if (prev != null) {
      final st = await standingsOf(db, prev, l.name, clubs, ids);
      ord = [for (final r in sortRows(st.values)) r.club.id];
      final cup = cupsByCountry[l.country]?.first;
      if (cup != null) cupWin = await winnerOf(db, prev, cup);
    } else {
      ord = [...ids]
        ..sort((a, b) => clubs[b]!.reputation != clubs[a]!.reputation
            ? clubs[b]!.reputation.compareTo(clubs[a]!.reputation)
            : a.compareTo(b));
    }
    void fill(List<int> to, int n) {
      for (final c in ord) {
        if (to.length >= n) break;
        if (used.add(c)) to.add(c);
      }
    }

    final cl = <int>[], el = <int>[], ecl = <int>[];
    fill(cl, _clSpots[min(i, 9)]);
    if (cupWin != null && clubs.containsKey(cupWin) && used.add(cupWin)) el.add(cupWin);
    fill(el, _elSpots[min(i, 9)]);
    fill(ecl, 1);
    q[euroComps[0]]!.addAll(cl);
    q[euroComps[1]]!.addAll(el);
    q[euroComps[2]]!.addAll(ecl);
  }
  // pad each competition to a multiple of 4 with the best unused clubs
  final pool = clubs.values.toList()
    ..sort((a, b) => b.reputation.compareTo(a.reputation));
  for (final n in euroComps) {
    final l = q[n]!;
    if (l.isEmpty) continue;
    for (final c in pool) {
      if (l.length % 4 == 0) break;
      if (used.add(c.id)) l.add(c.id);
    }
  }
  return q;
}

Future<void> createCompetitions(AppDatabase db, int sid, int? prev) async {
  final leagues = await db.select(db.leagues).get();
  final lg = {for (final l in leagues) l.id: l};
  final clubs = {for (final c in await db.select(db.clubs).get()) c.id: c};
  final r = Random(sid * 977);

  for (final e in cupsByCountry.entries) {
    final ids = [for (final c in clubs.values) if (lg[c.leagueId]!.country == e.key) c.id];
    if (ids.length < 2) continue;
    for (var i = 0; i < e.value.length; i++) {
      await _entries(db, sid, e.value[i], ids);
      await _koRound(db, sid, e.value[i], ids, clubs, 66 + 14 * i, 1);
    }
  }

  final q = await _qualify(db, prev, leagues, clubs);
  for (final n in euroComps) {
    if (q[n]!.length >= 4) await _groups(db, sid, n, q[n]!, clubs, r);
  }

  if (prev != null) {
    final a = await winnerOf(db, prev, euroComps[0]);
    final b = await winnerOf(db, prev, euroComps[1]);
    if (a != null && b != null && a != b) {
      await _entries(db, sid, superCup, [a, b]);
      await _fx(db, sid, superCup, 1, 38, a, b, ko: true);
    }
  }
}

/// Mid-season saves created before competitions existed.
Future<void> ensureCompetitions(AppDatabase db) async {
  final saves = await db.select(db.careerSaves).get();
  if (saves.isEmpty || saves.first.clubId == null) return;
  final s = await (db.select(db.seasons)..where((t) => t.id.equals(saves.first.seasonId))).getSingle();
  if (s.currentDay > 50) return;
  final has = await (db.select(db.compEntries)
        ..where((t) => t.seasonId.equals(s.id))
        ..limit(1))
      .get();
  if (has.isEmpty) await db.transaction(() => createCompetitions(db, s.id, null));
}

/// Generates the next knockout round (or first knockout round after groups) once a round is complete.
Future<void> advanceCompetitions(AppDatabase db, int sid) async {
  final es = await (db.select(db.compEntries)..where((t) => t.seasonId.equals(sid))).get();
  if (es.isEmpty) return;
  final clubs = {for (final c in await db.select(db.clubs).get()) c.id: c};
  final by = <String, List<CompEntry>>{};
  for (final e in es) {
    (by[e.competition] ??= []).add(e);
  }
  for (final e in by.entries) {
    final comp = e.key;
    if (comp == superCup) continue;
    final fx = await (db.select(db.fixtures)
          ..where((t) => t.seasonId.equals(sid) & t.competition.equals(comp)))
        .get();
    if (fx.isEmpty || fx.any((f) => !f.played)) continue;
    final euro = isEuro(comp);
    List<int> base;
    if (euro) {
      base = [];
      final groups = {for (final x in e.value) x.grp};
      final st = await standingsOf(db, sid, comp, clubs, [for (final x in e.value) x.clubId],
          maxRound: groupRounds);
      for (final g in groups) {
        final ids = [for (final x in e.value) if (x.grp == g) x.clubId];
        base.addAll(sortRows([for (final i in ids) st[i]!]).take(2).map((r) => r.club.id));
      }
    } else {
      base = [for (final x in e.value) x.clubId];
    }
    final ko = fx.where((f) => f.knockout).toList();
    final res = await (db.select(db.matchResults)
          ..where((t) => t.fixtureId.isIn([for (final f in ko) f.id])))
        .get();
    final win = {for (final m in res) m.fixtureId: m.winnerClubId};
    final lost = <int>{
      for (final f in ko)
        if (win[f.id] != null) win[f.id] == f.homeClubId ? f.awayClubId : f.homeClubId
    };
    final alive = base.where((i) => !lost.contains(i)).toList();
    if (alive.length < 2) continue;
    final k = {for (final f in ko) f.round}.length;
    final round = (euro ? groupRounds : 0) + k + 1;
    final day = euro ? min(275, 170 + 28 * k) : 66 + 14 * _cupIndex(comp) + 28 * k;
    await _koRound(db, sid, comp, alive, clubs, day, round);
  }
}

class CompDetail {
  final Season season;
  final Map<int, Club> clubs;
  final List<List<StandingRow>> groups;
  final List<(Fixture, MatchResult?)> fixtures;
  final int? winner;
  CompDetail(this.season, this.clubs, this.groups, this.fixtures, this.winner);
}

Future<List<String>> myCompetitions(AppDatabase db) async {
  final save = await loadCareer(db);
  final r = await (db.select(db.compEntries)
        ..where((t) => t.seasonId.equals(save.seasonId) & t.clubId.equals(save.clubId!)))
      .get();
  return {for (final e in r) e.competition}.toList()..sort();
}

Future<CompDetail> loadCompDetail(AppDatabase db, String comp) async {
  final save = await loadCareer(db);
  final season = await (db.select(db.seasons)..where((t) => t.id.equals(save.seasonId))).getSingle();
  final clubs = {for (final c in await db.select(db.clubs).get()) c.id: c};
  final es = await (db.select(db.compEntries)
        ..where((t) => t.seasonId.equals(season.id) & t.competition.equals(comp)))
      .get();
  final groups = <List<StandingRow>>[];
  final gs = {for (final e in es) if (e.grp >= 0) e.grp}.toList()..sort();
  if (gs.isNotEmpty) {
    final st = await standingsOf(db, season.id, comp, clubs, [for (final e in es) e.clubId],
        maxRound: groupRounds);
    for (final g in gs) {
      groups.add(sortRows([for (final e in es) if (e.grp == g) st[e.clubId]!]));
    }
  }
  final rows = await (db.select(db.fixtures).join([
    leftOuterJoin(db.matchResults, db.matchResults.fixtureId.equalsExp(db.fixtures.id))
  ])
        ..where(db.fixtures.seasonId.equals(season.id) & db.fixtures.competition.equals(comp))
        ..orderBy([OrderingTerm.asc(db.fixtures.round), OrderingTerm.asc(db.fixtures.day)]))
      .get();
  final fx = [
    for (final r in rows)
      (r.readTable(db.fixtures), r.readTableOrNull(db.matchResults))
  ].where((x) => gs.isEmpty || x.$1.knockout).toList();
  int? w;
  if (fx.isNotEmpty) {
    final last = fx.last;
    final n = fx.where((x) => x.$1.round == last.$1.round).length;
    if (n == 1) w = last.$2?.winnerClubId;
  }
  return CompDetail(season, clubs, groups, fx, w);
}
