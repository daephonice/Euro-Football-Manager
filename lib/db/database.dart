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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(careerSaves, careerSaves.formation);
            await m.addColumn(careerSaves, careerSaves.mentality);
            await m.addColumn(careerSaves, careerSaves.verticality);
          }
          if (from < 3) await m.createTable(financeEntries);
        },
        beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}
