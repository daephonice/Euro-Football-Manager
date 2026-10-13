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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}
