import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../engine/development.dart';
import '../engine/rating.dart';
import 'database.dart';

const _shape = [
  'GK', 'GK', 'GK', 'CB', 'CB', 'CB', 'CB', 'LB', 'LB', 'RB', 'RB', 'CDM',
  'CDM', 'CM', 'CM', 'CAM', 'CAM', 'LW', 'LW', 'RW', 'RW', 'ST', 'ST', 'ST',
];
const _first = [
  'Luca', 'Marco', 'Jonas', 'Mateo', 'Hugo', 'Nils', 'Tomás', 'Rui', 'Emre',
  'Jules', 'Liam', 'Pablo', 'Noah', 'Diego', 'Kai', 'Leon', 'Théo', 'Ivan',
  'Adam', 'Samuel',
];
const _last = [
  'Silva', 'Rossi', 'Müller', 'Garcia', 'Dubois', 'Jansen', 'Costa', 'Yilmaz',
  'Novak', 'Peeters', 'Weber', 'Santos', 'Moreau', 'Fischer', 'Ricci',
  'Martins', 'Keller', 'Bakker', 'Lopez', 'Demir',
];
const _nats = [
  'England', 'Spain', 'France', 'Germany', 'Italy', 'Portugal', 'Brazil',
  'Argentina', 'Netherlands', 'Belgium', 'Turkey', 'Nigeria', 'Senegal',
];

PlayersCompanion _player(Random r,
    {required String name,
    required int age,
    required String nat,
    required String pos,
    required int ovr,
    required int pot,
    required int clubId,
    required int lStr}) {
  final a = genAttrs(pos, ovr, r);
  final v = valueOf(ovr, pot, age, lStr);
  Value<int> x(String k) => Value(a[k]!);
  return PlayersCompanion.insert(
    fullName: name,
    age: age,
    nationality: nat,
    clubId: Value(clubId),
    positions: pos,
    preferredFoot: r.nextInt(4) == 0 ? 'left' : 'right',
    overall: ovr,
    potential: pot,
    contractEndYear: 2027 + r.nextInt(5),
    wagePerWeek: wageOf(v),
    value: v,
    injuryProneness: Value(1 + r.nextInt(20)),
    pace: x('pace'),
    acceleration: x('acceleration'),
    shooting: x('shooting'),
    finishing: x('finishing'),
    passing: x('passing'),
    crossing: x('crossing'),
    dribbling: x('dribbling'),
    technique: x('technique'),
    defending: x('defending'),
    tackling: x('tackling'),
    physical: x('physical'),
    strength: x('strength'),
    stamina: x('stamina'),
    jumping: x('jumping'),
    decisionMaking: x('decisionMaking'),
    workRate: x('workRate'),
    vision: x('vision'),
    composure: x('composure'),
    handling: x('handling'),
    reflexes: x('reflexes'),
    positioning: x('positioning'),
    kicking: x('kicking'),
    command: x('command'),
  );
}

Future<void> seedIfEmpty(AppDatabase db) async {
  if ((await db.select(db.leagues).get()).isNotEmpty) return;
  final data = jsonDecode(await rootBundle.loadString('assets/data/seed.json'))
      as Map<String, dynamic>;
  final r = Random(42);

  await db.transaction(() async {
    final lg = <String, ({int id, String country, int strength})>{};
    for (final l in data['leagues']) {
      final id = await db.into(db.leagues).insert(LeaguesCompanion.insert(
          name: l[1], country: l[2], tier: l[3], strength: l[4]));
      lg[l[0]] = (id: id, country: l[2] as String, strength: l[4] as int);
    }

    final real = <String, List<List>>{};
    for (final p in data['players']) {
      (real[p[1]] ??= []).add(p);
    }

    final rows = <PlayersCompanion>[];
    for (final c in data['clubs']) {
      final L = lg[c[1]]!;
      final rep = c[2] as int;
      final budget = (pow(rep / 100, 3) * 200000000 * (0.2 + 0.8 * L.strength / 100)).round();
      final cid = await db.into(db.clubs).insert(ClubsCompanion.insert(
          name: c[0],
          leagueId: L.id,
          reputation: rep,
          budget: Value(budget),
          trainingLevel: Value(trainingLevelFor(rep)),
          stadiumLevel: Value(trainingLevelFor(rep))));

      final shape = [..._shape];
      for (final p in real[c[0]] ?? <List>[]) {
        shape.remove(p[4]);
        rows.add(_player(r,
            name: p[0], age: p[2], nat: p[3], pos: p[4], ovr: p[5], pot: p[6],
            clubId: cid, lStr: L.strength));
      }
      for (final pos in shape) {
        final age = 18 + r.nextInt(10) + r.nextInt(8);
        final ovr = (35 + rep * 0.40 + L.strength * 0.12 + (r.nextDouble() - 0.5) * 14)
            .round()
            .clamp(30, 88);
        final pot = (age < 24 ? ovr + r.nextInt(13) : ovr + r.nextInt(3)).clamp(ovr, 95);
        rows.add(_player(r,
            name: '${_first[r.nextInt(_first.length)]} ${_last[r.nextInt(_last.length)]}',
            age: age,
            nat: r.nextInt(10) < 6 ? L.country : _nats[r.nextInt(_nats.length)],
            pos: pos, ovr: ovr, pot: pot, clubId: cid, lStr: L.strength));
      }
    }
    await db.batch((b) => b.insertAll(db.players, rows));

    final sid = await db.into(db.seasons).insert(SeasonsCompanion.insert(year: 2026));
    await db.into(db.careerSaves).insert(
        CareerSavesCompanion.insert(name: 'Career', seasonId: sid));
  });
}
