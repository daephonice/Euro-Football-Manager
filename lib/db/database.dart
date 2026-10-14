import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Leagues,
  Clubs,
  Players,
  Seasons,
  CareerSaves,
  Fixtures,
  MatchResults,
  Transfers,
  Loans,
  TrainingSessions,
  FinanceEntries,
  CompEntries,
  Awards,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([String name = 'career'])
      : super(driftDatabase(
          name: name,
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(careerSaves, careerSaves.formation);
            await m.addColumn(careerSaves, careerSaves.mentality);
            await m.addColumn(careerSaves, careerSaves.verticality);
          }
          if (from < 3) await m.createTable(financeEntries);
          if (from < 4) {
            await m.addColumn(careerSaves, careerSaves.trainingFocus);
            await customStatement(
                'UPDATE clubs SET training_level = CASE WHEN reputation >= 85 THEN 5 WHEN reputation >= 70 THEN 4 WHEN reputation >= 55 THEN 3 WHEN reputation >= 40 THEN 2 ELSE 1 END');
          }
          if (from < 5) {
            await m.addColumn(fixtures, fixtures.knockout);
            await m.addColumn(matchResults, matchResults.winnerClubId);
            await m.addColumn(matchResults, matchResults.note);
            await m.createTable(compEntries);
          }
          if (from < 6) {
            await m.addColumn(careerSaves, careerSaves.sponsorName);
            await m.addColumn(careerSaves, careerSaves.sponsorPct);
            await m.addColumn(careerSaves, careerSaves.themeMode);
            await m.createTable(awards);
            await customStatement(
                'UPDATE clubs SET stadium_level = CASE WHEN reputation >= 85 THEN 5 WHEN reputation >= 70 THEN 4 WHEN reputation >= 55 THEN 3 WHEN reputation >= 40 THEN 2 ELSE 1 END');
          }
        },
        beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}
