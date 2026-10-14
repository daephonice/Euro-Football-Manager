import 'dart:math';
import 'package:drift/drift.dart';
import '../engine/fixtures.dart';
import 'career.dart';
import 'database.dart';

class MarketTarget {
  final Player p;
  final Club club;
  final League league;
  MarketTarget(this.p, this.club, this.league);
}

class MarketData {
  final Club me;
  final Season season;
  final List<League> leagues;
  final List<MarketTarget> results;
  final int squadSize;
  MarketData(this.me, this.season, this.leagues, this.results, this.squadSize);
}

class BidResult {
  final bool ok;
  final String msg;
  BidResult(this.ok, this.msg);
}

class SaleOffer {
  final Player p;
  final Club buyer;
  final int fee;
  SaleOffer(this.p, this.buyer, this.fee);
}

class FinanceData {
  final Club club;
  final Season season;
  final int wageBill;
  final List<FinanceEntry> entries; // newest first
  final Map<String, int> totals;
  FinanceData(this.club, this.season, this.wageBill, this.entries, this.totals);
}

const maxSquad = 30, minSquad = 16, minSellerSquad = 18;

bool windowOpen(int day) => day <= 31 || (day >= 153 && day <= 184);

String windowText(int year, int day) => day <= 31
    ? 'Summer window open · closes ${dayLabel(year, 31)}'
    : day < 153
        ? 'Window closed · opens ${dayLabel(year, 153)}'
        : day <= 184
            ? 'Winter window open · closes ${dayLabel(year, 184)}'
            : 'Window closed · opens next summer';

({double club, double player}) bidChance({
  required int fee,
  required int value,
  required int sellerBudget,
  required int myRep,
  required int sellerRep,
  required int wage,
  required int curWage,
}) {
  var c = ((fee / value - 0.8) / 0.5).clamp(0.0, 1.0).toDouble();
  if (c > 0 && sellerBudget < value * 0.5) c = min(1.0, c + 0.1);
  final p = (0.5 + (myRep - sellerRep) / 60 + (wage / curWage - 1) * 1.5)
      .clamp(0.0, 1.0)
      .toDouble();
  return (club: c, player: p);
}

double _baseWeekly(int rep, int lStr) {
  final ovr = 35 + rep * 0.40 + lStr * 0.12;
  final lf = 0.25 + 0.75 * lStr / 100;
  return 24 * 400000 * pow(1.15, ovr - 50) * lf / 330;
}

Future<Season> _season(AppDatabase db, CareerSave s) =>
    (db.select(db.seasons)..where((t) => t.id.equals(s.seasonId))).getSingle();

Future<Club> _club(AppDatabase db, int id) =>
    (db.select(db.clubs)..where((t) => t.id.equals(id))).getSingle();

Future<int> _count(AppDatabase db, int clubId) async {
  final c = db.players.id.count();
  final r = await (db.selectOnly(db.players)
        ..addColumns([c])
        ..where(db.players.clubId.equals(clubId)))
      .getSingle();
  return r.read(c) ?? 0;
}

Future<int> _wageBill(AppDatabase db, int clubId) async {
  final s = db.players.wagePerWeek.sum();
  final r = await (db.selectOnly(db.players)
        ..addColumns([s])
        ..where(db.players.clubId.equals(clubId)))
      .getSingle();
  return r.read(s) ?? 0;
}

Future<MarketData> loadMarket(AppDatabase db,
    {String pos = 'All', int? leagueId, int maxAge = 40, int minOvr = 50, String q = ''}) async {
  final save = await loadCareer(db);
  final season = await _season(db, save);
  final me = await _club(db, save.clubId!);
  final leagues = await db.select(db.leagues).get();
  Expression<bool> w = db.players.clubId.equals(me.id).not() &
      db.players.age.isSmallerOrEqualValue(maxAge) &
      db.players.overall.isBiggerOrEqualValue(minOvr);
  if (pos != 'All') w = w & db.players.positions.like('%$pos%');
  if (leagueId != null) w = w & db.clubs.leagueId.equals(leagueId);
  if (q.trim().isNotEmpty) w = w & db.players.fullName.like('%${q.trim()}%');
  final j = db.select(db.players).join([
    innerJoin(db.clubs, db.clubs.id.equalsExp(db.players.clubId)),
    innerJoin(db.leagues, db.leagues.id.equalsExp(db.clubs.leagueId)),
  ])
    ..where(w)
    ..orderBy([OrderingTerm.desc(db.players.overall)])
    ..limit(40);
  final rows = await j.get();
  return MarketData(
    me,
    season,
    leagues,
    [
      for (final r in rows)
        MarketTarget(r.readTable(db.players), r.readTable(db.clubs), r.readTable(db.leagues))
    ],
    await _count(db, me.id),
  );
}

Future<BidResult> makeBid(AppDatabase db, int playerId,
        {required int fee, required int wage, required int years}) =>
    db.transaction(() async {
      final save = await loadCareer(db);
      final season = await _season(db, save);
      if (!windowOpen(season.currentDay)) return BidResult(false, 'Transfer window is closed');
      final p = await (db.select(db.players)..where((t) => t.id.equals(playerId))).getSingle();
      final me = await _club(db, save.clubId!);
      final seller = await _club(db, p.clubId!);
      if (fee > me.budget) return BidResult(false, 'Not enough budget');
      if (await _count(db, me.id) >= maxSquad) {
        return BidResult(false, 'Squad is full (max $maxSquad)');
      }
      if (await _count(db, seller.id) <= minSellerSquad) {
        return BidResult(false, '${seller.name} will not sell: squad too thin');
      }
      final ch = bidChance(
          fee: fee,
          value: p.value,
          sellerBudget: seller.budget,
          myRep: me.reputation,
          sellerRep: seller.reputation,
          wage: wage,
          curWage: p.wagePerWeek);
      final r = Random(playerId * 1000003 + season.currentDay);
      final r1 = r.nextDouble(), r2 = r.nextDouble();
      if (r1 >= ch.club) return BidResult(false, '${seller.name} rejected the offer');
      if (r2 >= ch.player) return BidResult(false, '${p.fullName} rejected personal terms');
      await (db.update(db.players)..where((t) => t.id.equals(p.id))).write(PlayersCompanion(
          clubId: Value(me.id),
          wagePerWeek: Value(wage),
          contractEndYear: Value(season.year + years)));
      await (db.update(db.clubs)..where((t) => t.id.equals(me.id)))
          .write(ClubsCompanion(budget: Value(me.budget - fee)));
      await (db.update(db.clubs)..where((t) => t.id.equals(seller.id)))
          .write(ClubsCompanion(budget: Value(seller.budget + fee)));
      await db.into(db.transfers).insert(TransfersCompanion.insert(
          playerId: p.id,
          fromClubId: Value(seller.id),
          toClubId: me.id,
          fee: fee,
          seasonId: season.id,
          day: season.currentDay));
      await db.into(db.financeEntries).insert(FinanceEntriesCompanion.insert(
          seasonId: season.id,
          clubId: me.id,
          day: season.currentDay,
          kind: 'transfer_in',
          amount: -fee,
          note: Value('Signed ${p.fullName} from ${seller.name}')));
      return BidResult(true, '${p.fullName} joins for ${_m(fee)} on a $years-year deal.');
    });

String _m(int v) => v >= 1000000 ? '£${(v / 1e6).toStringAsFixed(1)}M' : '£${(v / 1e3).round()}K';

Future<({SaleOffer? offer, String? error})> sellOffer(AppDatabase db, int playerId) async {
  final save = await loadCareer(db);
  final season = await _season(db, save);
  if (!windowOpen(season.currentDay)) return (offer: null, error: 'Transfer window is closed');
  final p = await (db.select(db.players)..where((t) => t.id.equals(playerId))).getSingle();
  final squad =
      await (db.select(db.players)..where((t) => t.clubId.equals(save.clubId!))).get();
  if (squad.length <= minSquad) return (offer: null, error: 'Squad too small (min $minSquad)');
  if (p.positions.split(',').first == 'GK' &&
      squad.where((x) => x.positions.split(',').first == 'GK').length <= 2) {
    return (offer: null, error: 'You need at least 2 goalkeepers');
  }
  final r = Random(p.id * 7919 + season.currentDay);
  final fee = max(10000, (p.value * (0.8 + 0.45 * r.nextDouble()) / 10000).round() * 10000);
  final counts = {
    for (final row in await db
        .customSelect(
            'SELECT club_id AS c, COUNT(*) AS n FROM players WHERE club_id IS NOT NULL GROUP BY club_id')
        .get())
      row.read<int>('c'): row.read<int>('n')
  };
  final elig = [
    for (final c in await db.select(db.clubs).get())
      if (c.id != save.clubId && c.budget >= fee && (counts[c.id] ?? 0) < maxSquad) c
  ];
  if (elig.isEmpty) return (offer: null, error: 'No club can afford him');
  return (offer: SaleOffer(p, elig[r.nextInt(elig.length)], fee), error: null);
}

Future<void> executeSale(AppDatabase db, SaleOffer o) => db.transaction(() async {
      final save = await loadCareer(db);
      final season = await _season(db, save);
      final me = await _club(db, save.clubId!);
      final buyer = await _club(db, o.buyer.id);
      await (db.update(db.players)..where((t) => t.id.equals(o.p.id)))
          .write(PlayersCompanion(clubId: Value(buyer.id)));
      await (db.update(db.clubs)..where((t) => t.id.equals(me.id)))
          .write(ClubsCompanion(budget: Value(me.budget + o.fee)));
      await (db.update(db.clubs)..where((t) => t.id.equals(buyer.id)))
          .write(ClubsCompanion(budget: Value(buyer.budget - o.fee)));
      await db.into(db.transfers).insert(TransfersCompanion.insert(
          playerId: o.p.id,
          fromClubId: Value(me.id),
          toClubId: buyer.id,
          fee: o.fee,
          seasonId: season.id,
          day: season.currentDay));
      await db.into(db.financeEntries).insert(FinanceEntriesCompanion.insert(
          seasonId: season.id,
          clubId: me.id,
          day: season.currentDay,
          kind: 'transfer_out',
          amount: o.fee,
          note: Value('Sold ${o.p.fullName} to ${buyer.name}')));
    });

/// Called inside finishMatchday's transaction: weekly wages, commercial income, gate receipts.
Future<void> applyMatchdayFinance(AppDatabase db, LiveMatchday lm) async {
  final cid = lm.myClubId;
  final club = await _club(db, cid);
  final lg =
      await (db.select(db.leagues)..where((t) => t.id.equals(club.leagueId))).getSingle();
  final wages = await _wageBill(db, cid);
  final t = _baseWeekly(club.reputation, lg.strength);
  final home = lm.mine != null && lm.mine!.homeClubId == cid;
  final mult = 1 + 0.15 * (club.stadiumLevel - 1);
  final rows = <(String, int, String)>[
    ('wages', -wages, 'Weekly wages'),
    ('commercial', (0.85 * t).round(), 'Sponsors & merchandise'),
    if (home)
      ('tickets', (0.8 * t * mult).round(), 'Gate receipts vs ${lm.names[lm.mine!.awayClubId]}'),
  ];
  await db.batch((b) => b.insertAll(db.financeEntries, [
        for (final r in rows)
          FinanceEntriesCompanion.insert(
              seasonId: lm.season.id,
              clubId: cid,
              day: lm.day,
              kind: r.$1,
              amount: r.$2,
              note: Value(r.$3))
      ]));
  final net = rows.fold<int>(0, (a, r) => a + r.$2);
  await (db.update(db.clubs)..where((x) => x.id.equals(cid)))
      .write(ClubsCompanion(budget: Value(club.budget + net)));
}

Future<FinanceData> loadFinance(AppDatabase db) async {
  final save = await loadCareer(db);
  final season = await _season(db, save);
  final club = await _club(db, save.clubId!);
  final entries = await (db.select(db.financeEntries)
        ..where((t) => t.clubId.equals(club.id) & t.seasonId.equals(season.id))
        ..orderBy([(t) => OrderingTerm.desc(t.id)]))
      .get();
  final totals = <String, int>{};
  for (final e in entries) {
    totals[e.kind] = (totals[e.kind] ?? 0) + e.amount;
  }
  return FinanceData(club, season, await _wageBill(db, club.id), entries, totals);
}
